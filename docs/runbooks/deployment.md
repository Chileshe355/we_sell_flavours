# Test server deployment runbook

This runbook targets only the dedicated Hetzner test environment. The production hostname and database identifiers in `docs/` are protected reference values and must never be used here.

## Required approvals and inputs

1. Copy `deploy/inventory.example.env` to the ignored `deploy/inventory.env` and replace every `TBD` with approved non-secret values.
2. Copy `.env.server.example` to `/etc/we-sell-flavours/server.env`, replace every placeholder, quote values containing spaces, and set mode `0640` owned by `root:wsfdeploy`.
3. Confirm the test DNS name, DNS mode/provider, TLS email, server ID/IP/size, Ubuntu 24.04 image, SSH key fingerprints and CIDRs, `main` deploy branch (or approved replacement), `plugins/` layout, basic-auth/IP policy, off-host rclone destination, age recipient, retention, RPO, and RTO.
4. Obtain explicit authorization and current SSH access before any host mutation. Create a Hetzner snapshot or other recoverable baseline and preserve the console/rescue route.

## Initial host setup

Perform read-only discovery first:

```bash
ssh root@TEST_IP 'cat /etc/os-release; uname -a; ss -lntp; df -h; docker version 2>/dev/null || true'
```

Copy only the reviewed provisioning script and operator public key to a temporary server path, inspect their checksums, then run:

```bash
sudo scripts/host/provision-ubuntu.sh wsfdeploy /root/operator.pub
```

The confirmed host already uses Ubuntu's `docker.io` package. Keep Docker Engine, `docker-compose-v2`, and `docker-buildx` in that same Ubuntu package family; do not add Docker's CE repository on top of it. The provisioner is idempotent for this package layout.

Create matching Hetzner Cloud Firewall rules before enabling UFW: TCP 80/443 from anywhere required to reach the site and ACME, TCP 22 only from approved CIDRs, deny all other inbound traffic. Set the same comma-separated CIDRs in `SSH_ALLOWED_CIDRS`, then run `scripts/host/configure-firewall.sh` and compare `ufw status verbose` with the Hetzner rule set.

Open and verify a second `wsfdeploy` key-authenticated SSH session. From that second session only:

```bash
sudo CONFIRM_SECOND_KEY_SESSION=yes scripts/host/harden-ssh.sh
```

Keep the original recovery session open until a new login succeeds and `sshd -T` shows root/password/keyboard-interactive login disabled.

## Private repository checkout

Create a repository-scoped read-only GitHub deploy key. Put the private key at `/root/.ssh/we-sell-flavours-deploy` with mode `0600`; register only its public half as a read-only deploy key. Obtain GitHub's current SSH host keys from an authenticated administrator channel, compare their fingerprints with GitHub's published fingerprints, then add the approved key to root's `known_hosts`. Never use `StrictHostKeyChecking=no`. Keeping the checkout and deploy credential root-owned prevents `wsfdeploy` from replacing scripts that its approved sudo wrappers execute as root.

Clone without granting the account Docker-group membership:

```bash
sudo install -d -o root -g wsfdeploy -m 0750 /srv/we-sell-flavours
sudo GIT_SSH_COMMAND='ssh -i /root/.ssh/we-sell-flavours-deploy -o IdentitiesOnly=yes' \
  git clone git@github.com:Chileshe355/we_sell_flavours.git /srv/we-sell-flavours
sudo git -C /srv/we-sell-flavours remote -v
```

Verify a fetch works and an attempted dry-run push is rejected by repository permissions. Do not print the private key.

## Secrets, backups, and preflight

Install/copy the approved `deploy/inventory.env` and external `server.env`, then generate unique server secrets interactively:

```bash
sudo BASIC_AUTH_USER=tester /srv/we-sell-flavours/scripts/server/generate-secrets.sh /etc/we-sell-flavours/secrets
```

Because non-Swarm Compose file secrets retain host metadata, the generator grants WordPress/PHP UID 33 group-read access only to its database password and salts, and Nginx UID 101 group-read access only to the hashed basic-auth file. Root database, plaintext basic-auth, backup identity, and bootstrap material remain root-only.

Create the age backup identity outside Git, store only its public recipient in `BACKUP_AGE_RECIPIENT`, configure a non-root rclone destination in `BACKUP_REMOTE`, and restrict the identity/config files to root. Put the approved alert webhook URL in the external mode-`0600` file named by `ALERT_WEBHOOK_URL_FILE`. Validate rclone writes to the exact test backup prefix and send a controlled notification test before enabling timers.

For direct DNS, point the hostname at the inventoried origin IP and use `DNS_MODE=direct`. For the current Cloudflare-proxied hostname, keep the origin in `HETZNER_PUBLIC_IPV4`, set `DNS_MODE=cloudflare-proxied` and `DNS_PROVIDER=Cloudflare`, and ensure Cloudflare proxies HTTP/HTTPS to that origin. Preflight verifies the origin IP is assigned to the SSH host; in direct mode it also requires public DNS to return that IP. Run the read-only preflight:

```bash
sudo SERVER_ENV_FILE=/etc/we-sell-flavours/server.env \
  DEPLOY_INVENTORY_FILE=/srv/we-sell-flavours/deploy/inventory.env \
  /srv/we-sell-flavours/scripts/server/preflight.sh
```

Preflight rejects placeholders, production markers, unsafe secret modes, unpinned third-party images, exposed database/FPM ports, an incorrect origin/DNS relationship, low disk space, and unsafe backup settings before changing containers. Health checks validate both the Cloudflare-facing URL and the origin directly with the hostname/SNI override, so an edge certificate cannot hide a missing or invalid origin certificate.

## First deployment and TLS

Use the full reviewed commit SHA:

```bash
sudo SERVER_ENV_FILE=/etc/we-sell-flavours/server.env \
  DEPLOY_INVENTORY_FILE=/srv/we-sell-flavours/deploy/inventory.env \
  /srv/we-sell-flavours/scripts/server/tls-bootstrap.sh

sudo SERVER_ENV_FILE=/etc/we-sell-flavours/server.env \
  DEPLOY_INVENTORY_FILE=/srv/we-sell-flavours/deploy/inventory.env \
  /srv/we-sell-flavours/scripts/server/bootstrap-admin.sh

sudo /usr/local/sbin/wsf-deploy FULL_40_CHARACTER_COMMIT_SHA
```

The ACME bootstrap exposes only HTTP challenge/health responses and a 503 maintenance response until a trusted certificate exists. Normal Nginx then redirects HTTP to HTTPS, protects WordPress with basic authentication, emits no-index headers, and exempts only the exact challenge and health paths.

Retrieve the one-time administrator password through the approved secure channel before bootstrap; the bootstrap script deletes its file after successful use. Rotate it immediately in WordPress if it was ever disclosed to another operator.

## Verification

Run `scripts/server/health.sh`, `scripts/host/audit.sh`, and the acceptance checklist. Confirm:

- only SSH, HTTP, and HTTPS listen publicly, with SSH source-restricted;
- MariaDB and PHP-FPM have no host ports and Nginx has no database-network membership;
- anonymous HTTPS is challenged/denied, authenticated HTTPS succeeds, HTTP redirects, ACME and `/healthz` are narrowly exempt;
- PHP 8.3.36, WordPress 7.1.3, Imagick, mysqli, `utf8mb4`, the selected collation, pretty permalinks, staging identity, no indexing, and configured request limits pass;
- the deployed Git revision and resolved image identifiers are recorded under ignored `.deploy/releases/`;
- encrypted off-host backup, isolated restore drill, certificate renewal dry run, and rollback test have evidence.

Install timers only after manual backup and renewal checks pass:

```bash
sudo scripts/server/install-systemd.sh
```

## Routine deployment and rollback

Deploy only a reviewed full commit on the approved remote branch:

```bash
sudo /usr/local/sbin/wsf-deploy FULL_40_CHARACTER_COMMIT_SHA
```

The command fetches without merging, verifies ancestry, creates a verified off-host pre-change backup for a running database, records the existing WordPress version, uses a revision-specific application image tag, explicitly updates the persistent WordPress core files to 7.1.3, runs database upgrades, waits for health, and records release state.

Rollback code/images:

```bash
sudo /usr/local/sbin/wsf-rollback /srv/we-sell-flavours/.deploy/releases/previous.env
```

Rollback explicitly restores the recorded prior WordPress core version. Add `--restore-state` when the release introduced incompatible database/content changes; for the WordPress 7.1.3/PHP 8.3.36 rollout, use it if rollback is required after `core update-db` has run. This creates another safety backup and requires the restore command's exact `wsf-test` guard before replacing test state. Never point these commands at a production directory, project, hostname, or backup.
