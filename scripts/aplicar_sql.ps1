[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Archivo,

  # Salida de emergencia, igual que en el respaldo: si la busqueda automatica
  # falla en una maquina donde psql SI esta, se le pasa la ruta y se acabo.
  [string]$PsqlPath = ''
)

# Salon y Mas - Ejecutar un archivo SQL contra la base.
#
# POR QUE EXISTE (09-ago-2026)
#
# Se intento aplicar la migracion del numero de ticket llamando a psql directo
# con `-U usuario -W`, y fallo con "password authentication failed". No era la
# contrasena equivocada: la contrasena de esta base lleva caracteres que el
# `Password:` de psql en la consola de Windows no entrega intactos.
#
# El script de respaldo nunca tuvo ese problema porque hace otra cosa (linea
# 144 de respaldo_supabase.ps1): lee la contrasena como SecureString y la
# **codifica** antes de meterla en la URL de conexion. Este script repite ese
# mismo mecanismo, que ya esta probado en esta maquina.
#
# LA CONTRASENA NUNCA SE ESCRIBE EN DISCO y nunca aparece en el historial de
# la consola: se pide en la ventana, se usa en memoria y se borra al terminar.
# Por eso este script existe en vez de una linea de comandos larga -- una
# contrasena escrita en la linea de comandos queda en el historial de
# PowerShell para siempre.
#
# COMO SE USA
#   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
#     -Archivo "supabase\migrations\20260809160000_numero_de_ticket_consecutivo.sql"
#
# QUE HACE Y QUE NO
#   * Se detiene al primer error (ON_ERROR_STOP). Las migraciones del proyecto
#     van dentro de begin/commit, asi que un fallo las deshace enteras: la base
#     queda como estaba, nunca a medias.
#   * NO decide que ejecutar. Solo ejecuta el archivo que se le indique.
#   * NO respalda. El respaldo se hace antes, y es cosa aparte.

$ErrorActionPreference = 'Stop'

$script:Rastro = New-Object System.Collections.Generic.List[string]

function Buscar-Herramienta {
  param([string]$Nombre)

  $candidatos = New-Object System.Collections.Generic.List[string]

  # Mismo orden de busqueda que respaldo_supabase.ps1, y por el mismo motivo:
  # LOCALAPPDATA puede no apuntar a tu perfil segun como se abrio la ventana.
  foreach ($base in @($env:LOCALAPPDATA, (Join-Path $env:USERPROFILE 'AppData\Local'))) {
    if ([string]::IsNullOrWhiteSpace($base)) { continue }
    $candidatos.Add((Join-Path $base ('PostgresTools\pgsql\bin\' + $Nombre + '.exe')))
  }

  foreach ($raiz in @(
    (Join-Path $env:ProgramFiles 'PostgreSQL'),
    (Join-Path ${env:ProgramFiles(x86)} 'PostgreSQL')
  )) {
    if ([string]::IsNullOrWhiteSpace($raiz) -or -not (Test-Path -LiteralPath $raiz)) { continue }
    $versiones = Get-ChildItem -LiteralPath $raiz -Directory -ErrorAction SilentlyContinue |
      Sort-Object { [int]($_.Name -replace '\D', '0') } -Descending
    foreach ($version in $versiones) {
      $candidatos.Add((Join-Path $version.FullName ('bin\' + $Nombre + '.exe')))
    }
  }

  foreach ($ruta in $candidatos) {
    $existe = Test-Path -LiteralPath $ruta
    $script:Rastro.Add("  [$(if ($existe) {'SI'} else {'no'})] $ruta")
    if ($existe) { return $ruta }
  }

  $enPath = Get-Command $Nombre -ErrorAction SilentlyContinue
  $script:Rastro.Add("  [$(if ($enPath) {'SI'} else {'no'})] PATH de esta ventana")
  if ($enPath) { return $enPath.Source }

  return $null
}

Write-Host ''
Write-Host 'Salon y Mas - Ejecutar SQL contra la base' -ForegroundColor Magenta
Write-Host 'La contrasena se usa solo en esta ventana y no se guarda en ningun archivo.'
Write-Host ''

# Se resuelve a ruta absoluta para poder mostrarla completa antes de ejecutar.
# Que el usuario vea EXACTAMENTE que archivo va a correr no es un adorno: es
# la ultima oportunidad de detectar que se apunto al archivo equivocado.
if (-not (Test-Path -LiteralPath $Archivo)) {
  throw "No existe el archivo: $Archivo"
}
$rutaSql = (Resolve-Path -LiteralPath $Archivo).Path

if ($PsqlPath) {
  if (-not (Test-Path -LiteralPath $PsqlPath)) {
    throw "No existe el archivo que indicaste: $PsqlPath"
  }
  $psql = $PsqlPath
} else {
  $psql = Buscar-Herramienta -Nombre 'psql'
}

if (-not $psql) {
  Write-Host 'No encontre psql. Esto es exactamente lo que revise:' -ForegroundColor Red
  Write-Host ''
  foreach ($linea in $script:Rastro) { Write-Host $linea }
  Write-Host ''
  Write-Host 'Puedes indicarme la ruta a mano:'
  Write-Host '  ...\aplicar_sql.ps1 -Archivo "..." -PsqlPath "C:\ruta\a\psql.exe"'
  Write-Host ''
  throw 'Falta psql.'
}

Write-Host "psql encontrado: $psql"
Write-Host ("  " + (& $psql --version))
Write-Host ''
Write-Host "Archivo a ejecutar:" -ForegroundColor Yellow
Write-Host "  $rutaSql"
Write-Host ''

Write-Host 'En Supabase: Project Settings -> Database -> Connection string -> Session pooler'
$plantilla = (Read-Host 'Pega la cadena conservando [YOUR-PASSWORD]').Trim().Trim('"').Trim("'")

if ($plantilla -notmatch '\[YOUR-PASSWORD\]') {
  throw 'Por seguridad la cadena debe conservar el texto [YOUR-PASSWORD]. No pegues la contrasena dentro de la URL.'
}
if (-not $plantilla.StartsWith('postgresql://', [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Esa cadena no parece una conexion de PostgreSQL.'
}

$segura = Read-Host 'Pega la contrasena de la base (quedara oculta)' -AsSecureString
$plana = [System.Net.NetworkCredential]::new('', $segura).Password

# ESTA linea es la razon de ser del script. Sin EscapeDataString, una
# contrasena con caracteres especiales llega rota y el servidor responde
# "password authentication failed", que suena a contrasena equivocada y no lo
# es. Costo un intento fallido descubrirlo.
$url = $plantilla.Replace('[YOUR-PASSWORD]', [System.Uri]::EscapeDataString($plana))

try {
  Write-Host ''
  Write-Host 'Ejecutando...' -ForegroundColor Cyan
  Write-Host ''

  & $psql --dbname=$url -v ON_ERROR_STOP=1 --file=$rutaSql

  if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'FALLO. No se aplico nada.' -ForegroundColor Red
    Write-Host 'Las migraciones de este proyecto van dentro de begin/commit:'
    Write-Host 'si algo fallo a mitad, la base quedo como estaba.'
    throw "psql termino con codigo $LASTEXITCODE."
  }

  Write-Host ''
  Write-Host 'LISTO' -ForegroundColor Green
  Write-Host "Se ejecuto: $rutaSql"
}
finally {
  # Se borra de memoria pase lo que pase, incluso si algo fallo a mitad.
  $url = $null
  $plana = $null
  $segura = $null
  [System.GC]::Collect()
}
