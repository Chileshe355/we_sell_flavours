## ADDED Requirements

### Requirement: One-command local lifecycle
The repository SHALL provide documented commands to validate, start, stop, inspect, and rebuild the local stack using the shared platform plus the local override. Local startup SHALL use a stable, non-production Compose project name and SHALL not require server credentials or a public DNS record.

#### Scenario: Developer starts from a clean checkout
- **WHEN** a developer copies the local example configuration, supplies local-only values, and runs the documented start command
- **THEN** the complete stack becomes healthy and the site is reachable through the documented loopback URL

### Requirement: Live plugin source development
The local environment SHALL bind-mount each configured plugin source directory from the repository into the corresponding WordPress plugin directory with write behavior appropriate for development. A host source edit SHALL be visible to WordPress without rebuilding the base image.

#### Scenario: Plugin PHP file changes
- **WHEN** a developer edits a mounted plugin file on the host
- **THEN** the local WordPress runtime observes the new file contents on the next applicable request without an image rebuild

### Requirement: Local-only development features
WordPress debugging and development tooling SHALL be available only through the local override or an explicitly invoked tooling profile. Debug output SHALL be logged rather than rendered to site visitors by default, and development settings MUST NOT appear in the effective server configuration.

#### Scenario: Environment configurations are compared
- **WHEN** an operator renders the local and server Compose configurations
- **THEN** debug and writable source-development behavior appears only locally while shared runtime versions and required extensions remain aligned

### Requirement: Safe local network defaults
Local web access SHALL bind to loopback by default, and MariaDB and PHP-FPM SHALL remain unexposed to the host. Any optional database host port MUST require an explicit local-only override and MUST bind only to loopback.

#### Scenario: Local ports are inspected
- **WHEN** the default local stack is running
- **THEN** no service is reachable through a non-loopback host interface and neither MariaDB nor PHP-FPM has a published port

### Requirement: Developer tooling through containers
The local workflow SHALL provide version-aligned WP-CLI access and documented commands for plugin activation, WordPress initialization, cache cleanup, database inspection, and running plugin checks without requiring PHP, WordPress, or MariaDB tooling installed directly on the host.

#### Scenario: Developer activates a plugin
- **WHEN** the developer invokes the documented WP-CLI command for a mounted plugin
- **THEN** the command runs against the local WordPress container and database and reports the activation result

### Requirement: Explicit destructive reset
The local workflow SHALL separate ordinary stop/restart operations from destructive data reset. A reset command MUST identify the local project and volumes it will remove and MUST require explicit confirmation or a deliberate force flag.

#### Scenario: Developer stops the stack normally
- **WHEN** the developer runs the documented stop command without the reset option
- **THEN** local database and WordPress persistent volumes remain intact

#### Scenario: Developer requests a reset
- **WHEN** the developer invokes reset and confirms the exact local target
- **THEN** only the named local project's persistent data is removed and server or production-marked resources are rejected
