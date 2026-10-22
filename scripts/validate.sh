#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$repo_root/scripts/check-secrets.sh"
"$repo_root/scripts/test-stack.sh" local
"$repo_root/scripts/test-stack.sh" server
while IFS= read -r -d '' file; do bash -n "$file"; done < <(find "$repo_root" -type f -name '*.sh' -print0)
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do shellcheck "$file"; done < <(find "$repo_root" -type f -name '*.sh' -print0)
else
  printf 'shellcheck unavailable; bash syntax validation completed.\n'
fi
openspec validate secure-wordpress-docker-environments --type change --strict
printf 'All available static validation passed.\n'
