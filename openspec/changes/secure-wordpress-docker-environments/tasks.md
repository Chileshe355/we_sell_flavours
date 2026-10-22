## 1. Resolve Inputs and Repository Safety

- [ ] 1.1 Record the approved test hostname, TLS contact email, Hetzner OS/IP/size, SSH allowlist, deploy branch, plugin source paths, site access method, backup destination/retention, and recovery objectives in a non-secret deployment inventory.
- [x] 1.2 Select and document reviewed WordPress/PHP-FPM, Nginx, MariaDB, WP-CLI, and ACME client versions/digests, including the MariaDB-versus-production compatibility boundary and update policy.
- [x] 1.3 Create the container, configuration, script, test, and runbook directory layout plus committed local/server environment templates containing no real credentials or production defaults.
- [x] 1.4 Extend Git ignore rules for real environment files, secrets, private keys, certificates, database dumps, backups, uploads, generated runtime files, and deployment state; verify ignored fixtures and a repository secret scan.

## 2. Build the Shared WordPress Platform

- [x] 2.1 Add the pinned WordPress 7.1.3/PHP 8.3.36 FPM image build with mysqli, Imagick, required health tooling, explicit ownership, and an exact build-time extension/version check.
- [x] 2.2 Add aligned PHP and PHP-FPM configuration for conservative runtime/upload defaults and an explicit production-parity large-media option.
- [x] 2.3 Add the hardened Nginx base configuration for FastCGI WordPress routing, pretty permalinks, aligned request limits, dotfile/config/archive denial, upload-PHP denial, security headers, and a non-secret health endpoint.
- [x] 2.4 Add the shared Compose manifest with pinned services, application/database network separation, no PHP-FPM or MariaDB host ports, no Docker socket mounts, named persistent volumes, health checks, dependency readiness, restart policy, and explicit environment-scoped names.
- [x] 2.5 Implement file-backed secret loading for MariaDB, WordPress database access, WordPress salts/keys, and server access authentication, with fail-closed validation and redacted errors.
- [x] 2.6 Add WordPress runtime configuration for explicit home/site URLs, environment type, locale, `utf8mb4` database settings, server-side code-edit restrictions, and selectable debugging behavior.
- [x] 2.7 Add a version-aligned WP-CLI service/profile and commands that operate through the same WordPress files, network, database, and secret sources.
- [x] 2.8 Add automated checks for image pins, service networks/ports, container health, required PHP extensions, database charset/collation, permalink routing, request-limit alignment, persistence across recreation, and sensitive-path rejection.

## 3. Implement the Local Plugin Workflow

- [x] 3.1 Add the local Compose override with loopback-only Nginx publication, clearly local-only configuration, writable plugin source bind mounts, development logging, and no default PHP-FPM or database publication.
- [x] 3.2 Add cross-platform documented wrapper commands for local configuration validation, start, stop, rebuild, status, bounded logs, and a server-like acceptance run.
- [x] 3.3 Add an idempotent WP-CLI local bootstrap that installs single-site WordPress with the local URL/locale and activates configured plugins without requiring host PHP or database tools.
- [x] 3.4 Add documented containerized WP-CLI commands for plugin activation, cache cleanup, database inspection, WordPress integrity checks, and plugin test/lint hooks.
- [x] 3.5 Implement a guarded local reset that displays the resolved local project and volumes, requires confirmation or an explicit force flag, and rejects server/production environment markers.
- [x] 3.6 Verify from a clean checkout that local startup is one command after configuration, a host plugin edit is immediately visible, ordinary stop preserves data, reset affects only local volumes, and only loopback web access is published.

## 4. Implement the Hardened Server Configuration

- [x] 4.1 Add the server Compose override with HTTP/HTTPS Nginx publication, persistent writable staging plugin storage, explicitly enabled staging dashboard package installation/editing, conservative Linux capabilities/security options, resource limits, restart policies, and rotated bounded logs.
- [x] 4.2 Implement the server preflight command to verify environment identity, reject production-marked inputs, validate hostname/DNS/host identity, check secret file ownership/modes, confirm image pins, render Compose safely, and check disk/backup capacity before mutation.
- [x] 4.3 Add secure secret-generation and one-time WordPress administrator bootstrap procedures that avoid command history/log exposure and remove or rotate bootstrap material after success.
- [x] 4.4 Add Nginx test-site protection using the approved basic-authentication or IP-allowlist method, `X-Robots-Tag` headers, WordPress search-engine discouragement, and exact ACME/health exceptions.
- [x] 4.5 Add the ACME HTTP-01 bootstrap/renewal workflow, certificate validation, conditional Nginx reload, and root-owned systemd service/timer units.
- [x] 4.6 Add a deployment command that accepts an explicit Git revision, records Git/image identifiers, validates preconditions, creates a pre-change backup when needed, updates/builds services, runs explicit WordPress/database upgrade steps, and gates completion on container plus authenticated HTTPS health.
- [x] 4.7 Add a rollback command that selects the recorded prior release, restores matching images/source, restores paired database/content state when required, and refuses ambiguous or non-test targets.
- [x] 4.8 Verify the rendered server configuration has no development-only settings, no production identifiers, no secret values, no Docker socket, no host port for PHP-FPM/MariaDB, and no unnecessary writable code mount.

## 5. Provision and Harden the Hetzner Host

- [x] 5.1 Write an idempotent host-provisioning runbook/script for the selected supported Linux image covering vendor Docker/Compose installation, security updates, time synchronization, filesystem layout, persistent bounded logs, and required system packages.
- [ ] 5.2 Define and verify Hetzner Cloud Firewall and host firewall rules that allow HTTP/HTTPS, restrict SSH to approved ranges where possible, and deny other unsolicited inbound traffic.
- [x] 5.3 Create the named non-root operator/deploy account with individual SSH keys and narrowly scoped privileged deployment operations, documenting that Docker access is host-root-equivalent.
- [ ] 5.4 Harden SSH in two verified stages: confirm a second key-authenticated session, then disable password authentication and direct root login and enable authentication abuse protection without losing operator access.
- [ ] 5.5 Configure the repository-scoped read-only Git deploy credential, pin/verify the Git server host key, clone into the approved deployment path, and prove that the credential cannot push.
- [ ] 5.6 Audit the provisioned host against the baseline and record OS patch state, time sync, firewall state, SSH policy, Docker/Compose versions, listening ports, filesystem permissions, and log limits.

## 6. Implement Backups, Restore, and Monitoring

- [x] 6.1 Add a consistent MariaDB dump and required WordPress-content backup command with timestamp, environment identifier, release metadata, failure cleanup, and no plaintext credentials in output.
- [x] 6.2 Add encryption, checksums, configurable retention, and transfer to the approved off-host destination; fail the job if integrity verification or off-host transfer fails.
- [x] 6.3 Add a restore command that verifies/decrypts a selected backup and defaults to newly named isolated Compose volumes, requiring an additional explicit guard for any in-place test restore.
- [x] 6.4 Add root-owned scheduled backup and certificate-renewal services/timers plus actionable failure and certificate-expiry monitoring using the approved notification destination.
- [x] 6.5 Perform and record an isolated restore drill that verifies WordPress/database integrity and sample content while proving the active stack was unchanged.

## 7. Complete Operations Documentation and Automated Validation

- [x] 7.1 Write the deployment runbook for prerequisites, secret placement, private Git checkout, DNS, TLS bootstrap, initial WP-CLI setup, deploy, verification, routine update, rollback, and production-isolation checks.
- [x] 7.2 Write the SSH troubleshooting runbook with read-only-first commands for release identity, service health, bounded/redacted logs, disk/resources, Nginx, PHP-FPM, MariaDB, certificates, WP-CLI, and HTTPS behavior; document that container edits are non-persistent diagnostics.
- [x] 7.3 Write the security/maintenance runbook for host patches, pinned image and WordPress updates, access review, secret rotation, backup monitoring, restore drills, incident rotation/recovery, and emergency-update recording.
- [x] 7.4 Add CI or repeatable local validation for Compose rendering in both environments, configuration linting, shell linting/tests, secret scanning, image pin enforcement, local smoke tests, and server security assertions using non-secret fixtures.
- [x] 7.5 Add an acceptance checklist mapping every OpenSpec scenario to an automated check or a documented manual verification and run the full local/server-like suite.

## 8. Deploy and Hand Off the Test Server

- [x] 8.1 Confirm explicit authorization and current SSH access details, snapshot or otherwise establish a recoverable Hetzner baseline, and run read-only discovery before provisioning changes.
- [ ] 8.2 Apply the reviewed host provisioning and hardening over SSH, keeping a verified recovery session available until key access, sudo boundaries, and both firewalls pass validation.
- [ ] 8.3 Configure the approved DNS record, server environment and secret files outside Git, test-site access control, encrypted off-host backup destination, and scheduled operations.
- [ ] 8.4 Deploy the approved Git revision, obtain and verify TLS, bootstrap WordPress, run all service/security/plugin acceptance checks, and record the revision, image identifiers, and non-secret configuration summary.
- [ ] 8.5 Execute a backup plus isolated restore drill, test certificate renewal, test application rollback, and correct any issues found before declaring the test environment ready.
- [ ] 8.6 Deliver the operator handoff with access ownership, recovery path, scheduled-job status, backup/restore evidence, known MariaDB compatibility limits, unresolved risks, and the SSH debugging workflow.
