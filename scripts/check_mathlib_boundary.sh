#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failed=0
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
  ! -path 'SOS/Mathlib/*' \
  ! -path 'SOS/Mathlib.lean' \
  | sort)

if [[ "$engine_files" -eq 0 ]]; then
  echo "Mathlib boundary check did not scan any engine files."
  exit 1
fi

mathlib_files=0
while IFS= read -r file; do
  mathlib_files=$((mathlib_files + 1))
  if matches="$(grep -En \
      '^[[:space:]]*import[[:space:]]+SOS\.' "$file" \
      | grep -Ev \
      '^[0-9]+:[[:space:]]*import[[:space:]]+SOS\.(Core|Engine|Mathlib([./][A-Za-z0-9_.]+)?)[[:space:]]*(--.*)?$' \
      || true)" && [[ -n "$matches" ]]; then
    echo "Unstable native import in $file:"
    echo "$matches"
    failed=1
  fi
done < <(find SOS/Mathlib -type f -name '*.lean' | sort)

if [[ "$mathlib_files" -eq 0 ]]; then
  echo "Mathlib boundary check did not scan any proof-facing files."
  exit 1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "Files outside SOS/Mathlib/ must remain Mathlib-free; proof-facing files may depend only on SOS.Core, SOS.Engine, and SOS.Mathlib siblings."
  exit 1
fi

echo "PASS: scanned $engine_files engine files and $mathlib_files proof-facing files; the SOS/Mathlib boundary is clean."
