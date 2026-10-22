# Deployment inventory

The authoritative non-secret template is `deploy/inventory.example.env`. Copy it to the ignored `deploy/inventory.env` and replace every `TBD` before any server mutation.

The inventory intentionally contains no passwords, tokens, deploy private keys, WordPress salts, administrator credentials, certificate private keys, or backup encryption identities. Those belong in the server secret path documented by the deployment runbook.

Required approval inputs are the dedicated test hostname and TLS email, DNS mode/provider, Hetzner server identity and addresses, supported OS and size, initial and operator SSH identities plus verified key fingerprints and source CIDRs, deploy branch, plugin source path, test-site access method, encrypted off-host backup destination and retention, recovery objectives, and whether the site starts empty or from a separately approved sanitized export.

The current ignored `deploy/inventory.env` records the values confirmed by read-only discovery on 2026-08-10. It deliberately retains `TBD` for approvals that have not been supplied, so preflight remains fail-closed.

Production identifiers from the reference documents are forbidden as defaults. The test environment remains isolated even when a future operator intentionally changes its domain.
