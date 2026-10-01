# Exporta una plantilla de marca a PNG con Chrome sin ventana.
#
# Uso, desde la raiz del repositorio:
#   powershell -ExecutionPolicy Bypass -File docs\00_producto\marca\plantillas\exportar.ps1 -Plantilla post_vertical
#
# El tamano lo lee de la propia plantilla (<meta name="pieza" content="1080x1440">).
# Si la plantilla es un carrusel (<meta name="diapositivas" content="5">), saca
# una imagen por diapositiva: nombre-1.png, nombre-2.png...
#
# Los PNG salen a una carpeta temporal, no al repositorio: al repositorio solo
# va una pieza aprobada y publicada (D-305).

param(
    [Parameter(Mandatory = $true)][string]$Plantilla,
    [string]$Carpeta = (Join-Path $env:TEMP "salonymas_piezas")
)

$ErrorActionPreference = "Stop"

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) { throw "No encuentro Chrome en $chrome" }

$nombre = [IO.Path]::GetFileNameWithoutExtension($Plantilla)
$html = Join-Path $PSScriptRoot "$nombre.html"
if (-not (Test-Path $html)) { throw "No existe la plantilla $html" }

$texto = Get-Content -Raw -Encoding UTF8 $html
$tam = [regex]::Match($texto, '<meta name="pieza" content="(\d+)x(\d+)">')
if (-not $tam.Success) { throw "La plantilla no dice su tamano: falta <meta name=""pieza"" content=""ANCHOxALTO"">" }
$ancho = $tam.Groups[1].Value
$alto = $tam.Groups[2].Value

$diap = [regex]::Match($texto, '<meta name="diapositivas" content="(\d+)">')
$cuantas = if ($diap.Success) { [int]$diap.Groups[1].Value } else { 0 }

New-Item -ItemType Directory -Force $Carpeta | Out-Null
$url = "file:///" + ($html -replace '\\', '/')

function Exportar([string]$destino, [string]$direccion) {
    # Chrome avisa "bytes written to file" por la salida de errores. En
    # PowerShell 5.1, con "Stop", ese aviso normal se vuelve un error y corta
    # el guion. Aqui se deja pasar y se comprueba el archivo justo despues.
    $ErrorActionPreference = "SilentlyContinue"
    if (Test-Path $destino) { Remove-Item $destino }
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        "--window-size=$ancho,$alto" "--screenshot=$destino" $direccion 2>&1 | Out-Null
    if (-not (Test-Path $destino)) { throw "Chrome no escribio $destino" }
    Write-Output $destino
}

if ($cuantas -eq 0) {
    Exportar (Join-Path $Carpeta "$nombre.png") $url
} else {
    for ($n = 1; $n -le $cuantas; $n++) {
        Exportar (Join-Path $Carpeta "$nombre-$n.png") "$url#d$n"
    }
}
