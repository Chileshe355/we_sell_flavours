#!/usr/bin/env bash
set -euo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf 'Run as root.\n' >&2; exit 1; }
allowed_cidrs="${SSH_ALLOWED_CIDRS:-}"
[[ -n "$allowed_cidrs" && "$allowed_cidrs" != TBD ]] || { printf 'Set SSH_ALLOWED_CIDRS as a comma-separated list.\n' >&2; exit 1; }

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp comment 'HTTP ACME redirect'
ufw allow 443/tcp comment 'HTTPS test site'
IFS=',' read -r -a cidrs <<<"$allowed_cidrs"
for cidr in "${cidrs[@]}"; do
  [[ "$cidr" =~ ^[0-9a-fA-F:.]+/[0-9]{1,3}$ ]] || { printf 'Invalid SSH CIDR: %s\n' "$cidr" >&2; exit 1; }
  ufw allow from "$cidr" to any port 22 proto tcp comment 'Restricted SSH'
done
ufw --force enable
ufw status verbose
