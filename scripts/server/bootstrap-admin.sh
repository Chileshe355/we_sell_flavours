#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity

admin_secret="$SECRETS_DIR/wp_admin_password"
[[ -s "$admin_secret" ]] || { printf 'Missing one-time wp_admin_password secret.\n' >&2; exit 1; }
for name in WP_ADMIN_USER WP_ADMIN_EMAIL WP_SITE_TITLE WORDPRESS_LOCALE; do
  [[ -n "${!name:-}" ]] || { printf 'Missing bootstrap setting: %s\n' "$name" >&2; exit 1; }
done

admin_compose=("${compose[@]}" -f "$repo_root/compose.admin-bootstrap.yaml")
"${admin_compose[@]}" run --rm --entrypoint sh \
  -e WP_ADMIN_USER -e WP_ADMIN_EMAIL -e WP_SITE_TITLE -e WORDPRESS_HOME -e WORDPRESS_LOCALE \
  -e DISALLOW_FILE_MODS=false \
  wpcli -eu -c '
    if ! wp core is-installed >/dev/null 2>&1; then
      wp core install --url="$WORDPRESS_HOME" --title="$WP_SITE_TITLE" --admin_user="$WP_ADMIN_USER" --admin_email="$WP_ADMIN_EMAIL" --locale="$WORDPRESS_LOCALE" --skip-email --prompt=admin_password </run/secrets/wp_admin_password
    elif ! wp user get "$WP_ADMIN_USER" >/dev/null 2>&1; then
      wp user create "$WP_ADMIN_USER" "$WP_ADMIN_EMAIL" --role=administrator --prompt=user_pass </run/secrets/wp_admin_password
    fi
    wp language core install "$WORDPRESS_LOCALE" --activate
    wp rewrite structure "/%year%/%monthnum%/%postname%/"
    wp option update blog_public 0
    wp plugin activate --all
    chown -R www-data:www-data /var/www/html/wp-content
  '

if command -v shred >/dev/null 2>&1; then shred -u "$admin_secret"; else rm -f -- "$admin_secret"; fi
printf 'WordPress bootstrap completed; one-time administrator password file removed.\n'
