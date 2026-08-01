# Extracting the Mathlib layer

The source tree is already divided at the eventual package boundary:

- `SOS/Engine.lean` and the modules it imports are the Mathlib-free native
  package. They depend on `hex-mv-poly` and `csdp-ffi`.
- `SOS/Mathlib/` is the prospective Mathlib contribution. Its only dependency
  on the native side is the public `SOS.Engine` façade.
- `SOS/Mathlib.lean` is the in-repository umbrella for that directory.
- The top-level `SOS.lean` intentionally imports both sides so existing users
  retain the single-import experience during the in-place phase.

The extraction is mechanical; it does not require another API redesign.

## Mathlib change

1. Copy `SOS/Mathlib/*.lean` to `Mathlib/Tactic/SOS/*.lean`.
2. Rewrite module imports from `SOS.Mathlib.X` to `Mathlib.Tactic.SOS.X`.
   Imports of `SOS.Engine` remain imports of the required native package.
3. Create `Mathlib/Tactic/SOS.lean` from `SOS/Mathlib.lean`, with the same
   module-path rewrite, and expose it from the desired Mathlib tactic umbrella.
4. Add the native SOS package as a Lake dependency. The package supplies the
   engine, `hex-mv-poly`, `csdp-ffi`, and the native CSDP artifacts; Mathlib
   supplies all proof-facing dependencies used by the copied files.
5. Run the existing SOS examples and regression files against
   `import Mathlib.Tactic.SOS` before removing the in-place copies.

## Upstream SOS change

1. Delete `SOS/Mathlib/` and `SOS/Mathlib.lean`.
2. Change `SOS.lean` to import only `SOS.Engine`.
3. Remove the direct Mathlib requirement from `lakefile.lean` and regenerate
   `lake-manifest.json`. Keep the direct `hex-mv-poly` and `csdp-ffi`
   requirements.
4. Move Mathlib-dependent regression examples to Mathlib. Keep engine tests
   and executable certificate checks upstream.
5. Run `scripts/check_mathlib_boundary.sh` and build the upstream library. The
   boundary check remains useful after extraction and prevents accidental
   Mathlib imports from returning.

Native link-argument propagation is deliberately independent of this source
split. It must be clean enough that a Mathlib target importing the tactic does
not repeat SOS/CSDP platform flags; that Lake packaging question is tracked
separately.
