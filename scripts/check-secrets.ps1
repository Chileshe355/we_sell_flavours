$ErrorActionPreference = 'Stop'

$candidateFiles = git ls-files --cached --others --exclude-standard
$forbiddenPaths = $candidateFiles | Where-Object {
    ($_ -match '(^|/)(secrets|backups|uploads|wordpress-data|database-data)/' -or $_ -match '\.wpress$') -and
    $_ -notmatch '^tests/fixtures/secrets/'
}

if ($forbiddenPaths) {
    Write-Error "Forbidden runtime or secret paths are tracked: $($forbiddenPaths -join ', ')"
}

$patterns = @(
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'ghp_[A-Za-z0-9]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    'AKIA[0-9A-Z]{16}'
)

foreach ($pattern in $patterns) {
    $matches = rg --line-number --hidden --glob '!tests/fixtures/**' --glob '!.git/**' --glob '!openspec/changes/**' --regexp $pattern . 2>$null
    if ($LASTEXITCODE -eq 0 -and $matches) {
        Write-Error "Possible secret material detected for pattern '$pattern'."
    }
    if ($LASTEXITCODE -gt 1) {
        throw "rg failed while checking pattern '$pattern'."
    }
}

Write-Output 'Repository secret-pattern and tracked-path checks passed.'
