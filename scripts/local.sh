#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_root/.env.local"
example_env="$repo_root/.env.local.example"
action="${1:-status}"
if (($#)); then shift; fi
compose=(docker compose --env-file "$env_file" -f "$repo_root/compose.yaml" -f "$repo_root/compose.local.yaml")

read_env() {
  local name="$1"
  sed -n "s/^${name}=//p" "$env_file" | tail -n 1
}

if [[ "$action" == init ]]; then
  if [[ ! -f "$env_file" ]]; then
    cp "$example_env" "$env_file"
    printf 'Created ignored local configuration: %s\n' "$env_file"
  else
    printf 'Local configuration already exists: %s\n' "$env_file"
  fi
  exit 0
fi

[[ -f "$env_file" ]] || { printf 'Missing .env.local. Run ./scripts/local.sh init first.\n' >&2; exit 1; }

case "$action" in
  config) "${compose[@]}" config --quiet ;;
  up) "${compose[@]}" up -d --build --wait ;;
  down) "${compose[@]}" down --remove-orphans ;;
  rebuild) "${compose[@]}" build --pull wordpress; "${compose[@]}" up -d --wait ;;
  status) "${compose[@]}" ps ;;
  logs) "${compose[@]}" logs --tail 200 "$@" ;;
  bootstrap)
    if ! "${compose[@]}" run --rm wpcli core is-installed >/dev/null 2>&1; then
      "${compose[@]}" run --rm wpcli core install \
        "--url=$(read_env WORDPRESS_HOME)" \
        "--title=$(read_env WP_SITE_TITLE)" \
        "--admin_user=$(read_env WP_ADMIN_USER)" \
        "--admin_password=$(read_env WP_ADMIN_PASSWORD)" \
        "--admin_email=$(read_env WP_ADMIN_EMAIL)" \
        "--locale=$(read_env WORDPRESS_LOCALE)" \
        --skip-email
    fi
    "${compose[@]}" run --rm wpcli language core install "$(read_env WORDPRESS_LOCALE)" --activate
    "${compose[@]}" run --rm wpcli rewrite structure '/%year%/%monthnum%/%postname%/'
    "${compose[@]}" run --rm wpcli option update blog_public 0
    "${compose[@]}" run --rm wpcli plugin activate --all
    ;;
  wp)
    (($#)) || { printf 'Pass a WP-CLI command, for example: ./scripts/local.sh wp plugin list\n' >&2; exit 1; }
    "${compose[@]}" run --rm wpcli "$@"
    ;;
  plugin-check)
    slug="${1:-}"
    [[ "$slug" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { printf 'Pass a safe plugin folder name.\n' >&2; exit 1; }
    "${compose[@]}" run --rm --no-deps --entrypoint sh -e "PLUGIN_SLUG=$slug" wordpress -eu -c '
      path="/var/www/html/wp-content/plugins/$PLUGIN_SLUG"
      test -d "$path"
      find "$path" -type f -name "*.php" -print0 | xargs -0 -r -n1 php -l
      if test -x "$path/vendor/bin/phpunit"; then cd "$path" && vendor/bin/phpunit; fi
    '
    ;;
  check) "$repo_root/scripts/test-stack.sh" local ;;
  reset)
    project="$(read_env COMPOSE_PROJECT_NAME)"
    environment="$(read_env ENVIRONMENT)"
    [[ "$project" == wsf-local && "$environment" == local && "$project" != *prod* ]] || {
      printf "Reset refused for project='%s' environment='%s'.\n" "$project" "$environment" >&2
      exit 1
    }
    printf 'Reset target project: %s\nVolumes to remove:\n' "$project"
    docker volume ls --filter "label=com.docker.compose.project=$project" --format '  {{.Name}}'
    if [[ "${1:-}" != --force ]]; then
      read -r -p "Type '$project' to confirm destructive local reset: " answer
      [[ "$answer" == "$project" ]] || { printf 'Reset cancelled.\n'; exit 1; }
    fi
    "${compose[@]}" down --volumes --remove-orphans
    ;;
  *) printf 'Unknown action: %s\n' "$action" >&2; exit 2 ;;
esac
