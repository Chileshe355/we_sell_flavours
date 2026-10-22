#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity
action="${1:-status}"

case "$action" in
  status)
    git -C "$repo_root" rev-parse HEAD
    "${compose[@]}" ps
    df -h "$DEPLOY_DIR" "$BACKUP_DIR"
    ;;
  logs)
    service="${2:-}"
    case "$service" in nginx|wordpress|mariadb) ;; *) printf 'Choose nginx, wordpress, or mariadb.\n' >&2; exit 2 ;; esac
    lines="${3:-200}"
    [[ "$lines" =~ ^[0-9]+$ && "$lines" -le 1000 ]] || { printf 'Log line limit must be 0-1000.\n' >&2; exit 2; }
    "${compose[@]}" logs --tail "$lines" "$service"
    ;;
  health) "$script_dir/health.sh" ;;
  resources) docker stats --no-stream; df -h; free -h; uptime ;;
  certificate)
    "${compose[@]}" run --rm --no-deps --entrypoint sh certbot -c \
      "openssl x509 -in /etc/letsencrypt/live/$TEST_DOMAIN/fullchain.pem -noout -issuer -subject -dates"
    ;;
  wp)
    subcommand="${2:-status}"
    case "$subcommand" in
      status) "${compose[@]}" run --rm wpcli core version; "${compose[@]}" run --rm wpcli plugin status ;;
      checksums) "${compose[@]}" run --rm wpcli core verify-checksums ;;
      *) printf 'Choose wp status or wp checksums.\n' >&2; exit 2 ;;
    esac
    ;;
  *) printf 'Choose status, logs, health, resources, certificate, or wp.\n' >&2; exit 2 ;;
esac
