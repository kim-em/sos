#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failed=0
while IFS= read -r file; do
  if matches="$(grep -En \
      '^[[:space:]]*import[[:space:]]+(Mathlib([./[:space:]]|$)|HexMvPolyMathlib([./[:space:]]|$)|SOS\.Mathlib([./[:space:]]|$))' \
      "$file" || true)" && [[ -n "$matches" ]]; then
    echo "Mathlib boundary violation in $file:"
    echo "$matches"
    failed=1
  fi
done < <(find SOS -type f -name '*.lean' \
  ! -path 'SOS/Mathlib/*' \
  ! -path 'SOS/Mathlib.lean' \
  | sort)

if [[ "$failed" -ne 0 ]]; then
  echo "Files outside SOS/Mathlib/ must remain Mathlib-free and must not import the Mathlib layer."
  exit 1
fi

echo "PASS: the SOS engine import boundary is Mathlib-free."
