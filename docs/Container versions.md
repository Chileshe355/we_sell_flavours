# Container version policy

## Reviewed baseline

The stack pins every third-party image to both a human-readable release tag and its reviewed multi-platform manifest digest. The WordPress/PHP and WP-CLI pins were updated and runtime-verified on 2026-10-22:

| Component | Reviewed image |
| --- | --- |
| WordPress/PHP-FPM | `wordpress:7.1.3-php8.3-fpm@sha256:788d6b34cb89997483ff2a08e2e04d1df28ce284ca046cd7990b0be10828c5b9` (PHP 8.3.36) |
| WP-CLI | `wordpress:cli-2.12.0-php8.3@sha256:85a4b720cd8acaf02b590eb27fcdfc2a25f67a4820e01bf0f39504b97da76a22` (PHP 8.3.36) |
| Nginx | `nginx:1.30.4-alpine3.24@sha256:97d490c12ba55b4946b01546d1c3ed324e8d41ab1c9fcb2a616aa470620e5b46` |
| MariaDB LTS | `mariadb:11.4.12-noble@sha256:67873d30a17f6a9c331f06363b2fa15f38abca415529966d67c84f87f82439fe` |
| Certbot | `certbot/certbot:v5.7.0@sha256:34ee91d2f43008eb78a007d22f23ed4b2eaa9a454cb27ca2c042b49527a695b4` |

The production-reference report says WordPress 6.8.7 on PHP 8.2.31. The test stack uses WordPress 7.1.3 on PHP 8.3.36 and treats both differences as explicit plugin-compatibility test boundaries. Do not claim exact production parity until the plugin suite has passed against both runtimes or production is upgraded through its own separately approved change.

The production database is MySQL-family 8.4 while this requested environment uses MariaDB 11.4 LTS. Both use `mysqli` and `utf8mb4`, but engine-specific SQL, collations, JSON behavior, indexing, and migration behavior can differ. Any import or schema migration must be tested and backed up first.

## Update process

1. Review upstream release and security notes.
2. Resolve the new immutable manifest digest with `docker buildx imagetools inspect`.
3. Update the Dockerfile or Compose image and this table in the same commit.
4. Build and run static, local smoke, plugin, backup, and isolated restore checks.
5. Create a server backup, deploy through health gates, and retain the previous revision and image identifiers for rollback.

Floating tags such as `latest`, `stable`, `11`, or `php8.3-fpm` are not deployable.

## Confirmed test-host tooling

Read-only discovery and the approved Compose-tooling install on 2026-08-10 confirmed one Ubuntu 24.04 package family: Docker Engine `29.1.3-0ubuntu3~24.04.2`, Compose v2 `2.40.3+ds1-0ubuntu1~24.04.1`, and Buildx `0.30.1-0ubuntu1~24.04.1`. The provisioner installs these by Ubuntu package name and must not add the Docker CE repository over an existing `docker.io` installation. Exact host package revisions continue to follow reviewed Ubuntu security updates; container images remain immutable-digest pinned as listed above.
