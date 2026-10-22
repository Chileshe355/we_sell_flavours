param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'config', 'up', 'down', 'rebuild', 'status', 'logs', 'bootstrap', 'wp', 'plugin-check', 'check', 'reset')]
    [string]$Action = 'status',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env.local'
$exampleEnv = Join-Path $repoRoot '.env.local.example'
$composeArgs = @('--env-file', $envFile, '-f', (Join-Path $repoRoot 'compose.yaml'), '-f', (Join-Path $repoRoot 'compose.local.yaml'))

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & docker compose @composeArgs @Arguments
    if ($LASTEXITCODE -ne 0) { throw "docker compose failed with exit code $LASTEXITCODE" }
}

function Read-EnvValue {
    param([string]$Name)
    $line = Get-Content -LiteralPath $envFile | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
    if (-not $line) { return $null }
    return ($line -split '=', 2)[1].Trim()
}

if ($Action -eq 'init') {
    if (-not (Test-Path -LiteralPath $envFile)) {
        Copy-Item -LiteralPath $exampleEnv -Destination $envFile
        Write-Output "Created ignored local configuration: $envFile"
    } else {
        Write-Output "Local configuration already exists: $envFile"
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $envFile)) {
    throw 'Missing .env.local. Run ./scripts/local.ps1 init first.'
}

switch ($Action) {
    'config' { Invoke-Compose config --quiet }
    'up' { Invoke-Compose up -d --build --wait }
    'down' { Invoke-Compose down --remove-orphans }
    'rebuild' { Invoke-Compose build --pull wordpress; Invoke-Compose up -d --wait }
    'status' { Invoke-Compose ps }
    'logs' { Invoke-Compose logs --tail 200 @ExtraArgs }
    'bootstrap' {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        & docker compose @composeArgs run --rm wpcli core is-installed *> $null
        $isInstalled = $LASTEXITCODE -eq 0
        $ErrorActionPreference = $previousErrorAction
        if (-not $isInstalled) {
            $url = Read-EnvValue 'WORDPRESS_HOME'
            $title = Read-EnvValue 'WP_SITE_TITLE'
            $adminUser = Read-EnvValue 'WP_ADMIN_USER'
            $adminPassword = Read-EnvValue 'WP_ADMIN_PASSWORD'
            $adminEmail = Read-EnvValue 'WP_ADMIN_EMAIL'
            $locale = Read-EnvValue 'WORDPRESS_LOCALE'
            Invoke-Compose run --rm wpcli core install "--url=$url" "--title=$title" "--admin_user=$adminUser" "--admin_password=$adminPassword" "--admin_email=$adminEmail" "--locale=$locale" --skip-email
        }
        $locale = Read-EnvValue 'WORDPRESS_LOCALE'
        Invoke-Compose run --rm wpcli language core install $locale --activate
        Invoke-Compose run --rm wpcli rewrite structure '/%year%/%monthnum%/%postname%/'
        Invoke-Compose run --rm wpcli option update blog_public 0
        Invoke-Compose run --rm wpcli plugin activate --all
    }
    'wp' {
        if (-not $ExtraArgs) { throw 'Pass a WP-CLI command, for example: ./scripts/local.ps1 wp plugin list' }
        Invoke-Compose run --rm wpcli @ExtraArgs
    }
    'plugin-check' {
        $slug = @($ExtraArgs)[0]
        if (-not $slug -or $slug -notmatch '^[a-z0-9][a-z0-9._-]*$') { throw 'Pass a safe plugin folder name.' }
        $pluginArgs = @('run', '--rm', '--no-deps', '--entrypoint', 'sh', '-e', "PLUGIN_SLUG=$slug", 'wordpress', '-eu', '-c', 'path="/var/www/html/wp-content/plugins/$PLUGIN_SLUG"; test -d "$path"; find "$path" -type f -name \*.php -print0 | xargs -0 -r -n1 php -l; if test -x "$path/vendor/bin/phpunit"; then cd "$path" && vendor/bin/phpunit; fi')
        Invoke-Compose @pluginArgs
    }
    'check' { & (Join-Path $PSScriptRoot 'test-stack.ps1') -Environment local }
    'reset' {
        $project = Read-EnvValue 'COMPOSE_PROJECT_NAME'
        $environment = Read-EnvValue 'ENVIRONMENT'
        if ($project -ne 'wsf-local' -or $environment -ne 'local' -or $project -match 'prod') {
            throw "Reset refused for project='$project' environment='$environment'."
        }
        $volumes = docker volume ls --filter "label=com.docker.compose.project=$project" --format '{{.Name}}'
        Write-Output "Reset target project: $project"
        Write-Output 'Volumes to remove:'
        if ($volumes) { $volumes | ForEach-Object { Write-Output "  $_" } } else { Write-Output '  (none currently exist)' }
        if (-not $Force) {
            $answer = Read-Host "Type '$project' to confirm destructive local reset"
            if ($answer -ne $project) { Write-Output 'Reset cancelled.'; exit 1 }
        }
        Invoke-Compose down --volumes --remove-orphans
    }
}
