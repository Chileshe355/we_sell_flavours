## ADDED Requirements

### Requirement: Isolated service topology
The platform SHALL run Nginx, WordPress 7.1.3 on PHP-FPM 8.3.36, and MariaDB as distinct services, and SHALL permit external web traffic to enter only through Nginx. MariaDB and PHP-FPM MUST NOT publish host ports, Nginx MUST NOT join the database-only network, and no application container SHALL receive the host Docker socket.

#### Scenario: Rendered network and port configuration
- **WHEN** an operator renders either environment's effective Compose configuration
- **THEN** only Nginx has a host-facing port and service network membership permits Nginx-to-PHP-FPM and WordPress-to-MariaDB traffic without permitting Nginx-to-MariaDB traffic

### Requirement: Environment-specific identity
The platform SHALL require each environment to define a distinct Compose project name, WordPress environment type, home URL, site URL, and persistent volume namespace. The server configuration MUST fail validation when required test-environment identity values are absent and MUST reject an explicitly production-marked target.

#### Scenario: Test environment starts with its own identity
- **WHEN** the test stack is rendered with valid test settings
- **THEN** its URLs reference only the configured test hostname, its WordPress environment type is `staging`, and none of its project, network, or volume names match the local or production identifiers

#### Scenario: Unsafe environment identity is supplied
- **WHEN** the server deployment receives a production environment marker or a missing test hostname
- **THEN** validation stops before any container or volume is changed

### Requirement: Production-relevant runtime compatibility
The WordPress runtime SHALL support single-site WordPress 7.1.3, PHP-FPM 8.3.36, Imagick, pretty permalinks, and the `en_ZA` locale when selected. MariaDB SHALL use `utf8mb4` with an explicitly configured compatible collation. Nginx and PHP request-size and execution limits SHALL be configurable together, with documented conservative defaults and a production-parity option for large-media testing.

#### Scenario: Compatibility verification runs
- **WHEN** the stack completes its acceptance check
- **THEN** the check confirms WordPress 7.1.3, PHP 8.3.36, required extensions including Imagick and mysqli, pretty-permalink routing, the selected locale, database character set/collation, and aligned Nginx/PHP request limits

### Requirement: Durable data and controlled code mounts
The platform SHALL persist MariaDB data and intended WordPress runtime content across ordinary container recreation. Plugin source SHALL come from a documented repository path, with environment-specific write permissions, and database data MUST NOT be stored in an image or Git working tree.

#### Scenario: Services are recreated
- **WHEN** containers are removed and recreated without an explicit reset or restore operation
- **THEN** database records, uploads, and configured persistent WordPress content remain available and the same checked-out plugin source is loaded

### Requirement: Reproducible images and upgrades
Runtime images SHALL use explicit reviewed versions and SHALL NOT use floating `latest` tags. The deployment SHALL record the Git revision and resolved image identifiers, and application image upgrades SHALL run through build, compatibility, backup, health-check, and rollback steps.

#### Scenario: A release is prepared
- **WHEN** an operator builds a deployable stack revision
- **THEN** all service images resolve to reviewed versions, the deployed revision and image identifiers can be reported, and a rollback target is known

### Requirement: Health and dependency readiness
Each long-running service SHALL expose a non-secret health check suitable for its responsibility, and startup/deployment SHALL wait for required dependencies to be ready rather than merely started. Health output MUST NOT reveal credentials or sensitive configuration.

#### Scenario: Database is temporarily unavailable
- **WHEN** MariaDB has started but is not ready to accept the application connection
- **THEN** WordPress is not reported ready and the deployment cannot pass its end-to-end health gate

### Requirement: Web and filesystem hardening
Nginx SHALL deny access to hidden files, environment/configuration artifacts, dumps, archives, private keys, and executable PHP in upload paths. Server code mounts SHALL be read-only where runtime writes are not required and filesystem ownership SHALL be explicit. The staging server SHALL permit authorized administrators to install, update, and edit plugins and themes in persistent writable content storage. Documentation SHALL state that staging administrator access therefore grants application code-execution capability and MUST NOT be treated as a production default.

#### Scenario: Sensitive-path request is made
- **WHEN** an HTTP client requests a known secret, backup, hidden, or uploaded-PHP path
- **THEN** Nginx rejects the request without passing it to PHP-FPM or disclosing filesystem contents
