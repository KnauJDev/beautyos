[CmdletBinding()]
param(
  [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'BeautyOS Backups'),
  [string]$PsqlPath = ''
)

# Salon y Mas - Respaldo de los archivos (logos, portadas y fotos).
#
# POR QUE HACE FALTA APARTE
#
# Ni el respaldo de la base ni los respaldos automaticos de Supabase Pro
# incluyen los archivos subidos. **Guardan las direcciones, no las imagenes.**
# Sin esto, un negocio restaurado desde el respaldo funcionaria pero con todos
# los recuadros de foto rotos: sin logo, sin portada y sin el portafolio de
# trabajos, que para un salon es parte de como se vende.
#
# COMO FUNCIONA
#
# Los archivos viven en cuatro almacenes -- `tenant-logos`, `tenant-covers`,
# `stylist-photos` y `work-photos` -- y la base guarda su direccion. Este
# script pregunta a la base por todas las direcciones y baja cada archivo.
#
# Se preguntan las direcciones **a la base** y no se listan los almacenes a
# proposito: asi se baja exactamente lo que la aplicacion usa. Lo que quedo
# huerfano en el almacen -- un logo viejo que nadie reemplazo, el hallazgo H-09
# de la auditoria -- no se baja, y esta bien: no es informacion, es basura.
#
# Usa `psql`, que ya vino con las herramientas de PostgreSQL. La contrasena se
# pide en la ventana y no se guarda en ningun archivo, igual que en el respaldo
# de la base.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Buscar-Herramienta {
  param([string]$Nombre)

  foreach ($base in @($env:LOCALAPPDATA, (Join-Path $env:USERPROFILE 'AppData\Local'))) {
    if ([string]::IsNullOrWhiteSpace($base)) { continue }
    $ruta = Join-Path $base ('PostgresTools\pgsql\bin\' + $Nombre + '.exe')
    if (Test-Path -LiteralPath $ruta) { return $ruta }
  }

  $enPath = Get-Command $Nombre -ErrorAction SilentlyContinue
  if ($enPath) { return $enPath.Source }

  return $null
}

Write-Host ''
Write-Host 'Salon y Mas - Respaldo de archivos' -ForegroundColor Magenta
Write-Host 'Logos, portadas y fotos de trabajos.'
Write-Host ''

$psql = if ($PsqlPath) { $PsqlPath } else { Buscar-Herramienta -Nombre 'psql' }

if (-not $psql -or -not (Test-Path -LiteralPath $psql)) {
  Write-Host 'No encontre psql.' -ForegroundColor Red
  Write-Host 'Corre primero: scripts\instalar_herramientas_postgres.ps1'
  throw 'Falta psql.'
}

Write-Host "psql encontrado: $psql"

Write-Host ''
Write-Host 'En Supabase: Project Settings -> Database -> Connection string -> Session pooler'
$plantilla = (Read-Host 'Pega la cadena conservando [YOUR-PASSWORD]').Trim().Trim('"').Trim("'")

if ($plantilla -notmatch '\[YOUR-PASSWORD\]') {
  throw 'Por seguridad la cadena debe conservar el texto [YOUR-PASSWORD].'
}

$segura = Read-Host 'Pega la contrasena de la base (quedara oculta)' -AsSecureString
$plana = [System.Net.NetworkCredential]::new('', $segura).Password
$urlBase = $plantilla.Replace('[YOUR-PASSWORD]', [System.Uri]::EscapeDataString($plana))

try {
  $sello = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
  $carpeta = Join-Path $BackupRoot "Archivos_$sello"
  New-Item -ItemType Directory -Path $carpeta -Force | Out-Null

  # Una consulta por las cuatro fuentes. `-A -t` devuelve texto pelado, sin
  # cabeceras ni marcos, que es lo que se puede recorrer sin adivinar.
  $consulta = @'
select 'tenant-logos'   as origen, logo_url        from public.tenants        where logo_url is not null
union all
select 'tenant-covers',        cover_photo_url    from public.tenants        where cover_photo_url is not null
union all
select 'stylist-photos',       photo_url          from public.stylists       where photo_url is not null
union all
select 'work-photos',          photo_url          from public.work_photos    where photo_url is not null
'@

  Write-Host ''
  Write-Host '1/2 Preguntando a la base que archivos hay...' -ForegroundColor Cyan

  $filas = & $psql --dbname=$urlBase -A -t -F '|' -c $consulta
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar la base.' }

  $filas = @($filas | Where-Object { $_ -and $_.Trim() })
  Write-Host "    $($filas.Count) archivos referenciados"

  if ($filas.Count -eq 0) {
    Write-Host ''
    Write-Host 'No hay archivos que respaldar todavia.' -ForegroundColor Yellow
    return
  }

  Write-Host '2/2 Descargando...' -ForegroundColor Cyan

  $bajados = 0
  $fallidos = New-Object System.Collections.Generic.List[string]
  $indice = New-Object System.Collections.Generic.List[string]
  $indice.Add('origen|url|archivo_local')

  foreach ($fila in $filas) {
    $partes = $fila -split '\|', 2
    if ($partes.Count -lt 2) { continue }

    $origen = $partes[0].Trim()
    $url = $partes[1].Trim()
    if (-not $url.StartsWith('http')) { continue }

    # Se conserva la ruta que trae la URL -- {tenant}/{archivo} -- para que
    # quede claro de que negocio es cada imagen sin abrirla.
    $relativa = ($url -split '/object/public/')[-1]
    $destino = Join-Path $carpeta ($relativa -replace '/', '\')

    $dir = Split-Path $destino -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    try {
      Invoke-WebRequest -Uri $url -OutFile $destino -TimeoutSec 120 -UseBasicParsing
      $bajados++
      $indice.Add("$origen|$url|$relativa")
    } catch {
      # Un archivo que ya no esta no invalida el respaldo: se anota y se sigue.
      # Pararlo todo por una foto borrada seria perder las otras noventa.
      $fallidos.Add("$origen | $url | $($_.Exception.Message)")
    }
  }

  [System.IO.File]::WriteAllLines(
    (Join-Path $carpeta 'INDICE.txt'), $indice,
    [System.Text.UTF8Encoding]::new($false))

  if ($fallidos.Count -gt 0) {
    [System.IO.File]::WriteAllLines(
      (Join-Path $carpeta 'NO_SE_PUDIERON_BAJAR.txt'), $fallidos,
      [System.Text.UTF8Encoding]::new($false))
  }

  $peso = (Get-ChildItem $carpeta -Recurse -File | Measure-Object -Property Length -Sum).Sum

  Write-Host ''
  Write-Host 'ARCHIVOS RESPALDADOS' -ForegroundColor Green
  Write-Host "  Bajados  : $bajados de $($filas.Count)"
  Write-Host ("  Peso     : {0:N1} MB" -f ($peso / 1MB))
  Write-Host "  Ubicacion: $carpeta"

  if ($fallidos.Count -gt 0) {
    Write-Host "  No se pudieron bajar $($fallidos.Count). Ver NO_SE_PUDIERON_BAJAR.txt" -ForegroundColor Yellow
  }
}
finally {
  $urlBase = $null
  $plana = $null
  $segura = $null
  [System.GC]::Collect()
}
