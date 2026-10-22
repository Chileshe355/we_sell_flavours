#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity
"$script_dir/preflight.sh"

bootstrap=("${compose[@]}" -f "$repo_root/compose.tls-bootstrap.yaml")
"${bootstrap[@]}" up -d --build --wait mariadb wordpress nginx

"${compose[@]}" run --rm --no-deps certbot certonly \
  --webroot --webroot-path /var/www/certbot \
  --domain "$TEST_DOMAIN" \
  --email "$TLS_EMAIL" \
  --agree-tos --no-eff-email --non-interactive

"${bootstrap[@]}" stop nginx
"${compose[@]}" up -d --wait
"$script_dir/health.sh"
printf 'Trusted TLS certificate installed and the authenticated HTTPS stack is healthy.\n'
