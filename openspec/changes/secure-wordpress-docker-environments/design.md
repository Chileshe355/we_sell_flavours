## Context

The repository has no container implementation yet. Its `docs/` directory records the live site's runtime characteristics: single-site WordPress, PHP-FPM 8.2, Nginx-compatible pretty permalinks, Imagick, `utf8mb4`, and relatively high configurable PHP upload and execution limits. Production connection identifiers and URLs are reference data only. The target change must support two trust levels: an ergonomic local environment for plugin work and an internet-facing test environment on a Hetzner host administered over SSH.

Stakeholders are plugin developers and the operator responsible for initial provisioning, deployment, maintenance, and incident debugging. The exact test hostname, server image/IP, deploy branch, plugin source layout, and whether sanitized seed content is required are not yet known, so the implementation must expose these as documented inputs rather than hard-code guesses.

## Goals / Non-Goals

**Goals:**

- Provide one version-controlled, reproducible container stack with explicit local and server overlays.
- Match the relevant production PHP, WordPress, database character-set, permalink, and media-processing behavior closely enough for plugin testing.
- Expose only Nginx on the server and protect the test site, credentials, and persistent data using defense in depth.
- Make initial Hetzner provisioning, private Git checkout, TLS bootstrap, deployment, backup/restore, rollback, and SSH troubleshooting repeatable.
- Keep environment identity and secrets separate so local/test actions cannot target or impersonate production.

**Non-Goals:**

- Changing or deploying to the live production server.
- Copying production secrets, database identifiers, personal data, domain names, certificates, or SSH keys.
- Designing a multi-host, high-availability, autoscaling, or Kubernetes platform.
- Automating production data migration; any future test data import must be explicitly approved and sanitized.
- Developing the WordPress plugins themselves.

## Decisions

### Layered Compose model

Use a shared `compose.yaml` for Nginx, WordPress/PHP-FPM, MariaDB, private networks, named volumes, health checks, and common configuration. Add a local override and a server override selected by explicit wrapper commands or Compose file arguments. Each environment receives a unique Compose project name so networks and volumes cannot collide.

This keeps service definitions aligned while making riskier local behaviors, such as source bind mounts and debugging, structurally absent from the server configuration. Separate unrelated Compose projects were rejected because they would drift; Compose profiles alone were rejected because accidental profile selection is less obvious than an explicit environment command.

### Service topology and traffic boundaries

Nginx is the only public entry point. It sends PHP requests to WordPress over FastCGI on an application network. WordPress reaches MariaDB on a separate private database network, while Nginx has no database membership. Neither PHP-FPM nor MariaDB publishes a host port. The local override binds HTTP to loopback; the server binds only HTTP/HTTPS and uses both the Hetzner Cloud Firewall and a host firewall to restrict all other inbound traffic. Containers do not receive the Docker socket.

A combined Apache/WordPress image was rejected because Nginx is a stated requirement and PHP-FPM better matches the documented production SAPI. Publishing MariaDB locally by default was rejected because WP-CLI and database administration can run through Compose without widening access.

### Images, compatibility, and updates

Build a small project WordPress image from the official WordPress 7.1.3/PHP 8.3 FPM base that was runtime-verified as PHP 8.3.36, ensuring required extensions such as Imagick are present. Use official Nginx, MariaDB, and certificate-client images. Pin image releases to reviewed immutable versions (digest where practical), assert the exact PHP patch version, record the selected WordPress and MariaDB versions, and update them through a deliberate pull/build/test/deploy change rather than floating `latest` tags. The recorded production PHP 8.2.31 and WordPress 6.8.7 remain compatibility references rather than test-stack pins.

The production database report is MySQL-family and uses `utf8mb4`; the requested test database is MariaDB. The implementation will select a maintained MariaDB release and run plugin schema/query compatibility tests before data import. Exact engine-version equivalence is not claimed.

### WordPress files and persistence

Persist MariaDB data and the WordPress shared document root using named volumes, with plugin source overlaid from the repository at the documented plugin path for local development. Local plugin mounts are writable for immediate feedback. On the staging server, plugins use a dedicated persistent writable volume so authorized WordPress administrators can install, update, and edit plugins and themes through the dashboard. Uploads, themes, and other intended runtime content remain persistent. This staging-only convenience treats every administrator as trusted code-execution access and is not a production default.

Use explicit UID/GID-compatible ownership and narrow filesystem permissions. Nginx configuration denies access to dotfiles, environment files, backup/archive formats, configuration artifacts, and executable PHP within uploads. It also applies request-size/time limits aligned with PHP; the production-like high upload limit remains configurable rather than universally enabled.

Bundling database state into an image was rejected because it prevents safe persistence and backup. Mounting the entire repository as a writable server webroot was rejected because a web compromise could modify deployed source.

### Configuration and secrets

Commit only non-secret examples. Generate unique database passwords, WordPress salts/keys, test-site access credentials, and administrator bootstrap credentials per environment. Server secrets live in root/deploy-owner-readable files outside the Git working tree and are mounted read-only under `/run/secrets`; startup configuration reads them from files rather than placing secret values in Compose YAML or command history. The repository ignore rules cover real environment files, secret directories, private keys, certificates, dumps, archives, and generated content.

Local development uses clearly fake local-only values from an ignored local environment file. Server startup fails closed when required values or secret files are missing. Logs and diagnostics must redact secret values. A one-time WP-CLI bootstrap passes administrator credentials without committing them and removes/rotates the bootstrap material afterward.

Environment variables alone were rejected for durable server secrets because they are easier to expose in process/container inspection. Docker Swarm secrets were not selected because the target is a single Compose host; file-backed Compose secrets preserve a simple deployment model.

### TLS and test-site access

The server uses a dedicated test hostname supplied at deployment time. Nginx redirects HTTP to HTTPS, except for ACME HTTP-01 challenges, and serves a valid automatically renewable certificate. A host systemd timer invokes a one-shot certificate-renewal Compose command and reloads Nginx only after successful renewal. The site sets its WordPress home/site URLs from the test hostname, uses the `staging` environment type, discourages indexing, emits `X-Robots-Tag: noindex, nofollow`, and is protected by Nginx basic authentication or an explicit IP allowlist; the ACME path and operational health probe are narrowly exempted as required.

Self-signed server certificates were rejected because they train operators to bypass browser warnings. Embedding a perpetual sleep loop in a privileged certificate container was rejected in favor of an auditable host timer.

### Host and SSH hardening

Provision a supported minimal Linux image, install Docker Engine, Compose v2, and Buildx as one supported package family (Ubuntu-supported packages on the confirmed Ubuntu 24.04 host), enable unattended security patches, and configure time synchronization and persistent logs. Do not mix Ubuntu `docker.io` packages with Docker CE repository packages during an in-place deployment. Create a named non-root operator/deploy account with SSH public-key authentication. Disable direct root login and password authentication only after a second key-authenticated session is verified. Restrict SSH at the Hetzner firewall to approved source ranges where operationally possible, mirror the allowlist in the host firewall, and rate-limit or ban repeated authentication failures.

Use a repository-scoped read-only Git deploy key or short-lived credential on the server. Store host fingerprints deliberately and verify the Git server fingerprint; do not disable host-key checking. Keep the deployment checkout, Git credential, and privileged wrapper targets root-owned so the operator cannot replace code that sudo executes. Docker access is root-equivalent, so routine deployment uses narrowly documented passwordless `sudo` wrappers rather than casually granting broad Docker-group membership.

### Deployment and rollback

Deployment checks out an explicit reviewed commit from the designated test branch, validates rendered Compose configuration without printing secrets, builds/pulls pinned images, creates a pre-deploy backup, runs database/plugin upgrade steps explicitly, starts services, and gates success on container and HTTPS application health. It records the deployed Git revision and image identifiers.

Rollback restores the prior Git revision and image identifiers first. If a deployment made incompatible database or persistent-file changes, the operator stops writers and restores the matching pre-deploy database/content backup before bringing the previous stack up. Deployment must never operate on a directory, hostname, Compose project, or volume whose environment marker is `production`.

### Operations and observability

Provide documented commands for status, redacted effective configuration, bounded logs, Nginx/PHP/MariaDB checks, WP-CLI, database backup, content backup, restore verification, certificate status, deployment, and rollback. Health checks distinguish container/process readiness from an HTTPS end-to-end check. Configure log rotation and container resource limits appropriate to the actual server size. Backups are timestamped, encrypted, integrity-checked, retained by policy, and copied off-host; scheduled restore drills prove recoverability.

The runbook will ask operators to collect status and bounded logs before changing state, and will identify which artifacts are safe to share. Direct edits inside running containers are treated as temporary diagnostics and are not a deployment method.

## Risks / Trade-offs

- [MariaDB behavior differs from the production MySQL-family server] -> Pin a maintained MariaDB release, use `utf8mb4`, test plugin migrations/queries, and document that engine-specific behavior needs separate verification.
- [A shared WordPress volume can retain stale core files across image changes] -> Add version checks and an explicit, backed-up core upgrade procedure; fail deployment on unexpected version drift.
- [High upload/time limits increase denial-of-service impact] -> Keep limits configurable, set conservative defaults, align Nginx/PHP values, protect the test site, and cap container resources.
- [A server compromise can expose file-backed Compose secrets] -> Limit file ownership/mode, mount secrets read-only, minimize host users, patch regularly, restrict network access, and rotate secrets after an incident.
- [Docker privileges can become host root] -> Avoid broad Docker-group access and document narrowly scoped privileged operations.
- [Basic authentication can interfere with ACME or health checks] -> Exempt only exact challenge/probe locations and test certificate renewal and external health during acceptance.
- [Local/server parity is intentionally imperfect] -> Keep core services and PHP extensions shared, document every override, and include a server-like validation command before deployment.
- [Unattended upgrades can restart services unexpectedly] -> Limit automation to host security policy, schedule maintenance, and keep application/container upgrades deliberate and rollback-capable.

## Migration Plan

1. Resolve the test hostname, server OS/IP and sizing, SSH source ranges, deploy branch, plugin paths, backup destination/retention, and access-control method.
2. Implement and validate the shared and local Compose files on a developer machine using synthetic content and local-only secrets.
3. Provision the Hetzner host, verify key-based operator access, apply firewall/SSH hardening, install Docker/Compose, and configure the read-only repository credential.
4. Point the test DNS record at the server, create server environment/secret files outside Git, validate configuration, and bootstrap TLS.
5. Deploy an explicit commit, initialize WordPress through WP-CLI, confirm environment identity and no-index/access controls, and run functional/security acceptance checks.
6. Run and verify database/content backups, perform a restore drill into an isolated disposable Compose project, and record the recovery result.
7. Enable scheduled backup, certificate renewal, health, log rotation, and patch jobs; document the deployed revision and operator handoff.

Rollback before DNS cutover is to destroy only the new, explicitly named test project and host. After cutover, restore the previous known-good commit/images; if state changed incompatibly, restore its paired backup before restarting. DNS can be directed to a maintenance response while recovery occurs. Production remains untouched throughout.

## Open Questions

- What test hostname and certificate contact email will be used?
- Which supported Linux distribution/image, server size, public IPs, and SSH source ranges are assigned on Hetzner?
- Which Git branch or release convention is deployable, and what is the repository's plugin source path?
- Should test content start empty or come from a separately approved, sanitized export?
- Is Nginx basic authentication sufficient, or is an IP/VPN allowlist required?
- What encrypted off-host backup destination, retention window, and recovery objectives apply?
