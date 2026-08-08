[CmdletBinding()]
param(
  [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'BeautyOS Backups'),
  [string]$Etiqueta = ''
)

# Salon y Mas - Respaldo de Supabase sin Docker.
#
# Reemplaza a `crear_respaldo_supabase.ps1`, que dejo de servir: pedia Docker
# Desktop, y en esta maquina no esta instalado. Docker son mas de mil megas,
# WSL2 y un reinicio; las herramientas de cliente de PostgreSQL son unos
# doscientos megas y hacen exactamente el mismo trabajo.
#
# QUE SE GUARDA
#   roles.sql    Los roles de la base. Puede fallar sin permisos: no es fatal.
#   schema.sql   Tablas, funciones, politicas de seguridad. La estructura.
#   data.sql     Los datos: negocios, clientes, citas, tickets, cobros.
#
# QUE NO SE GUARDA, Y HAY QUE SABERLO
#   * Las CUENTAS de usuario (`auth`) solo se exportan si la conexion tiene
#     permiso. El script avisa si no pudo.
#   * Los ARCHIVOS subidos -- logos, portadas, fotos de trabajos -- viven en
#     Storage, que es un almacen de archivos y no una tabla. Este respaldo
#     guarda la lista, no las imagenes.
#
# LA CONTRASENA NUNCA SE ESCRIBE EN DISCO. Se pide en la ventana, se usa en
# memoria y se borra al terminar. Mismo criterio que el script de julio.

$ErrorActionPreference = 'Stop'

function Buscar-Herramienta {
  param([string]$Nombre)

  $enPath = Get-Command $Nombre -ErrorAction SilentlyContinue
  if ($enPath) { return $enPath.Source }

  # Instalaciones tipicas de PostgreSQL en Windows, de mas nueva a mas vieja.
  $raices = @(
    (Join-Path $env:ProgramFiles 'PostgreSQL'),
    (Join-Path ${env:ProgramFiles(x86)} 'PostgreSQL')
  )

  foreach ($raiz in $raices) {
    if (-not (Test-Path -LiteralPath $raiz)) { continue }
    $candidatos = Get-ChildItem -LiteralPath $raiz -Directory -ErrorAction SilentlyContinue |
      Sort-Object { [int]($_.Name -replace '\D', '0') } -Descending
    foreach ($version in $candidatos) {
      $ruta = Join-Path $version.FullName "bin\$Nombre.exe"
      if (Test-Path -LiteralPath $ruta) { return $ruta }
    }
  }

  return $null
}

Write-Host ''
Write-Host 'Salon y Mas - Respaldo de Supabase' -ForegroundColor Magenta
Write-Host 'La contrasena se usa solo en esta ventana y no se guarda en ningun archivo.'
Write-Host ''

$pgDump = Buscar-Herramienta -Nombre 'pg_dump'
if (-not $pgDump) {
  Write-Host 'No encontre pg_dump.' -ForegroundColor Red
  Write-Host ''
  Write-Host 'Instala las herramientas de cliente de PostgreSQL 17:'
  Write-Host '  https://www.postgresql.org/download/windows/'
  Write-Host ''
  Write-Host 'En el instalador, DESMARCA "PostgreSQL Server" y "pgAdmin".'
  Write-Host 'Solo necesitas "Command Line Tools". Son unos 200 MB.'
  Write-Host ''
  throw 'Falta pg_dump.'
}

# La base del proyecto corre PostgreSQL 17. pg_dump se niega a exportar de un
# servidor mas nuevo que el, y con razon: produciria un respaldo incompleto sin
# avisar. Mejor detenerse aqui que descubrirlo el dia que haya que restaurar.
$versionTexto = & $pgDump --version
$versionMayor = 0
if ($versionTexto -match '(\d+)\.') { $versionMayor = [int]$Matches[1] }

Write-Host "pg_dump encontrado: $pgDump"
Write-Host "  $versionTexto"

if ($versionMayor -lt 17) {
  throw "pg_dump es version $versionMayor y la base corre PostgreSQL 17. Instala las herramientas de la 17 o superior."
}

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
$urlBase = $plantilla.Replace('[YOUR-PASSWORD]', [System.Uri]::EscapeDataString($plana))

$avisos = New-Object System.Collections.Generic.List[string]

try {
  $sello = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
  $nombre = if ($Etiqueta) { "Backup_${sello}_$Etiqueta" } else { "Backup_$sello" }
  $carpeta = Join-Path $BackupRoot $nombre
  New-Item -ItemType Directory -Path $carpeta -Force | Out-Null

  $rolesPath  = Join-Path $carpeta 'roles.sql'
  $schemaPath = Join-Path $carpeta 'schema.sql'
  $dataPath   = Join-Path $carpeta 'data.sql'

  # Los esquemas que importan. `public` es donde viven las 41 tablas y las
  # funciones; `auth` son las cuentas; `storage` la lista de archivos.
  $esquemas = @('--schema=public', '--schema=auth', '--schema=storage')

  Write-Host ''
  Write-Host '1/3 Roles...' -ForegroundColor Cyan
  $pgDumpAll = Buscar-Herramienta -Nombre 'pg_dumpall'
  if ($pgDumpAll) {
    & $pgDumpAll --dbname=$urlBase --roles-only --no-role-passwords --file=$rolesPath
    if ($LASTEXITCODE -ne 0) {
      $avisos.Add('Los roles no se pudieron exportar (permisos). No impide restaurar los datos.')
      Remove-Item -LiteralPath $rolesPath -ErrorAction SilentlyContinue
    }
  } else {
    $avisos.Add('pg_dumpall no encontrado: no hay roles.sql.')
  }

  Write-Host '2/3 Estructura...' -ForegroundColor Cyan
  & $pgDump --dbname=$urlBase --schema-only --no-owner --no-privileges @esquemas --file=$schemaPath
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la exportacion de la estructura. El respaldo NO es valido.' }

  Write-Host '3/3 Datos...' -ForegroundColor Cyan
  & $pgDump --dbname=$urlBase --data-only --no-owner --no-privileges @esquemas `
      --exclude-table='storage.buckets_vectors' `
      --exclude-table='storage.vector_indexes' `
      --file=$dataPath
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la exportacion de los datos. El respaldo NO es valido.' }

  # Un archivo vacio pesa muy poco y parece un respaldo. Se comprueba, porque
  # un respaldo que no sirve es peor que no tener ninguno: da confianza falsa.
  $obligatorios = @($schemaPath, $dataPath)
  foreach ($ruta in $obligatorios) {
    $archivo = Get-Item -LiteralPath $ruta
    if ($archivo.Length -lt 1024) {
      throw "El archivo $($archivo.Name) quedo casi vacio ($($archivo.Length) bytes). El respaldo NO es valido."
    }
  }

  $generados = Get-ChildItem -LiteralPath $carpeta -Filter '*.sql'
  $hashes = foreach ($archivo in $generados) {
    "$((Get-FileHash -LiteralPath $archivo.FullName -Algorithm SHA256).Hash) *$($archivo.Name)"
  }
  [System.IO.File]::WriteAllLines(
    (Join-Path $carpeta 'hashes.sha256.txt'), $hashes,
    [System.Text.UTF8Encoding]::new($false))

  $manifiesto = @(
    '# Respaldo de Salon y Mas',
    '',
    "- Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    '- Proyecto Supabase: eogppgbdnwxdtcbctaol',
    "- Herramienta: $versionTexto",
    '- Esquemas: public, auth, storage',
    '',
    '## Lo que NO incluye',
    '',
    '- Los archivos subidos (logos, portadas, fotos). Storage guarda archivos,',
    '  no filas: aqui esta la lista, no las imagenes.',
    '',
    '## Estado',
    '',
    '- Restauracion de ensayo: PENDIENTE',
    '',
    'Este archivo no contiene contrasenas ni cadenas de conexion.'
  )
  foreach ($aviso in $avisos) { $manifiesto += "- AVISO: $aviso" }

  [System.IO.File]::WriteAllLines(
    (Join-Path $carpeta 'MANIFIESTO.md'), $manifiesto,
    [System.Text.UTF8Encoding]::new($false))

  Write-Host ''
  Write-Host 'RESPALDO CREADO Y VERIFICADO' -ForegroundColor Green
  Write-Host "Ubicacion: $carpeta"
  foreach ($archivo in $generados) {
    Write-Host ("  {0,-12} {1,10:N0} bytes" -f $archivo.Name, $archivo.Length)
  }
  foreach ($aviso in $avisos) { Write-Host "  AVISO: $aviso" -ForegroundColor Yellow }
}
finally {
  # Se borra de memoria pase lo que pase, incluso si algo fallo a mitad.
  $urlBase = $null
  $plana = $null
  $segura = $null
  [System.GC]::Collect()
}
