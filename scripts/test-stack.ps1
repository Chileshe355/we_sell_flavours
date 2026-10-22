param(
    [ValidateSet('local', 'server')]
    [string]$Environment = 'local',
    [switch]$Runtime
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Environment -eq 'local') {
    $envFile = Join-Path $repoRoot '.env.local'
    $override = Join-Path $repoRoot 'compose.local.yaml'
} else {
    $envFile = Join-Path $repoRoot '.env.server.example'
    $override = Join-Path $repoRoot 'compose.server.yaml'
}
$composeArgs = @('--env-file', $envFile, '-f', (Join-Path $repoRoot 'compose.yaml'), '-f', $override)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing environment file: $envFile" }
$configText = & docker compose @composeArgs config --format json
if ($LASTEXITCODE -ne 0) { throw 'Compose rendering failed.' }
$config = $configText | ConvertFrom-Json

$servicesWithPorts = @($config.services.PSObject.Properties | Where-Object { $_.Value.ports })
Assert-True ($servicesWithPorts.Count -eq 1 -and $servicesWithPorts[0].Name -eq 'nginx') 'only Nginx may publish host ports'
Assert-True (-not $config.services.mariadb.ports) 'MariaDB must not publish a host port'
Assert-True (-not $config.services.wordpress.ports) 'PHP-FPM must not publish a host port'
Assert-True ($config.services.nginx.networks.PSObject.Properties.Name -contains 'application') 'Nginx must join the application network'
Assert-True (-not ($config.services.nginx.networks.PSObject.Properties.Name -contains 'database')) 'Nginx must not join the database network'
Assert-True ($config.services.wordpress.networks.PSObject.Properties.Name -contains 'database') 'WordPress must join the database network'

foreach ($serviceProperty in $config.services.PSObject.Properties) {
    foreach ($volume in @($serviceProperty.Value.volumes)) {
        Assert-True ($volume.source -notmatch 'docker\.sock') "service $($serviceProperty.Name) must not mount the Docker socket"
    }
    $image = [string]$serviceProperty.Value.image
    Assert-True ($image -notmatch ':latest(?:@|$)') "service $($serviceProperty.Name) must not use latest"
    if ($image -and $image -notmatch '^we-sell-flavours/wordpress:') {
        Assert-True ($image -match '@sha256:[0-9a-f]{64}$') "service $($serviceProperty.Name) must use a digest"
    }
}

if ($Environment -eq 'local') {
    $port = @($config.services.nginx.ports)[0]
    Assert-True ($port.host_ip -eq '127.0.0.1') 'local HTTP must bind only to loopback'
    Assert-True ($config.services.wordpress.environment.WORDPRESS_ENVIRONMENT_TYPE -eq 'development') 'local WordPress must identify as development'
    Assert-True ($config.services.wordpress.environment.WP_DEBUG -eq 'true') 'local debug mode must be enabled'
} else {
    $targets = @($config.services.nginx.ports | ForEach-Object { $_.target })
    Assert-True ($targets -contains 80 -and $targets -contains 443) 'server Nginx must publish HTTP and HTTPS'
    Assert-True ($config.services.wordpress.environment.WORDPRESS_ENVIRONMENT_TYPE -eq 'staging') 'server WordPress must identify as staging'
    Assert-True ($config.services.wordpress.environment.WP_DEBUG -eq 'false') 'server debug mode must be disabled'
    Assert-True ($config.services.wordpress.environment.DISALLOW_FILE_EDIT -eq 'false') 'staging administrators must have the dashboard plugin/theme editor'
    Assert-True ($config.services.wordpress.environment.DISALLOW_FILE_MODS -eq 'false') 'staging administrators must be able to install and update plugins/themes'
    Assert-True ($config.services.wordpress.environment.PHP_UPLOAD_MAX_FILESIZE -eq '1000M') 'staging PHP file upload limit must be 1000 MB'
    Assert-True ($config.services.wordpress.environment.PHP_POST_MAX_SIZE -eq '1024M') 'staging PHP POST limit must include multipart overhead'
    Assert-True ($config.services.wordpress.environment.PHP_MAX_EXECUTION_TIME -eq '900') 'staging PHP execution limit must be 900 seconds'
    Assert-True ($config.services.wordpress.environment.PHP_MAX_INPUT_TIME -eq '1200') 'staging PHP input limit must be 1200 seconds'
    Assert-True ($config.services.nginx.environment.NGINX_CLIENT_MAX_BODY_SIZE -eq '1024m') 'staging Nginx request limit must match the PHP POST ceiling'
    Assert-True ($config.services.nginx.environment.NGINX_FASTCGI_READ_TIMEOUT -eq '1200s') 'staging Nginx FastCGI timeout must allow long imports'
    $pluginMount = @($config.services.wordpress.volumes | Where-Object { $_.target -eq '/var/www/html/wp-content/plugins' })[0]
    Assert-True ($pluginMount.type -eq 'volume' -and $pluginMount.read_only -ne $true) 'staging plugins must use a persistent writable volume'
    $nginxPluginMount = @($config.services.nginx.volumes | Where-Object { $_.target -eq '/var/www/html/wp-content/plugins' })[0]
    Assert-True ($nginxPluginMount.type -eq 'volume' -and $nginxPluginMount.read_only -eq $true) 'Nginx must serve the persistent plugin volume read-only'
    Assert-True ([int64]$config.services.mariadb.mem_limit -eq 536870912) 'MariaDB must use the reviewed 512 MiB limit for the 2 GiB host'
    Assert-True ([int64]$config.services.wordpress.mem_limit -eq 671088640) 'WordPress must use the reviewed 640 MiB limit for the 2 GiB host'
    Assert-True ([int64]$config.services.nginx.mem_limit -eq 134217728) 'Nginx must use the reviewed 128 MiB limit for the 2 GiB host'
    $serverTemplate = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'docker/nginx/server.conf.template')
    $bootstrapTemplate = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'docker/nginx/bootstrap.conf.template')
    Assert-True ($serverTemplate.Contains('if ($host != ${NGINX_SERVER_NAME})')) 'server Nginx must reject unexpected Host headers'
    Assert-True ($bootstrapTemplate.Contains('if ($host != ${NGINX_SERVER_NAME})')) 'bootstrap Nginx must reject unexpected Host headers'
    $deployScript = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'scripts/server/deploy.sh')
    $rollbackScript = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'scripts/server/rollback.sh')
    Assert-True ($deployScript.Contains('core update --version=7.1.3 --force')) 'deployment must explicitly update persistent WordPress core files'
    Assert-True ($deployScript.Contains('WORDPRESS_VERSION=$previous_wordpress_version')) 'deployment must record the prior WordPress version for rollback'
    Assert-True ($rollbackScript.Contains('core update --version="$WORDPRESS_VERSION" --force')) 'rollback must restore the recorded WordPress core version'
}

if ($Runtime) {
    if ($Environment -ne 'local') { throw 'Runtime checks are intentionally local; server runtime checks run over SSH with scripts/server/health.sh.' }
    & docker compose @composeArgs up -d --wait
    if ($LASTEXITCODE -ne 0) { throw 'Local services did not become healthy.' }
    $phpCheck = "exit(extension_loaded('imagick') && extension_loaded('mysqli') && PHP_VERSION === '8.3.36' ? 0 : 1);"
    & docker compose @composeArgs exec -T wordpress php -r $phpCheck
    if ($LASTEXITCODE -ne 0) { throw 'PHP runtime compatibility check failed.' }
    $wordpressVersion = (& docker compose @composeArgs run --rm wpcli core version).Trim()
    Assert-True ($wordpressVersion -eq '7.1.3') 'WordPress runtime version must be 7.1.3'
    $phpLimits = (& docker compose @composeArgs exec -T wordpress php -r "echo ini_get('memory_limit').'|'.ini_get('upload_max_filesize').'|'.ini_get('post_max_size');").Trim()
    Assert-True ($phpLimits -eq '256M|64M|64M') 'PHP memory/upload/post limits must match the local profile'
    & docker compose @composeArgs run --rm wpcli core is-installed
    if ($LASTEXITCODE -ne 0) { throw 'WordPress is not bootstrapped.' }
    $permalink = (& docker compose @composeArgs run --rm wpcli option get permalink_structure).Trim()
    Assert-True ($permalink -eq '/%year%/%monthnum%/%postname%/') 'pretty permalink structure must match the production reference'
    $activeLocale = (& docker compose @composeArgs run --rm wpcli language core list --status=active --field=language).Trim()
    Assert-True ($activeLocale -eq 'en_ZA') 'the selected en_ZA locale must be installed and active'
    $dbSettings = (@(& docker compose @composeArgs run --rm wpcli db query 'SELECT @@character_set_server, @@collation_server' --skip-column-names) | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1).Trim()
    Assert-True ($dbSettings -eq "utf8mb4`tutf8mb4_unicode_520_ci") 'MariaDB charset and collation must match the configured profile'
    $mountProbe = Join-Path $repoRoot 'plugins/.mount-probe'
    $mountProbeValue = [Guid]::NewGuid().ToString('N')
    try {
        Set-Content -LiteralPath $mountProbe -Value $mountProbeValue -NoNewline
        $containerProbe = (& docker compose @composeArgs exec -T wordpress cat /var/www/html/wp-content/plugins/.mount-probe).Trim()
        Assert-True ($containerProbe -eq $mountProbeValue) 'host plugin edits must be immediately visible in WordPress'
    } finally {
        if (Test-Path -LiteralPath $mountProbe) { Remove-Item -LiteralPath $mountProbe -Force }
    }
    $probe = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
    & docker compose @composeArgs run --rm wpcli option update wsf_persistence_probe $probe | Out-Null
    & docker compose @composeArgs up -d --force-recreate --wait | Out-Null
    $readProbe = (& docker compose @composeArgs run --rm wpcli option get wsf_persistence_probe).Trim()
    Assert-True ($readProbe -eq $probe) 'WordPress/database state must persist across container recreation'
    $health = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/healthz'
    Assert-True ($health.StatusCode -eq 200 -and $health.Content.Trim() -eq 'ok') 'Nginx health endpoint must respond'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/wp-config.php' -ErrorAction Stop | Out-Null
        throw 'wp-config.php request unexpectedly succeeded.'
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -notin @(403, 404)) { throw }
    }
}

Write-Output "$Environment stack validation passed$(if ($Runtime) { ' with runtime checks' } else { '' })."
