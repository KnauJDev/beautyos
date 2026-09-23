# Diagnostico de la firma de ePayco (hallazgo BQ, D-270).
#
# POR QUE EXISTE. El 23-sep el primer cobro real por sede (paso 9.8) se aplico,
# pero el webhook de ePayco llego dos veces (14:26:27 y 14:32:45) y las dos
# veces el servidor lo rechazo: "Firma de ePayco invalida". La formula del
# codigo es la documentada por ePayco:
#
#   SHA-256( P_CUST_ID ^ P_KEY ^ x_ref_payco ^ x_transaction_id ^ x_amount ^ moneda )
#
# y el comercio (P_CUST_ID) es correcto: la confirmacion al volver lo comparo y
# paso. Lo que queda por saber es si el servidor usa la LLAVE correcta.
#
# QUE HACE. Recalcula la firma de ESE pago con la llave que pegues, en varias
# formas del monto, y te dice:
#   * si coincide con la firma que mando ePayco (entonces esa es la llave buena);
#   * si coincide con la que calculo el servidor (entonces esa es la que tiene).
#
# LA LLAVE NO SALE DE ESTA VENTANA: no se guarda, no se imprime, no se manda a
# ningun sitio. Igual que la contrasena de la base en aplicar_sql.ps1.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\diagnostico_firma_epayco.ps1

$ErrorActionPreference = 'Stop'

# Los datos del pago del 23-sep (no son secretos: la firma es un resumen, no la llave).
$custId      = '1588792'
$refPayco    = '386963043'
$transaccion = '3869630432026-09-23437278'
$moneda      = 'COP'
$firmaEpayco = '518c1264be0998c15db39d12f7adb5f815f2352495002baaaad3e916a27ddd8e'
# Lo que el servidor dijo que esperaba (el registro lo corta: se compara el principio).
$firmaServidor = 'ba59904af7e46ec645275905027c3f651943398bb21bb3a6a6984d65777e8'

function Sha256([string]$texto) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($texto)
  return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
}

Write-Host ''
Write-Host 'Salon y Mas - Diagnostico de la firma de ePayco' -ForegroundColor Cyan
Write-Host 'La llave se usa solo en esta ventana. No se guarda ni se muestra.'
Write-Host ''
Write-Host 'En ePayco: Integraciones -> Llaves API -> la que se llama P_KEY.'
$segura = Read-Host 'Pega la llave (quedara oculta)' -AsSecureString
$llave = [System.Net.NetworkCredential]::new('', $segura).Password.Trim()

if (-not $llave) { throw 'No se pego ninguna llave.' }

$encontrada = $false
foreach ($monto in @('10000', '10000.00', '10000.0', '10000,00')) {
  $cadena = "$custId^$llave^$refPayco^$transaccion^$monto^$moneda"
  $firma = Sha256 $cadena
  $conEpayco = $firma -eq $firmaEpayco
  $conServidor = $firma.StartsWith($firmaServidor)
  Write-Host ("  monto '{0}': coincide con ePayco: {1} | coincide con el servidor: {2}" -f `
    $monto, ($(if ($conEpayco) { 'SI' } else { 'no' })), ($(if ($conServidor) { 'SI' } else { 'no' })))
  if ($conEpayco) { $encontrada = $true }
}

Write-Host ''
if ($encontrada) {
  Write-Host 'RESULTADO: esa llave SI produce la firma de ePayco.' -ForegroundColor Green
  Write-Host 'Si no coincide con el servidor, el servidor tiene otra llave: pega esta misma en'
  Write-Host 'Supabase -> Edge Functions -> Secrets -> EPAYCO_P_KEY.'
} else {
  Write-Host 'RESULTADO: esa llave NO produce la firma de ePayco en ninguna forma del monto.' -ForegroundColor Yellow
  Write-Host 'Copia estas lineas y mandaselas al asistente. No mandes la llave.'
}

$llave = $null
