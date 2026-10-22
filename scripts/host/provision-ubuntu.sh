#!/usr/bin/env bash
set -euo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf 'Run as root on the target host.\n' >&2; exit 1; }
operator_user="${1:-wsfdeploy}"
public_key_file="${2:-}"
[[ "$operator_user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { printf 'Invalid operator user.\n' >&2; exit 1; }
[[ -f "$public_key_file" ]] || { printf 'Pass the operator SSH public-key file as argument 2.\n' >&2; exit 1; }
key_type="$(awk 'NR==1 {print $1}' "$public_key_file")"
case "$key_type" in
  ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com) ;;
  ssh-rsa)
    key_bits="$(ssh-keygen -lf "$public_key_file" | awk '{print $1}')"
    (( key_bits >= 2048 )) || { printf 'RSA operator keys must be at least 2048 bits.\n' >&2; exit 1; }
    ;;
  *) printf 'Unsupported operator SSH public-key type.\n' >&2; exit 1 ;;
esac

. /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || {
  printf 'This reviewed provisioner targets Ubuntu 24.04 LTS only.\n' >&2
  exit 1
}

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  age ca-certificates curl docker-buildx docker-compose-v2 docker.io fail2ban git \
  openssl rclone unattended-upgrades ufw
systemctl enable --now docker fail2ban systemd-timesyncd unattended-upgrades

if ! id "$operator_user" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$operator_user"
fi
install -d -o "$operator_user" -g "$operator_user" -m 0700 "/home/$operator_user/.ssh"
install -o "$operator_user" -g "$operator_user" -m 0600 "$public_key_file" "/home/$operator_user/.ssh/authorized_keys"

install -d -o root -g "$operator_user" -m 0750 /srv/we-sell-flavours
install -d -o root -g "$operator_user" -m 0750 /etc/we-sell-flavours /var/backups/we-sell-flavours
install -d -o root -g "$operator_user" -m 0700 /etc/we-sell-flavours/secrets

cat >/usr/local/sbin/wsf-deploy <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
exec /srv/we-sell-flavours/scripts/server/deploy.sh "$@"
WRAPPER
chmod 0755 /usr/local/sbin/wsf-deploy
cat >/usr/local/sbin/wsf-rollback <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
exec /srv/we-sell-flavours/scripts/server/rollback.sh "$@"
WRAPPER
chmod 0755 /usr/local/sbin/wsf-rollback
cat >/usr/local/sbin/wsf-diagnose <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
exec /srv/we-sell-flavours/scripts/server/diagnose.sh "$@"
WRAPPER
chmod 0755 /usr/local/sbin/wsf-diagnose

cat >"/etc/sudoers.d/$operator_user-wsf" <<EOF
$operator_user ALL=(root) NOPASSWD: /usr/local/sbin/wsf-deploy, /usr/local/sbin/wsf-rollback, /usr/local/sbin/wsf-diagnose *, /bin/systemctl status wsf-*, /bin/journalctl -u wsf-*
EOF
chmod 0440 "/etc/sudoers.d/$operator_user-wsf"
visudo -cf "/etc/sudoers.d/$operator_user-wsf"

journalctl --vacuum-time=30d
docker version
docker compose version
timedatectl show --property=NTPSynchronized --value
printf 'Base provisioning complete. Verify a second key-authenticated session before SSH hardening.\n'
