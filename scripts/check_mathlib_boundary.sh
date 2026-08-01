#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failed=0

if [[ -e SOS/Mathlib.lean ]] ||
    { [[ -d SOS/Mathlib ]] &&
      [[ -n "$(find SOS/Mathlib -type f -print -quit)" ]]; }; then
  echo "Mathlib-facing source must not be present in the engine package."
  failed=1
fi

engine_files=0
while IFS= read -r file; do
  engine_files=$((engine_files + 1))
  if matches="$(grep -En \
      '^[[:space:]]*import[[:space:]]+(Mathlib([./[:space:]]|$)|HexMvPolyMathlib([./[:space:]]|$)|SOS\.Mathlib([./[:space:]]|$))' \
      "$file" || true)" && [[ -n "$matches" ]]; then
    echo "Mathlib boundary violation in $file:"
    echo "$matches"
    failed=1
  fi
done < <(find SOS -type f -name '*.lean' \
  | sort)

if [[ "$engine_files" -eq 0 ]]; then
  echo "Mathlib boundary check did not scan any engine files."
  exit 1
fi

if jq -e '.packages[] | select(
    ((.name | ascii_downcase) == "mathlib") or
    ((.name | ascii_downcase) == "hexmvpolymathlib"))' \
    lake-manifest.json >/dev/null; then
  echo "Mathlib-facing package found in lake-manifest.json."
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "The SOS engine package must remain wholly Mathlib-free."
  exit 1
fi

echo "PASS: scanned $engine_files engine files; source and dependency graph are Mathlib-free."
