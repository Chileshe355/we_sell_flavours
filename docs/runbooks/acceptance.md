# Acceptance checklist

Each OpenSpec scenario is mapped to an automated or manual gate. Record the date, operator, commit, test result, and evidence location for manual server items.

| Capability / scenario | Gate |
| --- | --- |
| Platform: rendered networks and ports | `scripts/test-stack.ps1` or `.sh` for local and server |
| Platform: test identity / unsafe identity | server static test plus `scripts/server/preflight.sh` negative test |
| Platform: runtime compatibility | image build, local runtime test, and `scripts/server/health.sh` |
| Platform: recreation persistence | `scripts/test-stack.ps1 -Environment local -Runtime` |
| Platform: reproducible release | static digest test plus deployment release records |
| Platform: database not ready | stop MariaDB in an isolated project and confirm health/deploy gate fails |
| Platform: sensitive paths | local runtime test; repeat authenticated/anonymous on server |
| Local: clean start | clean checkout, `local init`, `local up`, `local bootstrap` |
| Local: live plugin edit | create/edit a plugin file and verify matching bytes inside WordPress |
| Local: development-only settings | local/server static comparison |
| Local: safe ports | local static test and host listener inspection |
| Local: containerized tooling | local bootstrap and `local wp plugin list` |
| Local: ordinary stop / guarded reset | verify volumes after `down`; test cancel and exact confirmed reset |
| Server: host baseline | `scripts/host/audit.sh` plus Hetzner firewall comparison |
| Server: SSH hardening | second-session login, negative password/root tests |
| Server: read-only Git access | fetch succeeds and dry-run push is rejected |
| Server: missing secret / secret scan | preflight negative fixture plus `scripts/check-secrets.*` |
| Server: HTTPS access control | anonymous challenge/deny and authenticated success |
| Server: certificate renewal | `renew-cert.sh`, certificate dates, conditional reload logs |
| Server: DNS mismatch | preflight negative test before cutover |
| Server: initial deployment | explicit revision record and all health gates |
| Server: failed release | isolated bad-health deployment and recorded rollback result |
| Server: scheduled backup | encrypted local/off-host artifact and checksum evidence |
| Server: restore drill | `restore.sh BACKUP --isolated` and active-project before/after evidence |
| Server: SSH diagnostics | follow troubleshooting runbook without disclosing secret material |
| Server: security update | pinned update test/deploy/rollback record |
| Server: production input | preflight negative test using protected hostname/environment marker |

Minimum release acceptance is strict OpenSpec validation, repository secret check, Bash syntax/ShellCheck where available, local and server Compose render tests, successful custom image build, healthy local stack, WP-CLI bootstrap, runtime/persistence/sensitive-path tests, and plugin checks. Server readiness additionally requires the host, SSH/Git, DNS/TLS/access, backup/restore, monitoring, rollback, and handoff rows above.
