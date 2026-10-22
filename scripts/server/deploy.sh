#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$script_dir/common.sh"
require_test_identity

revision="${1:-}"
[[ "$revision" =~ ^[0-9a-fA-F]{7,40}$ ]] || { printf 'Pass an explicit 7-40 character Git commit SHA.\n' >&2; exit 1; }
[[ -z "$(git -C "$repo_root" status --porcelain --untracked-files=no)" ]] || { printf 'Tracked server working tree changes prevent deployment.\n' >&2; exit 1; }

"$script_dir/preflight.sh"
git -C "$repo_root" fetch --prune origin "$DEPLOY_BRANCH"
revision="$(git -C "$repo_root" rev-parse --verify "${revision}^{commit}")"
git -C "$repo_root" merge-base --is-ancestor "$revision" "origin/$DEPLOY_BRANCH" || {
  printf 'Requested revision is not contained in the approved remote branch.\n' >&2
  exit 1
}

state_dir="$repo_root/.deploy/releases"
mkdir -p "$state_dir"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
current_state="$state_dir/current.env"
if [[ -f "$current_state" ]]; then
  previous_revision="$(sed -n 's/^GIT_REVISION=//p' "$current_state" | tail -n 1)"
  previous_tag="$(sed -n 's/^APP_IMAGE_TAG=//p' "$current_state" | tail -n 1)"
else
  previous_revision="$(git -C "$repo_root" rev-parse HEAD)"
  previous_tag="$APP_IMAGE_TAG"
fi
[[ "$previous_revision" =~ ^[0-9a-fA-F]{40}$ ]] || { printf 'Current release metadata has an invalid revision.\n' >&2; exit 1; }
[[ "$previous_tag" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'Current release metadata has an invalid image tag.\n' >&2; exit 1; }
backup_path=''
if [[ -n "$("${compose[@]}" ps -q mariadb)" ]]; then
  previous_wordpress_version="$("${compose[@]}" run --rm wpcli core version)"
  [[ "$previous_wordpress_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Current WordPress version is invalid.\n' >&2; exit 1; }
  backup_output="$($script_dir/backup.sh)"
  backup_path="$(sed -n 's/^Encrypted, verified, off-host backup completed: //p' <<<"$backup_output" | tail -n 1)"
else
  previous_wordpress_version=''
fi

cat >"$state_dir/previous.env" <<EOF
GIT_REVISION=$previous_revision
APP_IMAGE_TAG=$previous_tag
WORDPRESS_VERSION=$previous_wordpress_version
DATABASE_BACKUP=$backup_path
RECORDED_UTC=$timestamp
EOF

git -C "$repo_root" checkout --detach "$revision"
short_revision="$(git -C "$repo_root" rev-parse --short=12 HEAD)"
export APP_IMAGE_TAG="${APP_IMAGE_TAG_BASE:-7.1.3-php8.3.36}-${short_revision}"

"$script_dir/preflight.sh"
"${compose[@]}" pull --ignore-buildable
"${compose[@]}" build --pull wordpress
"${compose[@]}" up -d --wait
"${compose[@]}" run --rm wpcli core update --version=7.1.3 --force
"${compose[@]}" run --rm wpcli core update-db
"$script_dir/health.sh"

{
  printf 'GIT_REVISION=%s\n' "$revision"
  printf 'APP_IMAGE_TAG=%s\n' "$APP_IMAGE_TAG"
  printf 'WORDPRESS_VERSION=7.1.3\n'
  printf 'PHP_VERSION=8.3.36\n'
  printf 'DEPLOYED_UTC=%s\n' "$timestamp"
  printf 'DATABASE_BACKUP=%s\n' "$backup_path"
} >"$current_state"
"${compose[@]}" images --format json >"$state_dir/${timestamp}-images.json"
printf 'Deployment passed all health gates at revision %s.\n' "$revision"
