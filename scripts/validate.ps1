$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'check-secrets.ps1')
& (Join-Path $PSScriptRoot 'test-stack.ps1') -Environment local
& (Join-Path $PSScriptRoot 'test-stack.ps1') -Environment server

$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) {
    $shellFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.sh' | ForEach-Object { $_.FullName }
    foreach ($file in $shellFiles) {
        & bash -n $file
        if ($LASTEXITCODE -ne 0) { throw "Bash syntax check failed: $file" }
    }
} else {
    Write-Warning 'Bash is unavailable; shell syntax checks were skipped.'
}

openspec validate secure-wordpress-docker-environments --type change --strict
if ($LASTEXITCODE -ne 0) { throw 'OpenSpec validation failed.' }
Write-Output 'All available static validation passed.'
