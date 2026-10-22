#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
server_env="${SERVER_ENV_FILE:-/etc/we-sell-flavours/server.env}"
inventory_file="${DEPLOY_INVENTORY_FILE:-$repo_root/deploy/inventory.env}"

[[ -f "$server_env" ]] || { printf 'Missing server environment file: %s\n' "$server_env" >&2; exit 1; }
[[ -f "$inventory_file" ]] || { printf 'Missing deployment inventory: %s\n' "$inventory_file" >&2; exit 1; }

set -a
# The server environment is an operator-owned POSIX environment file outside Git.
# shellcheck disable=SC1090
. "$server_env"
set +a

compose=(
  docker compose
  --env-file "$server_env"
  -f "$repo_root/compose.yaml"
  -f "$repo_root/compose.server.yaml"
)

inventory_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$inventory_file" | tail -n 1
}

require_test_identity() {
  [[ "${ENVIRONMENT:-}" == staging ]] || { printf 'Refusing non-staging ENVIRONMENT.\n' >&2; exit 1; }
  [[ "${COMPOSE_PROJECT_NAME:-}" == wsf-test ]] || { printf 'Refusing unexpected COMPOSE_PROJECT_NAME.\n' >&2; exit 1; }
  [[ "${COMPOSE_PROJECT_NAME,,}" != *prod* ]] || { printf 'Refusing production-marked project.\n' >&2; exit 1; }
  [[ "${TEST_DOMAIN:-}" != wesellflavourz.com && "${TEST_DOMAIN:-}" != www.wesellflavourz.com ]] || {
    printf 'Refusing protected production hostname.\n' >&2
    exit 1
  }
  [[ "${WORDPRESS_HOME:-}" == "https://${TEST_DOMAIN:-}" ]] || { printf 'WORDPRESS_HOME must match the HTTPS test domain.\n' >&2; exit 1; }
  [[ "${WORDPRESS_SITEURL:-}" == "${WORDPRESS_HOME:-}" ]] || { printf 'WORDPRESS_SITEURL must equal WORDPRESS_HOME.\n' >&2; exit 1; }
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Required command is missing: %s\n' "$1" >&2; exit 1; }
}

authenticated_https_check() {
  local resolve_ip="${1:-}" password
  password="$(cat "$SECRETS_DIR/basic_auth_password")"
  {
    printf 'user = "%s:%s"\nsilent\nshow-error\nfail\nlocation\nmax-time = 20\nurl = "https://%s/"\n' \
      "$BASIC_AUTH_USER" "$password" "$TEST_DOMAIN"
    [[ -z "$resolve_ip" ]] || printf 'resolve = "%s:443:%s"\n' "$TEST_DOMAIN" "$resolve_ip"
  } | curl --config - >/dev/null
  unset password
}

safe_https_check() {
  authenticated_https_check
  if [[ "$(inventory_value DNS_MODE)" == cloudflare-proxied ]]; then
    authenticated_https_check "$(inventory_value HETZNER_PUBLIC_IPV4)"
  fi
}
