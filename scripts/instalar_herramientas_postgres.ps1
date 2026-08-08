[CmdletBinding()]
param(
  [string]$Destino = (Join-Path $env:LOCALAPPDATA 'PostgresTools'),
  [string]$Version = '17.6-1'
)

# Salon y Mas - Instala solo las herramientas de cliente de PostgreSQL.
#
# POR QUE ASI Y NO CON EL INSTALADOR:
#
# El instalador normal (o `winget install PostgreSQL.PostgreSQL.17`) monta un
# **servidor de base de datos completo** que arranca solo con Windows, ocupa un
# puerto y pide contrasena de superusuario. Para hacer un respaldo no hace
# falta nada de eso: solo `pg_dump`, que es un programa suelto.
#
# Este script baja el paquete de binarios, saca unicamente la carpeta `bin` y
# la deja en tu perfil de usuario. Sin permisos de administrador, sin servicios
# arrancando y sin tocar el registro de Windows. Para desinstalarlo, se borra
# la carpeta.
#
# La version por defecto es la **misma que corre la base en Supabase** (17.6).
# `pg_dump` se niega a exportar de un servidor mas nuevo que el, asi que no
# conviene quedarse corto.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # sin esto la descarga va lentisima

$url = "https://get.enterprisedb.com/postgresql/postgresql-$Version-windows-x64-binaries.zip"
$zip = Join-Path $env:TEMP "postgresql-$Version-binaries.zip"

Write-Host ''
Write-Host 'Salon y Mas - Herramientas de PostgreSQL' -ForegroundColor Magenta
Write-Host ''

# Si ya estan, no se baja nada otra vez.
$yaInstalado = Join-Path $Destino 'pgsql\bin\pg_dump.exe'
if (Test-Path -LiteralPath $yaInstalado) {
  Write-Host 'Ya estaban instaladas:' -ForegroundColor Green
  & $yaInstalado --version
  Write-Host ''
  Write-Host "Ubicacion: $(Split-Path $yaInstalado -Parent)"
  return
}

Write-Host "Origen : $url"
Write-Host "Destino: $Destino"
Write-Host ''

try {
  $cabecera = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 30 -UseBasicParsing
  $tamano = [int64]$cabecera.Headers['Content-Length']
  Write-Host ("Tamano : {0:N1} MB" -f ($tamano / 1MB))
} catch {
  throw "No se pudo alcanzar el archivo. Revisa la conexion a internet. Detalle: $($_.Exception.Message)"
}

Write-Host ''
Write-Host '1/4 Descargando... (varios minutos, no cierres esta ventana)' -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $zip -TimeoutSec 3600 -UseBasicParsing

$bajado = (Get-Item -LiteralPath $zip).Length
if ($bajado -ne $tamano) {
  Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
  throw "La descarga quedo incompleta ($bajado de $tamano bytes). Vuelve a intentarlo."
}
Write-Host ("    Descargado completo: {0:N1} MB" -f ($bajado / 1MB))

Write-Host '2/4 Extrayendo solo las herramientas...' -ForegroundColor Cyan

# Del paquete entero se saca unicamente `pgsql/bin`, que es donde viven
# pg_dump, pg_dumpall, psql y las librerias que necesitan en Windows. El resto
# son binarios de servidor que aqui no hacen ninguna falta.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archivo = [System.IO.Compression.ZipFile]::OpenRead($zip)
$extraidos = 0

try {
  foreach ($entrada in $archivo.Entries) {
    if ($entrada.FullName -notlike 'pgsql/bin/*') { continue }
    if ([string]::IsNullOrEmpty($entrada.Name)) { continue }

    $rutaFinal = Join-Path $Destino ($entrada.FullName -replace '/', '\')
    $carpeta = Split-Path $rutaFinal -Parent
    if (-not (Test-Path -LiteralPath $carpeta)) {
      New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
    }

    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entrada, $rutaFinal, $true)
    $extraidos++
  }
} finally {
  $archivo.Dispose()
}

Write-Host "    $extraidos archivos"

$binDir = Join-Path $Destino 'pgsql\bin'
$pgDump = Join-Path $binDir 'pg_dump.exe'

if (-not (Test-Path -LiteralPath $pgDump)) {
  throw 'No aparecio pg_dump.exe. El paquete pudo cambiar de estructura.'
}

Write-Host '3/4 Comprobando que funciona...' -ForegroundColor Cyan
$versionTexto = & $pgDump --version
if ($LASTEXITCODE -ne 0) {
  throw 'pg_dump se extrajo pero no arranca. Puede faltar alguna libreria del paquete.'
}
Write-Host "    $versionTexto"

Write-Host '4/4 Dejandolo disponible en la linea de comandos...' -ForegroundColor Cyan

# Se agrega al PATH del USUARIO, no al del sistema: no hace falta ser
# administrador y no afecta a nadie mas en el equipo.
$pathUsuario = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($pathUsuario -split ';') -notcontains $binDir) {
  [Environment]::SetEnvironmentVariable('Path', "$pathUsuario;$binDir", 'User')
  Write-Host '    Agregado al PATH de tu usuario.'
} else {
  Write-Host '    Ya estaba en el PATH.'
}

# Y tambien en esta ventana, para poder seguir sin reabrir nada.
if (($env:Path -split ';') -notcontains $binDir) {
  $env:Path = "$env:Path;$binDir"
}

Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'LISTO' -ForegroundColor Green
Write-Host "  $versionTexto"
Write-Host "  Ubicacion: $binDir"
Write-Host ''
Write-Host 'No se instalo ningun servidor ni servicio de Windows.'
Write-Host 'Para desinstalarlo algun dia, basta con borrar esa carpeta.'
Write-Host ''
Write-Host 'Siguiente paso: scripts\respaldo_supabase.ps1' -ForegroundColor Cyan
