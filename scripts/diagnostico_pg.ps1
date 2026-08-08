# Salon y Mas - Por que esta ventana no ve pg_dump.
#
# No cambia nada: solo mira y reporta. Se escribio porque el archivo existe en
# el disco -- comprobado por dos vias -- y aun asi la ventana del propietario
# respondia que no. Cuando dos ventanas del mismo Windows discrepan sobre si un
# archivo existe, la causa suele ser el usuario, los permisos o un caracter
# invisible pegado en la ruta. Esto los distingue.

$ruta = 'C:\Users\Tercero\AppData\Local\PostgresTools\pgsql\bin\pg_dump.exe'
$dir  = 'C:\Users\Tercero\AppData\Local\PostgresTools\pgsql\bin'

Write-Host ''
Write-Host '=== QUIEN ERES EN ESTA VENTANA ===' -ForegroundColor Cyan
Write-Host "  Usuario        : $(whoami)"
Write-Host "  USERPROFILE    : $env:USERPROFILE"
Write-Host "  LOCALAPPDATA   : $env:LOCALAPPDATA"
$esAdmin = ([Security.Principal.WindowsPrincipal] `
  [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "  Elevado (admin): $esAdmin"
Write-Host "  PowerShell     : $($PSVersionTable.PSVersion)"
Write-Host "  Proceso        : $([IntPtr]::Size * 8) bits"

Write-Host ''
Write-Host '=== LA CARPETA ===' -ForegroundColor Cyan
Write-Host "  Existe la carpeta : $(Test-Path -LiteralPath $dir)"
if (Test-Path -LiteralPath $dir) {
  $n = (Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue | Measure-Object).Count
  Write-Host "  Archivos dentro   : $n"
  Write-Host '  Los que empiezan por pg_:'
  Get-ChildItem -LiteralPath $dir -Filter 'pg_*' -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "    $($_.Name)  ($($_.Length) bytes)" }
} else {
  Write-Host '  Subiendo por el arbol, hasta donde llega:' -ForegroundColor Yellow
  $partes = $dir -split '\\'
  $acum = ''
  foreach ($p in $partes) {
    $acum = if ($acum) { "$acum\$p" } else { $p }
    if ($acum -notmatch '\\') { $acum = "$acum\" }
    Write-Host ("    [{0}] {1}" -f $(if (Test-Path -LiteralPath $acum) {'SI'} else {'no'}), $acum)
  }
}

Write-Host ''
Write-Host '=== EL ARCHIVO ===' -ForegroundColor Cyan
Write-Host "  Test-Path -LiteralPath : $(Test-Path -LiteralPath $ruta)"
Write-Host "  Test-Path normal       : $(Test-Path $ruta)"
Write-Host "  .NET File::Exists      : $([System.IO.File]::Exists($ruta))"
Write-Host "  Largo de la ruta       : $($ruta.Length) caracteres"

Write-Host ''
Write-Host '=== ARRANCA? ===' -ForegroundColor Cyan
try {
  $v = & $ruta --version 2>&1
  Write-Host "  $v" -ForegroundColor Green
} catch {
  Write-Host "  NO: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Write-Host '=== PERMISOS DE LECTURA ===' -ForegroundColor Cyan
try {
  $acl = Get-Acl -LiteralPath $dir -ErrorAction Stop
  Write-Host "  Dueno: $($acl.Owner)"
} catch {
  Write-Host "  No se pudo leer los permisos: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Write-Host 'Copia TODO esto y mandamelo.' -ForegroundColor Magenta
Write-Host ''
