## Why

The project needs a reproducible WordPress platform for local plugin development and a Hetzner-hosted test server, without inheriting production identifiers or relying on manual, undocumented deployment steps. Establishing the container and operations contract now provides useful production parity while keeping the non-production system isolated and secure.

## What Changes

- Add a Docker Compose architecture for Nginx, WordPress 7.1.3 on PHP-FPM 8.3.36, and MariaDB, with persistent content and database storage on private container networks.
- Add environment-specific Compose configuration: a developer workflow with plugin source bind mounts and development tooling, and a server workflow with TLS, hardened exposure, restart policies, health checks, resource/log controls, and no direct database or PHP-FPM publication.
- Add secure configuration and secret handling that keeps credentials, WordPress salts, private keys, database data, uploads, backups, and generated runtime files out of Git.
- Add initial Hetzner test-server provisioning and deployment procedures over SSH, including least-privilege access, firewalling, Docker setup, private-repository checkout, DNS/TLS prerequisites, and environment validation.
- Add operational runbooks for deploys, upgrades, health checks, logs, WordPress CLI use, backups, restore drills, rollback, and SSH-based troubleshooting.
- Preserve relevant production compatibility targets documented in `docs/`: single-site WordPress behavior, pretty permalinks, Imagick, `utf8mb4`, and configurable upload/runtime limits, while documenting PHP 8.2.31 versus 8.3.36 and WordPress 6.8.7 versus 7.1.3 as explicit compatibility boundaries and without reusing production URLs or database details.
- Make the site URL, domain, TLS email, ports, secrets, sizing, and environment type explicit per environment so test and local instances cannot accidentally identify as production.

## Capabilities

### New Capabilities

- `wordpress-container-platform`: Defines the shared Nginx, WordPress/PHP-FPM, MariaDB, networking, persistence, compatibility, configuration, and health behavior.
- `local-plugin-development`: Defines the local developer lifecycle, plugin source mounting, development-only settings, tooling, and safe reset behavior.
- `secure-test-server-operations`: Defines secure Hetzner provisioning, SSH and Git access, TLS exposure, secret management, deployment, backup/restore, rollback, observability, and troubleshooting requirements.

### Modified Capabilities

None.

## Impact

- Adds Compose manifests, image/build configuration, Nginx and PHP configuration, environment templates, helper commands, ignore rules, and operational documentation to this repository.
- Introduces Docker Engine with the Compose plugin, Nginx, WordPress/PHP-FPM, MariaDB, WP-CLI, and an automated ACME-compatible certificate workflow as runtime dependencies.
- Affects developer machines and the designated Hetzner test server; the documented live production server is a compatibility reference only and is not changed by this proposal.
- Requires separately supplied test DNS, TLS contact details, SSH/Git credentials, WordPress administrator details, and generated application/database secrets before server deployment.
