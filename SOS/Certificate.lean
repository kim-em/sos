/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import SOS.Raw
import SOS.Polynomial

namespace SOS

open CPoly

/-- Convert the typed `Poly n` AST into a Hex polynomial with `Rat`
coefficients. This is the bridge from our internal AST to the
computational substrate used by the verifier. -/
def Poly.toCMv {n : Nat} : SOS.Poly n → CMvPolynomial n Rat
  | .const r   => CMvPolynomial.C r
  | .var i     => CMvPolynomial.X i
  | .neg p     => -p.toCMv
  | .add p q   => p.toCMv + q.toCMv
  | .sub p q   => p.toCMv - q.toCMv
  | .mul p q   => p.toCMv * q.toCMv
  | .pow p k   => p.toCMv ^ k

/-- Weighted sum-of-squares decomposition: `Σᵢ cᵢ · pᵢ²`. Each `terms`
entry is a pair `(c, p)` with `c ∈ Rat`, interpreted as `c · p²`.

Validity requires `0 ≤ cᵢ` for every entry; this is enforced by
`Certificate.checks` via `SOSDecomp.coeffsNonneg`. Decide-checked at
certificate time rather than carried as a propositional field — direct
`sos_witness` users can hand-write certificates, so the verifier must
not rely on the search maintaining the invariant. -/
structure SOSDecomp (n : Nat) where
  terms : List (Rat × CMvPolynomial n Rat)
  deriving Inhabited

/-- The polynomial expansion `Σᵢ cᵢ · pᵢ²` of a weighted sum-of-squares
decomposition. -/
def SOSDecomp.toPoly {n : Nat} (sd : SOSDecomp n) : CMvPolynomial n Rat :=
  sd.terms.foldr (fun pair acc => acc + CMvPolynomial.C pair.1 * pair.2 * pair.2) 0

/-- All coefficients are non-negative; required for soundness. -/
def SOSDecomp.coeffsNonneg {n : Nat} (sd : SOSDecomp n) : Bool :=
  sd.terms.all (fun pair => decide (0 ≤ pair.1))

/-- Goal shape with all data needed to reconstruct the soundness theorem
appropriately. -/
inductive Goal (n : Nat) where
  /-- `p ≥ 0` over the constraint set. -/
  | closed     (p : CMvPolynomial n Rat)
  /-- `p > 0`, certified via `p − ε ≥ 0` with `ε > 0`. -/
  | strict     (p : CMvPolynomial n Rat) (epsilon : Rat) (hε : 0 < epsilon)
  /-- The constraint set is infeasible; certified via `−1 = σ₀ + …`. -/
  | infeasible

/-- The polynomial we certify against the constraint set. Closed: `p`.
Strict: `p − ε`. Infeasibility: `−1` (as the constant polynomial). -/
def Goal.target {n : Nat} : Goal n → CMvPolynomial n Rat
  | .closed p     => p
  | .strict p ε _ => p - CMvPolynomial.C ε
  | .infeasible   => -1

/-- A full Positivstellensatz certificate. `sigmas` is a list of
subset-indexed SOS multipliers: each entry `(idxs, σ)` contributes
`σ.toPoly · ∏_{i ∈ idxs} gs[i]` to the certificate. The empty subset
`[]` recovers the original `σ₀` term; singletons `[i]` recover the
per-constraint `σᵢ` of a Putinar-style decomposition; higher cardinalities
give Schmüdgen-style preordering terms (products of constraints).

`eqCofs` provides one free polynomial cofactor `qⱼ` per equality
constraint `pⱼ`; the equality contribution is `qⱼ · pⱼ`. Cofactors are
unrestricted in sign (they are not required to be sums of squares).

Indices in each subset must be `< gs.length`; `Certificate.checks`
enforces this bound. -/
structure Certificate (n : Nat) where
  /-- Subset-indexed SOS multipliers. -/
  sigmas : List (List Nat × SOSDecomp n)
  /-- One free polynomial cofactor `qⱼ` per equality constraint `pⱼ`.
  Empty (default) when the goal has no equality hypotheses. -/
  eqCofs : List (CMvPolynomial n Rat) := []
  deriving Inhabited

/-- Product of `gs[i]` for `i ∈ idxs`. Out-of-bounds indices default to
the constant `1`; the `Certificate.checks` bounds check ensures this
default never fires on a well-formed certificate. -/
def Certificate.constraintProduct {n : Nat}
    (gs : List (CMvPolynomial n Rat)) (idxs : List Nat) :
    CMvPolynomial n Rat :=
  idxs.foldr (fun i acc => acc * gs.getD i 1) 1

/-- Sum of `σ.toPoly · ∏_{i ∈ idxs} gs[i]` over the subset-indexed σ list. -/
def Certificate.monoidSum {n : Nat}
    (sigmas : List (List Nat × SOSDecomp n))
    (gs : List (CMvPolynomial n Rat)) :
    CMvPolynomial n Rat :=
  sigmas.foldr
    (fun pair acc => acc + pair.2.toPoly * Certificate.constraintProduct gs pair.1) 0

/-- Sum of `qⱼ * pⱼ` over paired lists of free cofactors and equality
polynomials. -/
def Certificate.equalitySum {n : Nat}
    (eqCofs : List (CMvPolynomial n Rat)) (ps : List (CMvPolynomial n Rat)) :
    CMvPolynomial n Rat :=
  (eqCofs.zip ps).foldr (fun pair acc => acc + pair.fst * pair.snd) 0

/-- The full polynomial expansion
`Σ_S σ_S · ∏_{i ∈ S} gᵢ + Σⱼ qⱼ · pⱼ` of a certificate evaluated against
inequality constraints `gs` and equality constraints `ps`. -/
def Certificate.toPoly {n : Nat} (c : Certificate n)
    (gs : List (CMvPolynomial n Rat)) (ps : List (CMvPolynomial n Rat)) :
    CMvPolynomial n Rat :=
  Certificate.monoidSum c.sigmas gs + Certificate.equalitySum c.eqCofs ps

/-- All indices in every subset are `< gs.length`. -/
def Certificate.indicesInBounds {n : Nat}
    (sigmas : List (List Nat × SOSDecomp n)) (gsLen : Nat) : Bool :=
  sigmas.all fun pair => pair.1.all (· < gsLen)

/-- Certificate validity check. Confirms every subset index is in
`[0, gs.length)`, every σ block has non-negative coefficients, that
`eqCofs` and `ps` line up, then checks the polynomial identity
`goal.target = c.toPoly gs ps` via `decide +kernel`. -/
def Certificate.checks {n : Nat} (c : Certificate n) (goal : Goal n)
    (gs : List (CMvPolynomial n Rat)) (ps : List (CMvPolynomial n Rat)) : Bool :=
  Certificate.indicesInBounds c.sigmas gs.length &&
  c.sigmas.all (fun pair => pair.2.coeffsNonneg) &&
  (c.eqCofs.length == ps.length) &&
  decide (goal.target = c.toPoly gs ps)

/-! ### Building certificates from `SOS.Poly`-form data

The search produces `CMvPolynomial`-form weighted-square terms; the
elaborator decompiles each term's polynomial back into a `SOS.Poly n`
AST so it can be `ToExpr`-quoted into a Lean term. The rational
coefficient is kept verbatim. `Certificate.fromDecompiled` then
maps the AST polynomials back through `SOS.Poly.toCMv` to assemble
a `Certificate n`. -/

/-- Lift a `List (Rat × SOS.Poly n)` of weighted-square terms to a
`SOSDecomp n` by mapping each polynomial through `SOS.Poly.toCMv`. -/
def SOSDecomp.fromTerms {n : Nat}
    (terms : List (Rat × SOS.Poly n)) : SOSDecomp n :=
  { terms := terms.map (fun pair => (pair.1, SOS.Poly.toCMv pair.2)) }

/-- Build a `Certificate n` from `SOS.Poly`-keyed subset-indexed σ data,
where each σ-block is a list of weighted-square terms `(c, p)`. -/
def Certificate.fromDecompiled {n : Nat}
    (sigmasPolys : List (List Nat × List (Rat × SOS.Poly n)))
    (eqCofPolys : List (SOS.Poly n) := []) : Certificate n :=
  { sigmas := sigmasPolys.map (fun pair => (pair.1, SOSDecomp.fromTerms pair.2)),
    eqCofs := eqCofPolys.map SOS.Poly.toCMv }

/-- Backward-compatible Putinar-shape builder: takes the original
`(σ₀, σᵢ list)` data and builds a subset-indexed certificate with the
empty subset for σ₀ and singletons `[i]` for each σᵢ. -/
def Certificate.fromPutinar {n : Nat}
    (sigma0 : SOSDecomp n) (sigmas : List (SOSDecomp n))
    (eqCofs : List (CMvPolynomial n Rat) := []) : Certificate n :=
  let indexed : List (List Nat × SOSDecomp n) :=
    ([], sigma0) :: sigmas.zipIdx.map (fun pair => ([pair.2], pair.1))
  { sigmas := indexed, eqCofs }

/-! ### Strict-product Positivstellensatz support

For Harrison's `REAL_NONLINEAR_PROVER` boundary-tight strict-positivity
path: the strict-positive witness `(∏ strictGs)^i` is built structurally
from strict hypotheses, while a closed certificate handles the residual
`−(∏ strictGs)^i = σ₀ + Σ_T σ_T · ∏ gs[T] + Σⱼ qⱼ · pⱼ` against the
*augmented* constraint list `gs ++ [−p]`. -/

/-- Left-to-right product of a polynomial list; `1` on the empty list. -/
def strictProductPoly {n : Nat} : List (CMvPolynomial n Rat) → CMvPolynomial n Rat
  | []      => 1
  | g :: rest => g * strictProductPoly rest

end SOS
