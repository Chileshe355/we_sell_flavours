#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"

require_test_identity
for command_name in docker git curl getent ip realpath stat df awk cut sort; do require_command "$command_name"; done

required_env=(
  TEST_DOMAIN TLS_EMAIL BASIC_AUTH_USER WORDPRESS_HOME WORDPRESS_SITEURL
  DB_NAME DB_USER SECRETS_DIR BACKUP_DIR BACKUP_REMOTE BACKUP_AGE_RECIPIENT
  DEPLOY_BRANCH DEPLOY_DIR MIN_FREE_DISK_MB APP_IMAGE_TAG ALERT_WEBHOOK_URL_FILE
)
for name in "${required_env[@]}"; do
  [[ -n "${!name:-}" ]] || { printf 'Missing required server setting: %s\n' "$name" >&2; exit 1; }
done
[[ -s "$ALERT_WEBHOOK_URL_FILE" ]] || { printf 'Missing alert webhook URL secret file.\n' >&2; exit 1; }
alert_mode="$(stat -c '%a' "$ALERT_WEBHOOK_URL_FILE")"
case "$alert_mode" in 400|440|600|640) ;; *) printf 'Unsafe alert webhook secret permissions.\n' >&2; exit 1 ;; esac

[[ "$TEST_DOMAIN" != *.invalid && "$TEST_DOMAIN" != *TBD* ]] || { printf 'TEST_DOMAIN is still a placeholder.\n' >&2; exit 1; }
if grep -Eq '=TBD($|[[:space:]])' "$inventory_file"; then
  printf 'Deployment inventory still contains TBD values.\n' >&2
  exit 1
fi

resolved_repo="$(realpath "$repo_root")"
resolved_secrets="$(realpath "$SECRETS_DIR")"
case "$resolved_secrets/" in
  "$resolved_repo/"*) printf 'SECRETS_DIR must be outside the Git working tree.\n' >&2; exit 1 ;;
esac

secret_names=(
  db_root_password db_password basic_auth basic_auth_password
  wp_auth_key wp_secure_auth_key wp_logged_in_key wp_nonce_key
  wp_auth_salt wp_secure_auth_salt wp_logged_in_salt wp_nonce_salt
)
for name in "${secret_names[@]}"; do
  path="$SECRETS_DIR/$name"
  [[ -s "$path" ]] || { printf 'Missing required secret file: %s\n' "$name" >&2; exit 1; }
  mode="$(stat -c '%a' "$path")"
  case "$mode" in 400|440|600|640) ;; *) printf 'Unsafe permissions on secret file: %s\n' "$name" >&2; exit 1 ;; esac
done

"${compose[@]}" config --quiet
while IFS= read -r image; do
  case "$image" in
    we-sell-flavours/wordpress:"$APP_IMAGE_TAG") ;;
    *@sha256:*) ;;
    *) printf 'Unpinned image in rendered configuration: %s\n' "$image" >&2; exit 1 ;;
  esac
  [[ "$image" != *:latest* ]] || { printf 'Floating latest tag is forbidden.\n' >&2; exit 1; }
done < <("${compose[@]}" config --images | sort -u)

rendered="$("${compose[@]}" config)"
grep -Fq 'target: 9000' <<<"$rendered" && { printf 'PHP-FPM host port is forbidden.\n' >&2; exit 1; }
grep -Fq 'target: 3306' <<<"$rendered" && { printf 'MariaDB host port is forbidden.\n' >&2; exit 1; }
grep -Fiq 'wesellflavourz.com' <<<"$rendered" && { printf 'Protected production hostname detected.\n' >&2; exit 1; }
unset rendered

expected_ip="$(inventory_value HETZNER_PUBLIC_IPV4)"
[[ -n "$expected_ip" && "$expected_ip" != TBD ]] || { printf 'Inventory lacks HETZNER_PUBLIC_IPV4.\n' >&2; exit 1; }
ip -4 -o address show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$expected_ip" || {
  printf 'Inventoried server IPv4 is not assigned to this host.\n' >&2
  exit 1
}
resolved_ipv4="$(getent ahostsv4 "$TEST_DOMAIN" | awk '{print $1}' | sort -u)"
[[ -n "$resolved_ipv4" ]] || { printf 'Test DNS has no public IPv4 result.\n' >&2; exit 1; }
dns_mode="$(inventory_value DNS_MODE)"
case "$dns_mode" in
  direct)
    grep -Fxq "$expected_ip" <<<"$resolved_ipv4" || {
      printf 'Direct test DNS does not resolve to the inventoried server IPv4 address.\n' >&2
      exit 1
    }
    ;;
  cloudflare-proxied)
    [[ "$(inventory_value DNS_PROVIDER)" == Cloudflare ]] || {
      printf 'Cloudflare-proxied DNS_MODE requires DNS_PROVIDER=Cloudflare.\n' >&2
      exit 1
    }
    ;;
  *)
    printf 'DNS_MODE must be direct or cloudflare-proxied.\n' >&2
    exit 1
    ;;
esac

mkdir -p "$BACKUP_DIR"
resolved_backup="$(realpath "$BACKUP_DIR")"
[[ "$resolved_backup" != / && "$resolved_backup" != "$resolved_repo" ]] || { printf 'Unsafe BACKUP_DIR.\n' >&2; exit 1; }
free_mb="$(df -Pm "$resolved_backup" | awk 'NR==2 {print $4}')"
(( free_mb >= MIN_FREE_DISK_MB )) || { printf 'Insufficient free disk space for deployment and backup.\n' >&2; exit 1; }

[[ "$BACKUP_REMOTE" == *:* && "$BACKUP_REMOTE" != *: ]] || { printf 'BACKUP_REMOTE must identify a non-root rclone path.\n' >&2; exit 1; }
printf 'Server preflight passed without changing containers.\n'
