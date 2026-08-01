/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

module

public import SOS.Certificate

/-!
Stable Mathlib-free data and checking interface for SOS.

Proof-facing consumers use this module for polynomial syntax, certificates,
and executable checking without importing the native search implementation or
CSDP. The automatic tactic additionally imports `SOS.Engine` to run search.
-/
