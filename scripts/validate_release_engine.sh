#!/usr/bin/env bash

# Exercise the same release-backed, Mathlib-free engine path on every CI host.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

./scripts/install_elan.sh
export PATH="$HOME/.elan/bin:$PATH"

lake update
lake script run CSDP/checkNativeDeps
lake build @CSDP:release
lake build --no-build --rehash CSDP
scripts/check_mathlib_boundary.sh
lake build SOS
lake test
scripts/test_downstream.sh

if grep -R -n -E '(^|[^[:alnum:]_])sorry([^[:alnum:]_]|$)|^[[:space:]]*axiom' SOS/; then
  echo "FAIL: sorry or axiom found in SOS/"
  exit 1
fi
echo "PASS: SOS/ has no sorry or axiom."
