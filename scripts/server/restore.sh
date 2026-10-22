#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity
for command_name in age sha256sum tar mktemp; do require_command "$command_name"; done

backup_file="${1:-}"
mode="${2:---isolated}"
confirmation="${3:-}"
[[ -f "$backup_file" ]] || { printf 'Pass an existing encrypted backup file.\n' >&2; exit 1; }
[[ -f "${backup_file}.sha256" ]] || { printf 'Missing backup checksum file.\n' >&2; exit 1; }
[[ -f "${BACKUP_AGE_IDENTITY:-}" ]] || { printf 'Missing BACKUP_AGE_IDENTITY.\n' >&2; exit 1; }
(cd "$(dirname "$backup_file")" && sha256sum -c "$(basename "$backup_file").sha256")

work_dir="$(mktemp -d /var/tmp/wsf-restore.XXXXXX)"
archive="$work_dir/backup.tar.gz"
age -d -i "$BACKUP_AGE_IDENTITY" -o "$archive" "$backup_file"
tar -xzf "$archive" -C "$work_dir"
(cd "$work_dir" && sha256sum -c SHA256SUMS)

if [[ "$mode" == --in-place ]]; then
  [[ "$confirmation" == "$COMPOSE_PROJECT_NAME" && "$COMPOSE_PROJECT_NAME" == wsf-test ]] || {
    printf 'In-place restore requires: --in-place wsf-test\n' >&2
    exit 1
  }
  "$script_dir/backup.sh"
  "${compose[@]}" stop nginx wordpress
  "${compose[@]}" exec -T mariadb sh -eu -c '
    umask 077
    config=/tmp/restore-client.cnf
    trap "rm -f \"$config\"" EXIT
    printf "[client]\nuser=root\npassword=%s\n" "$(cat /run/secrets/db_root_password)" >"$config"
    mariadb --defaults-extra-file="$config" -e "DROP DATABASE IF EXISTS \`$MARIADB_DATABASE\`; CREATE DATABASE \`$MARIADB_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;"
  '
  "${compose[@]}" exec -T mariadb sh -eu -c '
    umask 077
    config=/tmp/restore-client.cnf
    trap "rm -f \"$config\"" EXIT
    printf "[client]\nuser=root\npassword=%s\n" "$(cat /run/secrets/db_root_password)" >"$config"
    exec mariadb --defaults-extra-file="$config" "$MARIADB_DATABASE"
  ' <"$work_dir/database.sql"
  "${compose[@]}" run --rm --no-deps -v "$work_dir:/restore:ro" --entrypoint sh wordpress -eu -c '
    rm -rf /var/www/html/wp-content/uploads
    tar -xzf /restore/uploads.tar.gz -C /var/www/html
    chown -R www-data:www-data /var/www/html/wp-content/uploads 2>/dev/null || true
  '
  "${compose[@]}" up -d --wait
  "$script_dir/health.sh"
  rm -rf -- "$work_dir"
  printf 'Guarded in-place test restore completed after creating a safety backup.\n'
  exit 0
fi

[[ "$mode" == --isolated || "$mode" == --keep ]] || { printf 'Use --isolated, --keep, or guarded --in-place.\n' >&2; exit 1; }
restore_project="wsf-restore-$(date -u +%Y%m%d%H%M%S)"
restore_compose=(docker compose -p "$restore_project" --env-file "$server_env" -f "$repo_root/compose.yaml" -f "$repo_root/compose.server.yaml")
cleanup() {
  if [[ "$mode" != --keep ]]; then
    "${restore_compose[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true
    rm -rf -- "$work_dir"
  else
    printf 'Preserved isolated restore project %s and work directory %s\n' "$restore_project" "$work_dir"
  fi
}
trap cleanup EXIT

"${restore_compose[@]}" up -d --wait mariadb
"${restore_compose[@]}" exec -T mariadb sh -eu -c '
  umask 077
  config=/tmp/restore-client.cnf
  trap "rm -f \"$config\"" EXIT
  printf "[client]\nuser=root\npassword=%s\n" "$(cat /run/secrets/db_root_password)" >"$config"
  exec mariadb --defaults-extra-file="$config" "$MARIADB_DATABASE"
' <"$work_dir/database.sql"
"${restore_compose[@]}" run --rm --no-deps -v "$work_dir:/restore:ro" --entrypoint sh wordpress -eu -c '
  mkdir -p /var/www/html/wp-content
  tar -xzf /restore/uploads.tar.gz -C /var/www/html
'
"${restore_compose[@]}" up -d --wait wordpress
"${restore_compose[@]}" run --rm wpcli core is-installed
"${restore_compose[@]}" run --rm wpcli option get home >/dev/null
"${restore_compose[@]}" exec -T mariadb sh -eu -c '
  umask 077
  config=/tmp/restore-client.cnf
  trap "rm -f \"$config\"" EXIT
  printf "[client]\nuser=root\npassword=%s\n" "$(cat /run/secrets/db_root_password)" >"$config"
  mariadb --defaults-extra-file="$config" -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"$MARIADB_DATABASE\""
' | grep -Eq '^[1-9][0-9]*$'
printf 'Isolated restore drill passed in project %s; active project %s was not targeted.\n' "$restore_project" "$COMPOSE_PROJECT_NAME"
