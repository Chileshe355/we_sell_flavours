# SSH troubleshooting runbook

Collect read-only evidence before restarting, rebuilding, editing, restoring, or rotating anything. Commands shown here must run through the approved privileged path; Docker access is equivalent to host root.

The initial operator credential handoff files are `~/.wsf-basic-auth-password` and `~/.wsf-admin-password` for `wsfdeploy`. Copy them directly into the approved password manager without displaying them in shared logs, then delete both files. They are temporary delivery artifacts, not durable secret storage.

## Establish scope

Record UTC time, incident reporter, affected URL, expected release, and exact symptoms. Verify the host fingerprint when connecting:

```bash
date -u
hostnamectl
git -C /srv/we-sell-flavours rev-parse HEAD
sudo cat /srv/we-sell-flavours/.deploy/releases/current.env
```

The release state is non-secret. Do not share server environment files, `/run/secrets`, `/etc/we-sell-flavours`, Docker inspect output containing environment data, database dumps, backup identities, or full unreviewed logs.

## Read-only checks

```bash
sudo /usr/local/sbin/wsf-diagnose status
sudo /usr/local/sbin/wsf-diagnose logs nginx 200
sudo /usr/local/sbin/wsf-diagnose logs wordpress 200
sudo /usr/local/sbin/wsf-diagnose logs mariadb 200
sudo /usr/local/sbin/wsf-diagnose resources
df -h
free -h
uptime
sudo systemctl --failed --no-pager
sudo systemctl list-timers --all 'wsf-*'
sudo journalctl -u wsf-backup.service -u wsf-cert-renew.service --since '24 hours ago' --no-pager
```

Run the redacted health script and component checks:

```bash
sudo /usr/local/sbin/wsf-diagnose health
sudo /usr/local/sbin/wsf-diagnose certificate
```

Use containerized WP-CLI for non-mutating inspection:

```bash
sudo /usr/local/sbin/wsf-diagnose wp status
sudo /usr/local/sbin/wsf-diagnose wp checksums
```

## Symptom routing

- TLS/redirect failure: confirm DNS, port 80/443 firewalls, certificate dates, Certbot timer logs, Nginx config, and ACME-path access.
- 502 response: check WordPress health, FPM logs/status, application network membership, PHP resource exhaustion, and file ownership.
- Database connection error: check MariaDB health/disk, database network membership, secret-file presence/mode (not content), and recent migrations.
- Upload failure: compare Nginx `client_max_body_size` with PHP upload/post limits, disk/inodes, permissions, and configured conservative/parity profile.
- Plugin failure: record revision, plugin status, PHP logs, WordPress environment type, PHP extensions, and MariaDB compatibility assumptions; reproduce locally at the same commit.
- Backup failure: inspect bounded unit logs, disk, age recipient, rclone destination, remote permissions/quota, checksums, and last successful restore drill.

Do not edit files inside a running container as a fix. A diagnostic edit disappears on recreation and breaks revision evidence. Implement changes in Git, validate locally, deploy an explicit commit, and use rollback if the new release fails health gates.
