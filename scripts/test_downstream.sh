#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
consumer="$repo_root/tests/downstream"

if grep -Eq 'moreLink(Args|Libs)|blas|lapack|gfortran|Accelerate' \
    "$consumer/lakefile.lean"; then
  echo "SOS downstream fixture must not contain native link configuration"
  exit 1
fi

cd "$consumer"
lake update
lake build SosConsumerPlain
lake test
lake build sosConsumer
lake exe sosConsumer
lake env lean SosConsumerTest.lean \
  --setup=.lake/build/ir/SosConsumerTest.setup.json

echo "PASS: a portable downstream package builds and runs the SOS engine without native link flags."
