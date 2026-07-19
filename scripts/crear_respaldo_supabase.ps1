[CmdletBinding()]
param(
  [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'BeautyOS Backups')
)

$ErrorActionPreference = 'Stop'

function Invoke-SupabaseDump {
  param(
    [Parameter(Mandatory = $true)]
    [string]$DatabaseUrl,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & npx.cmd --yes supabase@latest @Arguments --db-url $DatabaseUrl
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase CLI termino con codigo $LASTEXITCODE."
  }
}

Write-Host ''
Write-Host 'BeautyOS - Respaldo seguro de Supabase' -ForegroundColor Magenta
Write-Host 'La conexion se usa solo en esta ventana y no se guarda en archivos.'
Write-Host ''

$nodeDirectory = Join-Path $env:ProgramFiles 'nodejs'
if ((Test-Path -LiteralPath (Join-Path $nodeDirectory 'node.exe')) -and
    -not (($env:Path -split ';') -contains $nodeDirectory)) {
  $env:Path = "$nodeDirectory;$env:Path"
}

if (-not (Get-Command npx.cmd -ErrorAction SilentlyContinue)) {
  throw 'Node.js no esta disponible. Reinicia Windows y vuelve a ejecutar este asistente.'
}

if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
  throw 'Docker no esta disponible. Abre Docker Desktop y espera a que indique que el motor esta listo.'
}

$dockerCommand = (Get-Command docker.exe).Source
$dockerCheck = Start-Job -ScriptBlock {
  param([string]$Command)
  & $Command info *> $null
  $LASTEXITCODE
} -ArgumentList $dockerCommand

if (-not (Wait-Job -Job $dockerCheck -Timeout 20)) {
  Stop-Job -Job $dockerCheck
  Remove-Job -Job $dockerCheck -Force
  throw 'Docker tardo demasiado en responder. Abre Docker Desktop y espera a que el motor este listo.'
}

$dockerExitCode = Receive-Job -Job $dockerCheck
Remove-Job -Job $dockerCheck -Force
if ($dockerExitCode -ne 0) {
  throw 'El motor de Docker aun no esta listo. Abre Docker Desktop y espera antes de reintentar.'
}

$secureUrl = Read-Host 'Pega la cadena Session pooler de beautyos-dev' -AsSecureString
$databaseUrl = [System.Net.NetworkCredential]::new('', $secureUrl).Password

try {
  if ([string]::IsNullOrWhiteSpace($databaseUrl) -or
      -not $databaseUrl.StartsWith('postgresql://', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'La cadena no parece una conexion PostgreSQL valida.'
  }

  $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
  $backupDirectory = Join-Path $BackupRoot "BeautyOS_Backup_$timestamp"
  New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

  $rolesPath = Join-Path $backupDirectory 'roles.sql'
  $schemaPath = Join-Path $backupDirectory 'schema.sql'
  $dataPath = Join-Path $backupDirectory 'data.sql'

  Write-Host ''
  Write-Host '1/3 Exportando roles...' -ForegroundColor Cyan
  Invoke-SupabaseDump -DatabaseUrl $databaseUrl -Arguments @(
    'db', 'dump', '-f', $rolesPath, '--role-only'
  )

  Write-Host '2/3 Exportando estructura...' -ForegroundColor Cyan
  Invoke-SupabaseDump -DatabaseUrl $databaseUrl -Arguments @(
    'db', 'dump', '-f', $schemaPath
  )

  Write-Host '3/3 Exportando datos...' -ForegroundColor Cyan
  Invoke-SupabaseDump -DatabaseUrl $databaseUrl -Arguments @(
    'db', 'dump', '-f', $dataPath, '--use-copy', '--data-only',
    '-x', 'storage.buckets_vectors', '-x', 'storage.vector_indexes'
  )

  $requiredFiles = @($rolesPath, $schemaPath, $dataPath)
  foreach ($path in $requiredFiles) {
    $file = Get-Item -LiteralPath $path
    if ($file.Length -le 0) {
      throw "El archivo $($file.Name) quedo vacio. El respaldo no es valido."
    }
  }

  $hashLines = foreach ($path in $requiredFiles) {
    $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
    "$($hash.Hash) *$([System.IO.Path]::GetFileName($path))"
  }
  [System.IO.File]::WriteAllLines(
    (Join-Path $backupDirectory 'hashes.sha256.txt'),
    $hashLines,
    [System.Text.UTF8Encoding]::new($false)
  )

  $manifest = @(
    '# Manifiesto de respaldo BeautyOS',
    '',
    "- Fecha local: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    '- Proyecto: beautyos-dev',
    '- Referencia: eogppgbdnwxdtcbctaol',
    '- Contenido: roles, esquema y datos',
    '- Integridad: hashes SHA-256 generados',
    '- Restauracion de ensayo: PENDIENTE',
    '- Resultado de linea base: PENDIENTE',
    '',
    'Este manifiesto no contiene contrasenas ni cadenas de conexion.'
  )
  [System.IO.File]::WriteAllLines(
    (Join-Path $backupDirectory 'MANIFIESTO.md'),
    $manifest,
    [System.Text.UTF8Encoding]::new($false)
  )

  Write-Host ''
  Write-Host 'RESPALDO CREADO Y VERIFICADO' -ForegroundColor Green
  Write-Host "Ubicacion: $backupDirectory"
  Write-Host 'Siguiente compuerta: restaurarlo en un entorno de ensayo.'
}
finally {
  $databaseUrl = $null
  $secureUrl = $null
}
