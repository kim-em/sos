/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

module

@[expose] public section

namespace SOS.Poly

/-- Untyped polynomial AST with `ℕ`-valued atom indices. Built up during
reification before the total atom count is known. -/
inductive Raw where
  | const : Rat → Raw
  | var   : Nat → Raw          -- atom index
  | neg   : Raw → Raw
  | add   : Raw → Raw → Raw
  | sub   : Raw → Raw → Raw
  | mul   : Raw → Raw → Raw
  | pow   : Raw → Nat → Raw
  deriving Inhabited, Repr

/-- One past the largest atom index referenced in `r`. Used as the lower
bound on `n` when casting to the typed form `Poly n`. -/
def Raw.maxAtomBound : Raw → Nat
  | .const _   => 0
  | .var i     => i + 1
  | .neg p     => p.maxAtomBound
  | .add p q   => max p.maxAtomBound q.maxAtomBound
  | .sub p q   => max p.maxAtomBound q.maxAtomBound
  | .mul p q   => max p.maxAtomBound q.maxAtomBound
  | .pow p _   => p.maxAtomBound

end SOS.Poly

namespace SOS

/-- Typed polynomial AST in `n` variables. Obtained from `Poly.Raw` once the
total atom count is known. -/
inductive Poly (n : Nat) where
  | const : Rat → Poly n
  | var   : Fin n → Poly n
  | neg   : Poly n → Poly n
  | add   : Poly n → Poly n → Poly n
  | sub   : Poly n → Poly n → Poly n
  | mul   : Poly n → Poly n → Poly n
  | pow   : Poly n → Nat → Poly n
  deriving Inhabited, Repr, DecidableEq

end SOS

namespace SOS.Poly

/-- Cast `Raw` into the typed `Poly n` once `n ≥ r.maxAtomBound`. -/
def Raw.cast : (n : Nat) → (r : Raw) → r.maxAtomBound ≤ n → SOS.Poly n
  | _, .const r,   _ => .const r
  | _, .var i,     h => .var ⟨i, Nat.lt_of_succ_le h⟩
  | n, .neg p,     h => .neg (cast n p h)
  | n, .add p q, h =>
    .add (cast n p (Nat.le_trans (Nat.le_max_left _ _) h))
         (cast n q (Nat.le_trans (Nat.le_max_right _ _) h))
  | n, .sub p q, h =>
    .sub (cast n p (Nat.le_trans (Nat.le_max_left _ _) h))
         (cast n q (Nat.le_trans (Nat.le_max_right _ _) h))
  | n, .mul p q, h =>
    .mul (cast n p (Nat.le_trans (Nat.le_max_left _ _) h))
         (cast n q (Nat.le_trans (Nat.le_max_right _ _) h))
  | n, .pow p k, h => .pow (cast n p h) k

end SOS.Poly
