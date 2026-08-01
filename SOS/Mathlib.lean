/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import SOS.Mathlib.Certificate
import SOS.Mathlib.Raw
import SOS.Mathlib.Polynomial
import SOS.Mathlib.Reify
import SOS.Mathlib.Lift
import SOS.Mathlib.Verifier
import SOS.Mathlib.Tactic

/-!
Mathlib-facing soundness proofs and tactic elaboration for SOS.

The modules above form the intended Mathlib extraction boundary. The
computational engine lives outside `SOS/Mathlib/` and does not import this
umbrella.
-/
