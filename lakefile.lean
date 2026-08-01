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
    "2844bb8ff2af63fb977c949f4178e7e2e5c82f3d"

require HexMvPoly from git
  "https://github.com/leanprover/hex-mv-poly.git" @
    "010d49ad68446ae1638609269791ae8795be146a"

-- We do not set `precompileModules := true` on SOS itself: the FFI
-- (`@[extern]` declarations) lives in `CSDP.Basic`, which has
-- `precompileModules := true` upstream. Setting it here too triggers a
-- runtime-linker failure during SOS's own dynlib loading.
@[default_target]
lean_lib SOS

@[test_driver]
lean_lib SOSTest
