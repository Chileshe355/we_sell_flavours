## ADDED Requirements

### Requirement: Hardened Hetzner host baseline
The test host SHALL use a supported minimal Linux release with security updates, time synchronization, firewalling, bounded persistent logs, and vendor-supported Docker Engine and Compose packages. The Hetzner firewall and host firewall SHALL allow public HTTP/HTTPS and SHALL restrict SSH to approved source ranges where operationally possible; all other unsolicited inbound traffic MUST be denied.

#### Scenario: Host baseline is audited
- **WHEN** initial provisioning completes
- **THEN** the operator can verify patch policy, clock synchronization, active firewall rules, Docker/Compose versions, listening ports, and log limits against the runbook

### Requirement: Least-privilege SSH and Git access
Operators SHALL authenticate over SSH with individual public keys to a named non-root account. Direct root login and password authentication MUST be disabled only after a second key-authenticated session succeeds. Git checkout SHALL use a repository-scoped read-only deploy credential with host-key verification enabled, and Docker privilege SHALL be limited to documented deployment operations.

#### Scenario: SSH hardening is applied safely
- **WHEN** the operator verifies a second key-authenticated session and applies the hardened SSH configuration
- **THEN** password and direct-root authentication fail while the approved non-root key remains usable

#### Scenario: Server fetches repository content
- **WHEN** the deploy account fetches the configured private repository
- **THEN** the Git server fingerprint is verified and the credential cannot write to unrelated repositories

### Requirement: Secret lifecycle
Server database passwords, WordPress salts/keys, site-access credentials, administrator bootstrap material, private keys, and certificate private material SHALL be unique to the test environment, absent from Git and image layers, stored with restrictive host permissions, and mounted/read as files where supported. Startup MUST fail closed when required secrets are missing, and operational output MUST not print secret values.

#### Scenario: Required secret is absent
- **WHEN** the server configuration is validated with a missing or unreadable required secret file
- **THEN** deployment stops before services are changed and reports only the secret name/path requirement, not any secret contents

#### Scenario: Repository is scanned for secret material
- **WHEN** the pre-deployment secret and ignore-rule check runs
- **THEN** real environment files, keys, certificates, database dumps, backups, uploads, and generated runtime files are not tracked

### Requirement: Authenticated HTTPS test endpoint
The test server SHALL use a dedicated configured hostname, redirect HTTP to HTTPS except where ACME validation requires HTTP, serve a trusted automatically renewable certificate, and reload Nginx only after successful renewal. The site SHALL identify as staging, discourage WordPress indexing, emit a no-index response header, and require Nginx basic authentication or an approved IP allowlist except for narrowly defined challenge and health paths.

#### Scenario: Anonymous visitor opens the test hostname
- **WHEN** an unauthenticated and non-allowlisted visitor requests site content
- **THEN** access is denied or challenged over HTTPS and the response does not expose WordPress content

#### Scenario: Certificate renewal is exercised
- **WHEN** the scheduled renewal command runs before certificate expiry
- **THEN** renewal is attempted without exposing secrets, Nginx reloads only for a valid renewed certificate, and the HTTPS health check remains successful

### Requirement: Guarded initial deployment
Initial deployment SHALL validate DNS, host identity, the environment marker, required configuration, secret file permissions, rendered Compose configuration, image pins, and available backup/storage capacity before changing services. It SHALL deploy an explicit reviewed Git revision and SHALL initialize WordPress using the configured test URL and a one-time administrator credential.

#### Scenario: DNS points elsewhere
- **WHEN** initial deployment validation finds that the configured hostname does not resolve to the target server as expected
- **THEN** TLS bootstrap and public stack activation stop with a corrective diagnostic

#### Scenario: Initial deployment succeeds
- **WHEN** every prerequisite passes and the explicit revision is deployed
- **THEN** all container health checks and the authenticated HTTPS end-to-end check pass, the deployed revision/images are recorded, and bootstrap administrator material is removed or rotated

### Requirement: Repeatable deployment and rollback
Each server update SHALL validate an explicit Git revision, preserve local server secrets and persistent data, create a verified pre-change backup when state can change, and gate success on service and HTTPS health checks. A documented rollback SHALL restore the matching prior revision and image identifiers and, when required by incompatible state changes, the paired database/content backup.

#### Scenario: Updated application fails health checks
- **WHEN** a deployment does not pass its health gates within the documented timeout
- **THEN** the operation is marked failed, diagnostic logs are retained, and the operator can invoke rollback to the recorded prior release without targeting another environment

### Requirement: Backup and restore assurance
The server SHALL create consistent timestamped backups of MariaDB and required WordPress content, encrypt them, integrity-check them, retain them according to configured policy, and copy them to an approved off-host destination. The runbook SHALL include a scheduled restore drill into an isolated disposable project that never overwrites the active stack.

#### Scenario: Scheduled backup completes
- **WHEN** the backup job runs successfully
- **THEN** encrypted database and content artifacts, checksums, timestamp, environment identifier, and restore metadata exist off-host and expired sets are pruned according to policy

#### Scenario: Restore drill runs
- **WHEN** an operator follows the restore-drill procedure using a selected backup set
- **THEN** the data is restored into newly named isolated volumes, WordPress integrity and sample content are verified, and the active test stack remains unchanged

### Requirement: Secure diagnostics and observability
The operations runbook SHALL provide SSH-based commands for service status, bounded and redacted logs, non-secret effective configuration, resource/disk usage, certificate status, Nginx/PHP/MariaDB diagnostics, WP-CLI, and end-to-end health. Routine debugging MUST begin with read-only evidence collection, and edits inside running containers MUST NOT be treated as persistent fixes.

#### Scenario: Site returns an error
- **WHEN** an operator follows the incident checklist over SSH
- **THEN** the operator can identify the deployed revision, service health, recent bounded logs, storage/resource pressure, database connectivity, and HTTPS response without revealing credentials

### Requirement: Security maintenance
The server SHALL document host patching, pinned container/application update checks, certificate expiry monitoring, backup failure monitoring, access review, and credential rotation. Security-relevant updates SHALL be tested locally or in an isolated validation project before the controlled server rollout, except when an emergency procedure explicitly records the deviation.

#### Scenario: A container security update is available
- **WHEN** the operator prepares the update
- **THEN** the new pinned image is tested, backed up, deployed through health gates, recorded, and remains rollback-capable

### Requirement: Production isolation
Server automation MUST NOT reuse or default to production hostnames, database identifiers, credentials, volumes, Compose project names, or unsanitized production data. Any future production-derived content import SHALL require explicit approval, a documented sanitization step, and a disposable pre-import backup.

#### Scenario: Production-marked input is detected
- **WHEN** validation detects a production hostname, environment marker, or protected resource identifier in the test deployment inputs
- **THEN** the operation stops before connecting to or modifying the resource and identifies the conflicting non-secret field
