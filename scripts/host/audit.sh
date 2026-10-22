#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '--- OS and patches ---'
. /etc/os-release
printf '%s %s\n' "$PRETTY_NAME" "$(uname -r)"
apt-get -s upgrade | grep '^Inst ' || true
printf '%s\n' '--- Clock ---'
timedatectl status
printf '%s\n' '--- Firewall ---'
ufw status verbose
printf '%s\n' '--- SSH effective settings ---'
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|maxauthtries) '
printf '%s\n' '--- Docker ---'
docker version --format 'Server {{.Server.Version}}'
docker compose version
printf '%s\n' '--- Listening TCP ports ---'
ss -lntp
printf '%s\n' '--- Filesystem permissions ---'
stat -c '%a %U:%G %n' /srv/we-sell-flavours /etc/we-sell-flavours /etc/we-sell-flavours/secrets /var/backups/we-sell-flavours
printf '%s\n' '--- Timers and recent failures ---'
systemctl list-timers --all 'wsf-*'
systemctl --failed --no-pager
