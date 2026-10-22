#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity
for command_name in age rclone sha256sum tar mktemp realpath; do require_command "$command_name"; done

mkdir -p "$BACKUP_DIR"
backup_root="$(realpath "$BACKUP_DIR")"
[[ "$backup_root" != / && "$backup_root" != "$repo_root" ]] || { printf 'Unsafe BACKUP_DIR.\n' >&2; exit 1; }
[[ -n "${BACKUP_AGE_RECIPIENT:-}" ]] || { printf 'BACKUP_AGE_RECIPIENT is required.\n' >&2; exit 1; }
[[ "${BACKUP_REMOTE:-}" == *:* && "$BACKUP_REMOTE" != *: ]] || { printf 'BACKUP_REMOTE must be a non-root rclone path.\n' >&2; exit 1; }

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
work_dir="$(mktemp -d "$backup_root/.backup.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT
archive_name="wsf-${ENVIRONMENT}-${timestamp}.tar.gz"
encrypted_path="$backup_root/${archive_name}.age"

"${compose[@]}" exec -T mariadb sh -eu -c '
  umask 077
  config=/tmp/backup-client.cnf
  trap "rm -f \"$config\"" EXIT
  printf "[client]\nuser=%s\npassword=%s\n" "$MARIADB_USER" "$(cat /run/secrets/db_password)" >"$config"
  exec mariadb-dump --defaults-extra-file="$config" --single-transaction --quick --skip-lock-tables "$MARIADB_DATABASE"
' >"$work_dir/database.sql"

"${compose[@]}" exec -T wordpress sh -eu -c '
  if [ -d /var/www/html/wp-content/uploads ]; then
    tar -czf - -C /var/www/html wp-content/uploads
  else
    tar -czf - --files-from /dev/null
  fi
' >"$work_dir/uploads.tar.gz"

{
  printf 'environment=%s\n' "$ENVIRONMENT"
  printf 'compose_project=%s\n' "$COMPOSE_PROJECT_NAME"
  printf 'created_utc=%s\n' "$timestamp"
  printf 'git_revision=%s\n' "$(git -C "$repo_root" rev-parse HEAD)"
  printf 'app_image_tag=%s\n' "$APP_IMAGE_TAG"
  printf 'database_charset=%s\n' "$DB_CHARSET"
  printf 'database_collation=%s\n' "$DB_COLLATION"
  "${compose[@]}" images --format json
} >"$work_dir/metadata.txt"

(cd "$work_dir" && sha256sum database.sql uploads.tar.gz metadata.txt >SHA256SUMS)
tar -czf "$work_dir/$archive_name" -C "$work_dir" database.sql uploads.tar.gz metadata.txt SHA256SUMS
age -r "$BACKUP_AGE_RECIPIENT" -o "$encrypted_path" "$work_dir/$archive_name"
sha256sum "$encrypted_path" >"$encrypted_path.sha256"

remote_path="${BACKUP_REMOTE%/}/$(basename "$encrypted_path")"
rclone copyto "$encrypted_path" "$remote_path"
rclone copyto "$encrypted_path.sha256" "$remote_path.sha256"

retention_days="${BACKUP_RETENTION_DAYS:-14}"
[[ "$retention_days" =~ ^[0-9]+$ ]] || { printf 'Invalid BACKUP_RETENTION_DAYS.\n' >&2; exit 1; }
find "$backup_root" -maxdepth 1 -type f -name 'wsf-*.age*' -mtime "+$retention_days" -delete
rclone delete "$BACKUP_REMOTE" --min-age "${retention_days}d" --include 'wsf-*.age' --include 'wsf-*.age.sha256'

printf 'Encrypted, verified, off-host backup completed: %s\n' "$encrypted_path"
