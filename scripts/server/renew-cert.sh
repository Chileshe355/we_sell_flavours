#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity

before="$("${compose[@]}" run --rm --no-deps --entrypoint sh certbot -c "sha256sum /etc/letsencrypt/live/$TEST_DOMAIN/fullchain.pem 2>/dev/null || true")"
"${compose[@]}" run --rm --no-deps certbot renew --webroot --webroot-path /var/www/certbot --quiet
after="$("${compose[@]}" run --rm --no-deps --entrypoint sh certbot -c "sha256sum /etc/letsencrypt/live/$TEST_DOMAIN/fullchain.pem")"

if [[ "$before" != "$after" ]]; then
  "${compose[@]}" exec -T nginx nginx -t
  "${compose[@]}" exec -T nginx nginx -s reload
  printf 'Certificate changed; validated configuration and reloaded Nginx.\n'
else
  printf 'Certificate is not due for renewal; Nginx was not reloaded.\n'
fi
"${compose[@]}" run --rm --no-deps --entrypoint openssl certbot x509 \
  -in "/etc/letsencrypt/live/$TEST_DOMAIN/fullchain.pem" -noout -checkend 1814400
safe_https_check
