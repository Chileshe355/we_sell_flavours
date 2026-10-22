#!/usr/bin/env bash
set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
secret_dir="${1:-/etc/we-sell-flavours/secrets}"
basic_user="${BASIC_AUTH_USER:-tester}"

require_command() { command -v "$1" >/dev/null 2>&1 || { printf 'Missing command: %s\n' "$1" >&2; exit 1; }; }
require_command openssl
require_command realpath

mkdir -p "$secret_dir"
chmod 0700 "$secret_dir"
resolved_secret_dir="$(realpath "$secret_dir")"
resolved_repo="$(realpath "$repo_root")"
case "$resolved_secret_dir/" in
  "$resolved_repo/"*) printf 'Secret directory must be outside the Git working tree.\n' >&2; exit 1 ;;
esac

generate_file() {
  local name="$1"
  if [[ ! -s "$secret_dir/$name" ]]; then
    openssl rand -base64 48 >"$secret_dir/$name"
    chmod 0600 "$secret_dir/$name"
    printf 'Generated secret file: %s\n' "$name"
  else
    printf 'Preserved existing secret file: %s\n' "$name"
  fi
}

for name in \
  db_root_password db_password \
  wp_auth_key wp_secure_auth_key wp_logged_in_key wp_nonce_key \
  wp_auth_salt wp_secure_auth_salt wp_logged_in_salt wp_nonce_salt \
  wp_admin_password
do
  generate_file "$name"
done

if [[ ! -s "$secret_dir/basic_auth" || ! -s "$secret_dir/basic_auth_password" ]]; then
  read -r -s -p "Password for test-site user '$basic_user': " basic_password
  printf '\n'
  [[ ${#basic_password} -ge 16 ]] || { printf 'Basic-auth password must contain at least 16 characters.\n' >&2; exit 1; }
  printf '%s' "$basic_password" >"$secret_dir/basic_auth_password"
  basic_hash="$(printf '%s\n' "$basic_password" | openssl passwd -apr1 -stdin)"
  printf '%s:%s\n' "$basic_user" "$basic_hash" >"$secret_dir/basic_auth"
  unset basic_password basic_hash
  chmod 0600 "$secret_dir/basic_auth" "$secret_dir/basic_auth_password"
  printf 'Generated basic-auth files.\n'
else
  printf 'Preserved existing basic-auth files.\n'
fi

# Compose file-backed secrets are bind mounts and retain host ownership/mode.
# Grant only the container service UID that consumes each file read access.
wordpress_secret_names=(
  db_password
  wp_auth_key wp_secure_auth_key wp_logged_in_key wp_nonce_key
  wp_auth_salt wp_secure_auth_salt wp_logged_in_salt wp_nonce_salt
)
for name in "${wordpress_secret_names[@]}"; do
  chown 0:33 "$secret_dir/$name"
  chmod 0640 "$secret_dir/$name"
done
chown 0:101 "$secret_dir/basic_auth"
chmod 0440 "$secret_dir/basic_auth"
chown 0:0 "$secret_dir/db_root_password" "$secret_dir/basic_auth_password"
chmod 0600 "$secret_dir/db_root_password" "$secret_dir/basic_auth_password"

printf 'Secrets are stored outside Git at %s with restrictive permissions.\n' "$resolved_secret_dir"
