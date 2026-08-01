import Lake
open Lake DSL

package sos where
  version := v!"0.1.0"
  description := "A Lean 4 sum-of-squares tactic for nonlinear real arithmetic."
  keywords := #["math", "software-verification", "tactic", "real-arithmetic", "sos", "sdp"]
  license := "Apache-2.0"
  leanOptions := #[⟨`autoImplicit, false⟩]

require CSDP from git
  "https://github.com/leanprover/csdp-ffi" @
    "2844bb8ff2af63fb977c949f4178e7e2e5c82f3d"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.32.0-rc1-patch1"

require HexMvPoly from git
  "https://github.com/leanprover/hex-mv-poly.git" @
    "abd64dac3b4e517b09412db5fc089d7443a4590d"

-- We don't set `precompileModules := true` on SOS itself: the FFI
-- (`@[extern]` declarations) lives in `CSDP.Basic`, which has
-- `precompileModules := true` upstream. Setting it here too triggers a
-- runtime-linker failure on Linux during sos's own dynlib loading
-- (libLake_shared.so isn't on LD_LIBRARY_PATH at compile time).
@[default_target]
lean_lib SOS

@[test_driver]
lean_lib SOSTest
