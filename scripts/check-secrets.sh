#!/usr/bin/env bash
set -euo pipefail

forbidden_paths="$(git ls-files --cached --others --exclude-standard | grep -E '(^|/)(secrets|backups|uploads|wordpress-data|database-data)/|\.wpress$' | grep -Ev '^tests/fixtures/secrets/' || true)"
if [[ -n "$forbidden_paths" ]]; then
  printf 'Forbidden runtime or secret paths are tracked:\n%s\n' "$forbidden_paths" >&2
  exit 1
fi

patterns=(
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  'ghp_[A-Za-z0-9]{20,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'AKIA[0-9A-Z]{16}'
)

for pattern in "${patterns[@]}"; do
  if rg --line-number --hidden --glob '!tests/fixtures/**' --glob '!.git/**' --glob '!openspec/changes/**' --regexp "$pattern" . >/dev/null; then
    printf 'Possible secret material detected for pattern: %s\n' "$pattern" >&2
    exit 1
  fi
done

printf 'Repository secret-pattern and tracked-path checks passed.\n'
