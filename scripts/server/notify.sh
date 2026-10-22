#!/usr/bin/env bash
set -euo pipefail

failed_unit="${1:-unknown}"
[[ "$failed_unit" =~ ^wsf-[A-Za-z0-9@_.-]+\.service$ ]] || { printf 'Invalid failed unit name.\n' >&2; exit 1; }
[[ -n "${ALERT_WEBHOOK_URL_FILE:-}" && -s "$ALERT_WEBHOOK_URL_FILE" ]] || { printf 'Alert webhook is not configured.\n' >&2; exit 1; }
webhook_url="$(cat "$ALERT_WEBHOOK_URL_FILE")"
hostname_value="$(hostname -f 2>/dev/null || hostname)"
payload="{\"text\":\"We Sell Flavours test alert: ${failed_unit} failed on ${hostname_value}. Check systemd journal and the operations runbook.\"}"
printf 'url = "%s"\nrequest = "POST"\nheader = "Content-Type: application/json"\nsilent\nshow-error\nfail\n' "$webhook_url" \
  | curl --config - --data "$payload" >/dev/null
unset webhook_url payload
