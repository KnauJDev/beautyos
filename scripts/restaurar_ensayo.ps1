# Salon y Mas - Restaurar un respaldo en el proyecto de ENSAYO (paso 2.2).
#
# POR QUE EXISTE ESTE GUION Y NO SE USA `aplicar_sql.ps1`.
# Aquel usa `ON_ERROR_STOP=1`, que para una migracion es exactamente lo que se
# quiere: si algo falla, no se aplica nada. **En una restauracion es al reves.**
# Un proyecto de Supabase recien creado ya trae sus propios roles y su
# estructura interna, asi que `roles.sql` y parte de `schema.sql` van a
# protestar por cosas que YA EXISTEN. Esos errores son normales y esperados.
# Con `ON_ERROR_STOP` el proceso se pararia en la primera linea y no se
# restauraria nada.
#
# Aqui se hace lo contrario: **se ejecuta todo, se registra todo, y al final se
# cuenta.** El resultado no es "fallo o no fallo" sino un archivo de registro y
# un censo que se compara contra produccion. La prueba de que el respaldo sirve
# no es que psql no se queje: es que los numeros cuadren.
#
# USO:
#   powershell -ExecutionPolicy Bypass -File "scripts\restaurar_ensayo.ps1" `
#     -Carpeta "C:\Users\Tercero\OneDrive\Documents\BeautyOS Backups\Backup_2026-08-11_09-59-53"

param(
  [Parameter(Mandatory = $true)]
  [string]$Carpeta,
  [string]$PsqlPath
)

$ErrorActionPreference = 'Stop'

# El identificador del proyecto de PRODUCCION. Si aparece en la cadena de
# conexion, este guion se niega a ejecutarse. Restaurar un volcado encima de
# produccion seria lo peor que puede pasar en este proyecto, y una cadena de
# 90 caracteres no se lee bien a las nueve de la manana.
$PROYECTO_PRODUCCION = 'eogppgbdnwxdtcbctaol'

function Buscar-Herramienta {
  param([string]$Nombre)
  $cmd = Get-Command $Nombre -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidatos = @(
    "$env:LOCALAPPDATA\PostgresTools\pgsql\bin\$Nombre.exe",
    "$env:ProgramFiles\PostgreSQL\17\bin\$Nombre.exe",
    "$env:ProgramFiles\PostgreSQL\16\bin\$Nombre.exe"
  )
  foreach ($c in $candidatos) { if (Test-Path -LiteralPath $c) { return $c } }
  return $null
}

Write-Host ''
Write-Host 'Salon y Mas - Restauracion de ENSAYO' -ForegroundColor Magenta
Write-Host 'La contrasena se usa solo en esta ventana y no se guarda en ningun archivo.'
Write-Host ''

# --- Los tres archivos del respaldo ---------------------------------------

if (-not (Test-Path -LiteralPath $Carpeta)) {
  throw "No existe la carpeta: $Carpeta"
}
$carpetaReal = (Resolve-Path -LiteralPath $Carpeta).Path

$archivos = @('roles.sql', 'schema.sql', 'data.sql')
foreach ($a in $archivos) {
  $ruta = Join-Path $carpetaReal $a
  if (-not (Test-Path -LiteralPath $ruta)) {
    throw "Falta $a en la carpeta del respaldo. No se puede restaurar a medias."
  }
  $tam = (Get-Item -LiteralPath $ruta).Length
  if ($tam -le 0) { throw "$a esta vacio. El respaldo no sirve." }
  Write-Host ("  {0,-12} {1,12:N0} bytes" -f $a, $tam)
}

Write-Host ''
Write-Host "Respaldo: $carpetaReal"
Write-Host ''

# --- psql -----------------------------------------------------------------

if ($PsqlPath) { $psql = $PsqlPath } else { $psql = Buscar-Herramienta -Nombre 'psql' }
if (-not $psql) {
  throw 'No encontre psql. Pasa la ruta con -PsqlPath "C:\ruta\a\psql.exe".'
}
Write-Host "psql encontrado: $psql"
Write-Host ("  " + (& $psql --version))
Write-Host ''

# --- La conexion, con el candado ------------------------------------------

Write-Host 'AHORA LA PARTE IMPORTANTE:' -ForegroundColor Yellow
Write-Host 'La cadena que pegues debe ser la del proyecto de ENSAYO, NO la de produccion.'
Write-Host ''

$plantilla = (Read-Host 'Pega la cadena del proyecto de ENSAYO, conservando [YOUR-PASSWORD]').Trim().Trim('"').Trim("'")

if ($plantilla -notmatch '\[YOUR-PASSWORD\]') {
  throw 'Por seguridad la cadena debe conservar el texto [YOUR-PASSWORD]. No pegues la contrasena dentro de la URL.'
}
if (-not $plantilla.StartsWith('postgresql://', [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Esa cadena no parece una conexion de PostgreSQL.'
}

# EL CANDADO. No se negocia y no tiene opcion para saltarselo a proposito.
if ($plantilla -match [regex]::Escape($PROYECTO_PRODUCCION)) {
  Write-Host ''
  Write-Host '=============================================================' -ForegroundColor Red
  Write-Host ' ALTO. Esa es la cadena de PRODUCCION.' -ForegroundColor Red
  Write-Host '=============================================================' -ForegroundColor Red
  Write-Host ''
  Write-Host " La cadena contiene '$PROYECTO_PRODUCCION', que es el proyecto real."
  Write-Host ' Restaurar un respaldo encima de produccion destruiria datos.'
  Write-Host ''
  Write-Host ' No se ha ejecutado nada. Pega la cadena del proyecto de ensayo.'
  Write-Host ''
  throw 'Cancelado por seguridad: la cadena apunta a produccion.'
}

# Segunda barrera, a proposito manual: obliga a parar y mirar.
$destino = ($plantilla -split '@')[-1]
Write-Host ''
Write-Host "Vas a restaurar CONTRA: $destino" -ForegroundColor Cyan
Write-Host ''
$confirma = Read-Host 'Si es el proyecto de ensayo, escribe ENSAYO en mayusculas'
if ($confirma -cne 'ENSAYO') {
  throw 'Cancelado: no se confirmo el destino.'
}

$segura = Read-Host 'Pega la contrasena de la base de ENSAYO (quedara oculta)' -AsSecureString
$plana = [System.Net.NetworkCredential]::new('', $segura).Password

# Igual que en aplicar_sql.ps1: sin EscapeDataString, una contrasena con
# caracteres especiales llega rota y el servidor dice "password authentication
# failed", que suena a contrasena equivocada y no lo es.
$url = $plantilla.Replace('[YOUR-PASSWORD]', [System.Uri]::EscapeDataString($plana))

$marca = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$registro = Join-Path $carpetaReal "restauracion_$marca.log"

try {
  Write-Host ''
  Write-Host 'Restaurando. Los errores de "ya existe" son NORMALES.' -ForegroundColor Cyan
  Write-Host "Todo queda en: $registro"
  Write-Host ''

  $resumen = @()

  foreach ($a in $archivos) {
    $ruta = Join-Path $carpetaReal $a
    Write-Host ("  {0,-12} ejecutando..." -f $a) -NoNewline

    Add-Content -LiteralPath $registro -Value "" -Encoding utf8
    Add-Content -LiteralPath $registro -Value "===== $a =====" -Encoding utf8

    # SIN ON_ERROR_STOP: se ejecuta todo y se registra todo.
    #
    # NO se usa `& $psql ... 2>&1`, y esto no es un detalle de estilo.
    # En Windows PowerShell 5.1, redirigir con `2>&1` la salida de error de un
    # programa externo **envuelve cada linea en un error de PowerShell**. Con
    # `$ErrorActionPreference = 'Stop'`, el primer `ERROR:` de psql mata el
    # guion entero -- es decir, justo los errores de "ya existe" que este
    # guion existe para tolerar. Paso en el primer intento del 12-ago.
    #
    # `Start-Process` con archivos de redireccion no pasa por ese mecanismo:
    # psql escribe directamente a disco y PowerShell no interpreta nada.
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()

    # EL ESPACIO DE "BeautyOS Backups" ROMPIO EL PRIMER INTENTO DEL 12-ago:
    # `Start-Process -ArgumentList` no pone comillas solo, partio el argumento
    # en el espacio y psql recibio "...\BeautyOS". No se restauro nada.
    #
    # Se podria arreglar poniendo las comillas a mano. **No se hace asi**: eso
    # deja el problema vivo esperando a la proxima ruta rara. Se le pasa a psql
    # solo el NOMBRE del archivo -- `roles.sql`, sin espacios posibles -- y se
    # le dice en que carpeta trabajar. Asi no hay ruta que partir.
    #
    # `$url` va entre comillas por si acaso, aunque no puede llevar espacios:
    # la contrasena se codifica con EscapeDataString antes de entrar aqui.
    $proc = Start-Process -FilePath $psql `
      -ArgumentList @("--dbname=`"$url`"", "--file=$a") `
      -WorkingDirectory $carpetaReal `
      -NoNewWindow -Wait -PassThru `
      -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr

    $salida = ''
    foreach ($t in @($tmpOut, $tmpErr)) {
      $trozo = Get-Content -LiteralPath $t -Raw -ErrorAction SilentlyContinue
      if ($trozo) { $salida += $trozo }
    }
    Remove-Item -LiteralPath $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue

    Add-Content -LiteralPath $registro -Value $salida -Encoding utf8

    # SE CUENTAN DOS FAMILIAS DE ERROR DISTINTAS, y confundirlas costo un
    # intento entero:
    #   "ERROR:"       -> la base rechazo una instruccion. Los de "already
    #                     exists" son normales en una restauracion.
    #   "psql: error:" -> **el programa no pudo ni empezar**: no encontro el
    #                     archivo, no pudo conectarse. Esto NUNCA es normal.
    # La primera version solo miraba la primera familia, asi que dijo
    # "ningun error inesperado" cuando no habia ejecutado ni una linea.
    $errores    = ([regex]::Matches($salida, '(?im)^\s*ERROR:')).Count
    $yaExisten  = ([regex]::Matches($salida, '(?im)^\s*ERROR:.*already exists')).Count
    $delPrograma = ([regex]::Matches($salida, '(?im)^\s*psql:\s*error:')).Count
    $otros      = $errores - $yaExisten

    # Y LA TERCERA COMPROBACION, que es la que de verdad protege: una
    # restauracion que no dice NADA no es una restauracion silenciosa y
    # limpia -- es una que no ocurrio. `schema.sql` sano imprime miles de
    # lineas. Silencio absoluto = no se ejecuto.
    $vacio = [string]::IsNullOrWhiteSpace($salida)
    $fallo = ($proc.ExitCode -ne 0) -or ($delPrograma -gt 0) -or $vacio

    $resumen += [pscustomobject]@{
      Archivo      = $a
      Codigo       = $proc.ExitCode
      Errores      = $errores
      YaExistian   = $yaExisten
      OtrosErrores = $otros
      DelPrograma  = $delPrograma
      Resultado    = if ($fallo) { 'FALLO' } else { 'ok' }
    }

    if ($fallo) {
      Write-Host ' FALLO' -ForegroundColor Red
    } else {
      Write-Host (" {0} errores ({1} de 'ya existe')" -f $errores, $yaExisten)
    }
  }

  Write-Host ''
  Write-Host 'RESUMEN' -ForegroundColor Green
  $resumen | Format-Table -AutoSize

  $otrosTotal = ($resumen | Measure-Object -Property OtrosErrores -Sum).Sum
  $fallos     = @($resumen | Where-Object { $_.Resultado -eq 'FALLO' }).Count

  Write-Host ''
  if ($fallos -gt 0) {
    Write-Host '=============================================================' -ForegroundColor Red
    Write-Host " NO SE RESTAURO. $fallos de $($archivos.Count) archivos fallaron." -ForegroundColor Red
    Write-Host '=============================================================' -ForegroundColor Red
    Write-Host ''
    Write-Host ' Esto NO son los errores normales de "ya existe": es que psql'
    Write-Host ' no pudo ni empezar, o termino con codigo distinto de cero, o'
    Write-Host ' no dijo absolutamente nada -- que en una restauracion sana'
    Write-Host ' es imposible.'
    Write-Host ''
    Write-Host " Mira el registro: $registro"
    Write-Host ''
    Write-Host ' NO EJECUTES EL CENSO. No hay nada que censar.' -ForegroundColor Yellow
    Write-Host ''
    return
  }

  if ($otrosTotal -eq 0) {
    Write-Host 'Ningun error inesperado. Los de "ya existe" son los normales.' -ForegroundColor Green
  } else {
    Write-Host "$otrosTotal errores que NO son de 'ya existe'." -ForegroundColor Yellow
    Write-Host 'Eso NO significa que fallara: puede ser algo que no importa.'
    Write-Host 'Lo que decide es el censo, no el numero de errores.'
  }

  Write-Host ''
  Write-Host 'AHORA LO QUE DE VERDAD PRUEBA QUE SIRVE:' -ForegroundColor Cyan
  Write-Host '  Ejecuta el censo (166) contra ESTA copia y compara con produccion.'
  Write-Host '  Un respaldo no esta comprobado porque psql no se queje.'
  Write-Host ''
  Write-Host "Registro completo: $registro"
}
finally {
  $url = $null
  $plana = $null
  $segura = $null
  [System.GC]::Collect()
}
