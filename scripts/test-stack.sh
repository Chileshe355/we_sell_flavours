#!/usr/bin/env bash
set -euo pipefail

environment="${1:-local}"
runtime="${2:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$environment" in
  local) env_file="$repo_root/.env.local"; override="$repo_root/compose.local.yaml" ;;
  server) env_file="$repo_root/.env.server.example"; override="$repo_root/compose.server.yaml" ;;
  *) printf 'Environment must be local or server.\n' >&2; exit 2 ;;
esac
compose=(docker compose --env-file "$env_file" -f "$repo_root/compose.yaml" -f "$override")
"${compose[@]}" config --quiet
rendered="$("${compose[@]}" config)"

grep -Eq 'target: (3306|9000)' <<<"$rendered" && { printf 'Database or PHP-FPM host port detected.\n' >&2; exit 1; }
grep -Fq '/var/run/docker.sock' <<<"$rendered" && { printf 'Docker socket mount detected.\n' >&2; exit 1; }
grep -Eq 'image: .*:latest([@[:space:]]|$)' <<<"$rendered" && { printf 'Floating latest image detected.\n' >&2; exit 1; }

if [[ "$environment" == local ]]; then
  grep -Fq 'host_ip: 127.0.0.1' <<<"$rendered"
  grep -Fq 'WORDPRESS_ENVIRONMENT_TYPE: development' <<<"$rendered"
else
  grep -Fq 'WORDPRESS_ENVIRONMENT_TYPE: staging' <<<"$rendered"
  grep -Fq 'DISALLOW_FILE_EDIT: "false"' <<<"$rendered"
  grep -Fq 'DISALLOW_FILE_MODS: "false"' <<<"$rendered"
  grep -Fq 'PHP_UPLOAD_MAX_FILESIZE: 1000M' <<<"$rendered"
  grep -Fq 'PHP_POST_MAX_SIZE: 1024M' <<<"$rendered"
  grep -Fq 'PHP_MAX_EXECUTION_TIME: "900"' <<<"$rendered"
  grep -Fq 'PHP_MAX_INPUT_TIME: "1200"' <<<"$rendered"
  grep -Fq 'NGINX_CLIENT_MAX_BODY_SIZE: 1024m' <<<"$rendered"
  grep -Fq 'NGINX_FASTCGI_READ_TIMEOUT: 1200s' <<<"$rendered"
  grep -B3 -A8 'target: /var/www/html/wp-content/plugins' <<<"$rendered" | grep -Fq 'type: volume'
  [[ "$(grep -c 'target: /var/www/html/wp-content/plugins' <<<"$rendered")" -eq 3 ]]
  grep -Fq 'mem_limit: "536870912"' <<<"$rendered"
  grep -Fq 'mem_limit: "671088640"' <<<"$rendered"
  grep -Fq 'mem_limit: "134217728"' <<<"$rendered"
  grep -Fq 'if ($host != ${NGINX_SERVER_NAME})' "$repo_root/docker/nginx/server.conf.template"
  grep -Fq 'if ($host != ${NGINX_SERVER_NAME})' "$repo_root/docker/nginx/bootstrap.conf.template"
  grep -Fq 'core update --version=7.1.3 --force' "$repo_root/scripts/server/deploy.sh"
  grep -Fq 'WORDPRESS_VERSION=$previous_wordpress_version' "$repo_root/scripts/server/deploy.sh"
  grep -Fq 'core update --version="$WORDPRESS_VERSION" --force' "$repo_root/scripts/server/rollback.sh"
fi

if [[ "$runtime" == --runtime ]]; then
  [[ "$environment" == local ]] || { printf 'Server runtime checks use scripts/server/health.sh over SSH.\n' >&2; exit 1; }
  "${compose[@]}" up -d --wait
  "${compose[@]}" exec -T wordpress php -r 'exit(extension_loaded("imagick") && extension_loaded("mysqli") && PHP_VERSION === "8.3.36" ? 0 : 1);'
  [[ "$("${compose[@]}" run --rm wpcli core version)" == 7.1.3 ]]
  "${compose[@]}" run --rm wpcli core is-installed
  [[ "$("${compose[@]}" run --rm wpcli option get permalink_structure)" == '/%year%/%monthnum%/%postname%/' ]]
  [[ "$("${compose[@]}" run --rm wpcli language core list --status=active --field=language)" == en_ZA ]]
  "${compose[@]}" run --rm wpcli db query 'SELECT @@character_set_server, @@collation_server' --skip-column-names | grep -Fq $'utf8mb4\tutf8mb4_unicode_520_ci'
  curl -fsS http://127.0.0.1:8080/healthz | grep -qx ok
  status="$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/wp-config.php)"
  [[ "$status" == 403 || "$status" == 404 ]]
fi

printf '%s stack validation passed%s.\n' "$environment" "$([[ "$runtime" == --runtime ]] && printf ' with runtime checks')"
