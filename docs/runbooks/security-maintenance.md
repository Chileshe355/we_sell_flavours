# Security and maintenance runbook

## Schedule

- Daily: review backup/renewal timer failures, external health result, disk pressure, and authentication anomalies.
- Weekly: review pending Ubuntu security updates, container/WordPress/plugin advisories, certificate lifetime, firewall drift, and failed SSH bans.
- Monthly: apply approved host maintenance, review operator/deploy keys and repository access, update pinned images/plugins as needed, and test alert delivery.
- Quarterly or at the approved interval: run an encrypted backup plus isolated restore drill, record RPO/RTO results, test application rollback and certificate renewal, and review this threat model.

Host security updates use Ubuntu's unattended-security policy; schedule reboots and verify services afterward. WordPress core, MariaDB, Nginx, WP-CLI, and Certbot changes are deliberate: update tags and immutable digests with upstream notes, run static/local/server-like checks, back up, deploy through health gates, and preserve rollback state. Authorized staging administrators may install, update, and edit plugins/themes through the dashboard; record and test those changes because they live in persistent content storage outside the Git release. Treat every staging administrator as having application code-execution access, and do not carry this staging-only policy into production by default.

## Access and secrets

Review individual SSH public keys, the read-only Git deploy key, GitHub repository access, sudoers wrappers, Hetzner console users/tokens, basic-auth users, WordPress administrators, rclone credentials, and age identities. Remove stale access promptly.

Rotate database passwords and WordPress salts/keys during a planned window because salts invalidate sessions and database changes require coordinated service updates. Rotate the basic-auth password and WordPress administrator password independently. After suspected compromise, rotate SSH/Git/Hetzner credentials, all application secrets, TLS material when indicated, and backup credentials/identities; rebuild from a trusted revision and restore only a verified pre-incident backup.

Never commit or paste secret files into tickets or chat. Share bounded, reviewed logs and non-secret release/configuration summaries only.

## Backup assurance

A successful job means encrypted artifacts and checksum metadata reached the configured non-root off-host prefix. A file existing locally is not sufficient. Monitor failed systemd units and backup age. Restore drills must use a new `wsf-restore-*` project by default and prove the active `wsf-test` project was untouched. An in-place restore requires an additional safety backup and exact project-name confirmation.

## Emergency updates

Record the advisory, decision maker, scope, skipped checks, current release, backup identifier, emergency commit/digests, verification evidence, and rollback result. Run omitted checks as soon as the immediate exposure is controlled. Emergency status does not authorize production changes or bypass environment-identity guards.
