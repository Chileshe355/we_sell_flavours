# Test server details

Last read-only verification: 2026-08-10

## Endpoint and SSH bootstrap access

- Origin IPv4: `41.222.36.110`
- Test hostname: `flavourz.cdkdev.co.za`
- Initial SSH user: `root` (bootstrap/recovery only; routine access will use `wsfdeploy`)
- SSH port: `22`
- Local PuTTY private key: `C:\Users\Admin\Desktop\servers\yoursolar.ppk`
- Matching user-key fingerprint: `SHA256:H99p/tpaH4JwEpza+IV660NbDmMx8+x+x5AtdYLkBTQ`
- Observed server RSA host-key fingerprint: `SHA256:tsK9u82p2hmYZ4uY88a0I/+Drffs3YqioVC8dIMCWHk`

Never copy the PPK into this repository or onto the application checkout. Verify the host-key fingerprint through the server provider console before treating it as trusted.

The owner approved reusing this existing 2048-bit RSA key for the initial `wsfdeploy` account. Once direct root SSH is disabled, rotate to a dedicated Ed25519 operator key during the next access review if practical.

## Confirmed host platform

- OS: Ubuntu 24.04 LTS (Noble), x86_64
- Kernel: `6.8.0-31-generic`
- Hostname: `flavourz.cdkdev.co.za`
- Capacity: 1 vCPU, 1.9 GiB RAM, no swap, 50 GB root disk (44 GB free when checked)
- Docker Engine: `29.1.3-0ubuntu3~24.04.2` from Ubuntu
- Docker Compose: `2.40.3+ds1-0ubuntu1~24.04.1`
- Docker Buildx: `0.30.1-0ubuntu1~24.04.1`

## DNS and current security state

The hostname is Cloudflare-proxied. Public DNS currently returns Cloudflare edge addresses rather than the origin IPv4, so deployment inventory must use `DNS_MODE=cloudflare-proxied`. Edge addresses may change and must not be used as the server identity.

At discovery time there were no Docker containers, images, or named volumes. UFW was not installed, SSH allowed direct root and password authentication, and 365 package upgrades were pending. These are provisioning/hardening tasks, not accepted steady-state settings.

## Provisioning state on 2026-08-10

- Root-only pre-provision baseline: `/root/wsf-baseline-before-provision-20260810.tar.gz`, SHA-256 `b2ffc23c7f0829d59323895c14f70036f2361c7e9523452184ffe0f05b951695`.
- Installed `age`, `fail2ban`, `rclone`, `ufw`, and their dependencies; upgraded eight TLS/cURL/Git foundation packages. The server still reports 357 packages not upgraded.
- Created `wsfdeploy`, installed the approved existing public key, and verified a second PPK-authenticated session.
- The operator is not in the Docker group, cannot read the Docker socket, cannot modify the root-owned deployment checkout, and has only the documented passwordless deployment/diagnostic sudo wrappers.
- Staged the reviewed 77-file bundle in `/srv/we-sell-flavours`; bundle SHA-256 is `c0d56850649cfeb26200dde405cf994c067801f9d7b51b236b0432633e17204f`. Server-side Compose validation passed.
- Generated unique mode-`0600` database, WordPress salt/key, one-time administrator, and basic-auth secret files under `/etc/we-sell-flavours/secrets` without printing their values.
- Staged `/etc/we-sell-flavours/server.env` with the confirmed staging hostname. TLS/admin email, off-host backup, age recipient, and alert destination remain intentionally incomplete.
- UFW remains inactive and direct root/password SSH remains enabled until approved SSH CIDRs, recovery access, and the hardening sequence are confirmed.

## Running test stack on 2026-08-10

- The server-side SCP release is committed locally at `50ac00084e844f543cc63538287cac8491424dd1`; it is not yet connected with a verified read-only GitHub deploy credential.
- MariaDB 11.4.12, WordPress 7.0.2 on PHP-FPM 8.2, and Nginx 1.30.4 are running and healthy. Only Nginx publishes host ports 80/443.
- WordPress is installed as a staging site at `https://flavourz.cdkdev.co.za`, uses locale `en_ZA`, pretty permalinks, `utf8mb4_unicode_520_ci`, no-index settings, and dashboard code modification restrictions.
- Let's Encrypt issued the origin certificate for `flavourz.cdkdev.co.za`; it expires on 2026-11-08. A renewal exercise passed without reloading Nginx because renewal was not due.
- HTTP returns 301 to HTTPS, anonymous HTTPS returns 401, `/healthz` returns `ok`, authenticated edge and direct-origin checks pass, and HSTS/no-index/content/frame headers are present.
- Basic-auth username is `tester`; the WordPress administrator is `testadmin`. Replacement credentials are mode `0600` files at `/home/wsfdeploy/.wsf-basic-auth-password` and `/home/wsfdeploy/.wsf-admin-password`. Retrieve and remove them after storing them in the approved password manager.
- The initial administrator password was exposed by unexpected WP-CLI prompt output and was immediately rotated. The exposed value is no longer valid and the temporary server secret was shredded.
- An encrypted backup completed and an isolated restore drill verified checksums, WordPress/database integrity, and cleanup without targeting the active `wsf-test` project.
- Backup and certificate-renewal systemd timers are enabled. Backup transfer currently uses an encrypted same-host mirror only; it is not an acceptable off-host disaster-recovery destination.
- Alert delivery currently points to an intentionally non-working local sink and must be replaced with an approved webhook.
- UFW is active with inbound deny by default, public TCP 80/443, and TCP 22 restricted to `197.185.251.136/32`. No Hetzner Cloud Firewall rule set was available to verify.
- A fresh `wsfdeploy` session succeeded after firewall activation. Direct root public-key login now fails and Fail2ban's SSH jail is active.
- The effective SSH audit printed `PasswordAuthentication yes` despite the installed `60-we-sell-flavours-hardening.conf` requesting `no`. No configured account currently has a usable password, but the corrected local provisioner now installs an earlier `00-` override; applying it on this host requires provider-console/root recovery access.
