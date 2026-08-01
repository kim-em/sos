/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import SOS.Engine

/-!
Mathlib-free sum-of-squares search engine.

The proof-producing `sos` tactic and its soundness layer live in
`Mathlib.Tactic.SOS`. Most users should import that module from Mathlib;
engine consumers can import `SOS.Core` or `SOS.Engine` directly.
-/
