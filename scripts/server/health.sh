#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity
require_command curl

unhealthy="$("${compose[@]}" ps --format json | grep -E '"Health":"(unhealthy|starting)"|"State":"(exited|dead|restarting)"' || true)"
[[ -z "$unhealthy" ]] || { printf 'One or more services are not healthy.\n' >&2; exit 1; }
"${compose[@]}" exec -T wordpress php -r 'if (PHP_VERSION !== "8.3.36") { fwrite(STDERR, "unexpected PHP version\n"); exit(1); } foreach (["imagick", "mysqli"] as $extension) { if (!extension_loaded($extension)) { fwrite(STDERR, "missing extension\n"); exit(1); } }'
"${compose[@]}" run --rm wpcli core version | grep -Fx '7.1.3'
"${compose[@]}" exec -T mariadb sh -eu -c '
  umask 077
  config=/tmp/health-client.cnf
  trap "rm -f \"$config\"" EXIT
  printf "[client]\nuser=root\npassword=%s\n" "$(cat /run/secrets/db_root_password)" >"$config"
  mariadb --defaults-extra-file="$config" --protocol=socket -Nse "SELECT @@character_set_server, @@collation_server"
' | grep -Fx "${DB_CHARSET}"$'\t'"${DB_COLLATION}"
safe_https_check
printf 'Container, runtime, database, and authenticated HTTPS health checks passed.\n'
