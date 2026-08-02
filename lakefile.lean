import Lake
open Lake DSL

package sos where
  version := v!"0.2.0"
  description := "A Mathlib-free sum-of-squares search engine for Lean 4."
  keywords := #["math", "software-verification", "sos", "sdp"]
  license := "Apache-2.0"
  leanOptions := #[⟨`autoImplicit, false⟩]

require CSDP from git
  "https://github.com/leanprover/csdp-ffi" @
    "v0.1.0-mathlib-rc11"
  with NameMap.empty.insert `csdpPortable "true"

-- Keep the full Hex closure direct so downstream manifests retain the
-- immutable semantic-version inputs rather than the mirrors' commit pins.
require HexBasic from git
  "https://github.com/leanprover/hex-basic.git" @
    "v0.1.0"

require HexPoly from git
  "https://github.com/leanprover/hex-poly.git" @
    "v0.1.0"

require HexMvPoly from git
  "https://github.com/leanprover/hex-mv-poly.git" @
    "v0.1.0"

-- We do not set `precompileModules := true` on SOS itself: the FFI
-- (`@[extern]` declarations) lives in `CSDP.Basic`, which has
-- `precompileModules := true` upstream. Setting it here too triggers a
-- runtime-linker failure during SOS's own dynlib loading.
@[default_target]
lean_lib SOS

@[test_driver]
lean_lib SOSTest
