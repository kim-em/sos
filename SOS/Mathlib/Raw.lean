/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import SOS.Core
import Mathlib.Data.Real.Basic

namespace SOS.Poly

/-- Real-valued denotation of the typed AST under a `Fin n → ℝ` valuation. -/
def evalReal {n : Nat} (φ : Fin n → ℝ) : SOS.Poly n → ℝ
  | .const r   => (r : ℝ)
  | .var i     => φ i
  | .neg p     => -evalReal φ p
  | .add p q   => evalReal φ p + evalReal φ q
  | .sub p q   => evalReal φ p - evalReal φ q
  | .mul p q   => evalReal φ p * evalReal φ q
  | .pow p k   => evalReal φ p ^ k

end SOS.Poly
