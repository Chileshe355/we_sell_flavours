# We Sell Flavours WordPress environments

This repository defines a shared Nginx + WordPress 7.1.3/PHP-FPM 8.3.36 + MariaDB stack, with explicit overrides for local plugin development and a hardened Hetzner test server. Production architecture documents are compatibility references only; this automation rejects production-marked targets.

## Local quick start

Requirements: Docker Engine/Desktop with Docker Compose v2, Git, and either PowerShell 5.1+ or Bash.

PowerShell:

```powershell
./scripts/local.ps1 init
./scripts/local.ps1 up
./scripts/local.ps1 bootstrap
```

Bash:

```bash
./scripts/local.sh init
./scripts/local.sh up
./scripts/local.sh bootstrap
```

Open `http://127.0.0.1:8080`. The example login is intentionally local-only: `localadmin` / `local-development-only`. Copy `.env.local.example` to the ignored `.env.local` and change those values if other machines can access your Docker host.

Put plugin folders under `plugins/`; changes are visible to local WordPress without rebuilding. The server mounts the same checked-out plugin directory read-only.

Useful actions are `config`, `up`, `down`, `rebuild`, `status`, `logs`, `bootstrap`, `wp`, `plugin-check`, `check`, and the guarded destructive `reset`. For example:

```powershell
./scripts/local.ps1 wp plugin list
./scripts/local.ps1 wp core verify-checksums
./scripts/local.ps1 wp cache flush
./scripts/local.ps1 plugin-check your-plugin-folder
```

`plugin-check` syntax-checks every PHP file and runs the plugin's executable `vendor/bin/phpunit` when present. Project-specific Composer/npm setup remains owned by the plugin.

For an explicit large-media compatibility run matching the recorded production PHP limits, add `--env-file config/production-parity.env.example` after `.env.local` in the Compose command. These 1 GiB upload limits are intentionally opt-in because they increase resource-exhaustion risk.

`down` preserves named volumes. `reset` names the project and its volumes and requires confirmation unless `-Force` (PowerShell) or `--force` (Bash) is supplied.

## Server deployment

Do not run server commands until `deploy/inventory.env`, an external server environment file, and the external secret directory are complete. See `docs/runbooks/deployment.md`; host and live deployment steps are intentionally gated on explicit SSH and Hetzner details.


## SSH bootstrap note

The current PuTTY PPK path and verified non-secret fingerprints are recorded in `docs/Server details.md`; the private key must never be copied into Git. Direct `root` access is temporary bootstrap/recovery access only. Follow `docs/runbooks/deployment.md` to create the named `wsfdeploy` account, verify a second key-authenticated session, and only then disable password authentication and direct root login without risking lockout.
