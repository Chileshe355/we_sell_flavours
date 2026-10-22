#!/usr/bin/env bash
set -euo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf 'Run as root.\n' >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for unit in wsf-backup.service wsf-backup.timer wsf-cert-renew.service wsf-cert-renew.timer 'wsf-notify@.service'; do
  install -o root -g root -m 0644 "$repo_root/deploy/systemd/$unit" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable --now wsf-backup.timer wsf-cert-renew.timer
systemctl list-timers --all 'wsf-*'
