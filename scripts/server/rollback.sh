#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity

release_file="${1:-$repo_root/.deploy/releases/previous.env}"
restore_state="${2:-}"
[[ -f "$release_file" ]] || { printf 'Rollback release metadata does not exist.\n' >&2; exit 1; }

GIT_REVISION="$(sed -n 's/^GIT_REVISION=//p' "$release_file" | tail -n 1)"
APP_IMAGE_TAG="$(sed -n 's/^APP_IMAGE_TAG=//p' "$release_file" | tail -n 1)"
DATABASE_BACKUP="$(sed -n 's/^DATABASE_BACKUP=//p' "$release_file" | tail -n 1)"
WORDPRESS_VERSION="$(sed -n 's/^WORDPRESS_VERSION=//p' "$release_file" | tail -n 1)"
[[ "$GIT_REVISION" =~ ^[0-9a-fA-F]{40}$ ]] || { printf 'Rollback metadata has an invalid Git revision.\n' >&2; exit 1; }
[[ "$APP_IMAGE_TAG" =~ ^[A-Za-z0-9._-]+$ && "$APP_IMAGE_TAG" != *latest* ]] || { printf 'Rollback metadata has an invalid image tag.\n' >&2; exit 1; }
[[ "$WORDPRESS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Rollback metadata has an invalid WordPress version.\n' >&2; exit 1; }
git -C "$repo_root" cat-file -e "${GIT_REVISION}^{commit}"

"$script_dir/backup.sh"
git -C "$repo_root" checkout --detach "$GIT_REVISION"
export APP_IMAGE_TAG

if docker image inspect "we-sell-flavours/wordpress:$APP_IMAGE_TAG" >/dev/null 2>&1; then
  "${compose[@]}" up -d --no-build --wait
else
  "${compose[@]}" build wordpress
  "${compose[@]}" up -d --wait
fi

"${compose[@]}" run --rm wpcli core update --version="$WORDPRESS_VERSION" --force

if [[ "$restore_state" == --restore-state ]]; then
  [[ -n "${DATABASE_BACKUP:-}" && -f "$DATABASE_BACKUP" ]] || { printf 'Paired rollback backup is unavailable.\n' >&2; exit 1; }
  "$script_dir/restore.sh" "$DATABASE_BACKUP" --in-place "$COMPOSE_PROJECT_NAME"
fi

"$script_dir/health.sh"
printf 'Rollback passed health gates at revision %s with image tag %s.\n' "$GIT_REVISION" "$APP_IMAGE_TAG"
