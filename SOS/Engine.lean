/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import SOS.Search

namespace SOS

open CPoly

/-- Search configuration independent of any tactic frontend. Pass it to
`Engine.solve`; Mathlib's tactic accepts the same structure through
`sos (config := { maxDepth := 3 })`.

* `maxDepth` is the iterative-deepening cap. At each
  `extraDeg ∈ [0..maxDepth]`, the σ₀ and σᵢ bases grow by one monomial degree.
  Harrison's `REAL_SOS` reports needing depth up to 12; each level is a fresh
  CSDP solve and scales combinatorially with the basis. The default `1` is the
  largest value with no measurable cost over `0` on the regression suite and
  unlocks the discriminant identity. Raise it per call for hard targets.
* `maxRoundingDenomLog2` is the base-2 logarithm of the largest candidate in
  the rounding-denominator schedule. The default `66` matches Harrison's
  `find_rounding` ceiling. Lower it to fail faster when large denominators are
  not expected.
* `basisStrategy` controls σ₀ basis pruning. `.newton` uses Reznick's
  half-Newton-polytope test via an exact-rational simplex; `.dense` disables
  pruning. A dense fallback runs at the same degree when pruning does not
  certify, so this is a performance and sparsity choice, not a soundness one.
* `maxSubsetCardinality` caps subsets in the constraint-product monoid.
  Cardinality `1` is pure Putinar; higher values enable products of constraint
  polynomials. Search always tries Putinar first, then falls back to the cap.
  Raise it for targets, such as interval Schur inequalities, that require
  products of three or more constraints.
* `maxRefutationPower` is Harrison's Positivstellensatz refutation exponent
  budget. `0` disables this route. Positive values let unconstrained closed
  goals search for certificates of `−(−p)^i`, which is the route for genuinely
  non-SOS non-negative polynomials such as Motzkin's. It is disabled by
  default because every power starts a family of growing-degree CSDP solves
  and rational reconstruction gets harder; hard targets may also need a
  larger `maxDepth`. -/
structure Config where
  /-- Iterative-deepening cap for polynomial bases; see `Config`. -/
  maxDepth : Nat := 1
  /-- Base-2 logarithm of the largest rationalisation denominator. -/
  maxRoundingDenomLog2 : Nat := 66
  /-- Basis pruning strategy used by the SDP search; see `Config`. -/
  basisStrategy : SOS.Search.BasisStrategy := .newton
  /-- Largest constraint-product cardinality tried by the preordering search. -/
  maxSubsetCardinality : Nat := 2
  /-- Largest Positivstellensatz refutation power; zero disables that path. -/
  maxRefutationPower : Nat := 0
  deriving Inhabited

namespace Engine

/-- A fully reified search problem. Strict problems additionally identify
which inequality constraints came from strict hypotheses. -/
inductive Problem (n : Nat) where
  | closed
      (p : CMvPolynomial n Rat)
      (gs ps : List (CMvPolynomial n Rat))
  | strict
      (p : CMvPolynomial n Rat)
      (gs : List (CMvPolynomial n Rat))
      (strictIdxs : List Nat)
      (ps : List (CMvPolynomial n Rat))
  | infeasible
      (gs ps : List (CMvPolynomial n Rat))

/-- The certificate route selected by the complete SOS search policy. -/
inductive Result (n : Nat) where
  | closed (cert : Certificate n)
  | closedRefutation (cert : Certificate n)
  | nonnegRefutation (exponent : Nat) (cert : Certificate n)
  | strict (ε : Rat) (hε : 0 < ε) (cert : Certificate n)
  | strictProduct
      (strictGs : List (CMvPolynomial n Rat))
      (exponent : Nat)
      (cert : Certificate n)
  | infeasible (cert : Certificate n)

/-- Deterministically re-derive and evaluate the exact certificate obligation
for an engine result. This defence-in-depth check turns an engine bug into a
clear error before proof construction. The soundness boundary is the separate
`decide +kernel` proof of the same `Certificate.checks` obligation in the
Mathlib-facing tactic. -/
def Result.check {n : Nat} (problem : Problem n) (result : Result n) : Bool :=
  match problem, result with
  | .closed p gs ps, .closed cert =>
      cert.checks (.closed p) gs ps
  | .closed p gs ps, .closedRefutation cert =>
      let target : CMvPolynomial n Rat := -(strictProductPoly [] ^ 1)
      cert.checks (.closed target) (gs ++ [-p]) ps
  | .closed p gs ps, .nonnegRefutation exponent cert =>
      let target : CMvPolynomial n Rat := -((-p) ^ exponent)
      cert.checks (.closed target) (gs ++ [-p]) ps
  | .strict p gs _ ps, .strict ε hε cert =>
      cert.checks (.strict p ε hε) gs ps
  | .strict p gs strictIdxs ps,
      .strictProduct returnedStrictGs exponent cert =>
      let expectedStrictGs := strictIdxs.map (fun i => gs.getD i 0)
      let target := -(strictProductPoly expectedStrictGs ^ exponent)
      (returnedStrictGs == expectedStrictGs) &&
        cert.checks (.closed target) (gs ++ [-p]) ps
  | .infeasible gs ps, .infeasible cert =>
      cert.checks .infeasible gs ps
  | _, _ => false

/-- Run the complete search policy for a reified problem. This owns all
fallback choices so Mathlib's tactic frontend only reifies, invokes the
engine, rechecks the result, and constructs the corresponding proof. -/
def solve {n : Nat} (cfg : SOS.Config) (problem : Problem n) :
    IO (Option (Result n)) := do
  match problem with
  | .closed p gs ps =>
      let goal : Goal n := .closed p
      if let some cert ← SOS.Search.runSearch goal gs ps
          (maxRoundingDenomLog2 := cfg.maxRoundingDenomLog2)
          (maxDepth := cfg.maxDepth)
          (basisStrategy := cfg.basisStrategy)
          (maxSubsetCardinality := cfg.maxSubsetCardinality) then
        return some (.closed cert)
      if gs.isEmpty && ps.isEmpty then
        if let some cert ← SOS.Search.runClosedRefutation p gs ps
            (maxRoundingDenomLog2 := cfg.maxRoundingDenomLog2)
            (maxDepth := cfg.maxDepth)
            (basisStrategy := cfg.basisStrategy)
            (maxSubsetCardinality := cfg.maxSubsetCardinality) then
          return some (.closedRefutation cert)
        if cfg.maxRefutationPower != 0 then
          if let some (exponent, cert) ← SOS.Search.runNonnegRefutation p gs ps
              (maxPower := cfg.maxRefutationPower)
              (maxRoundingDenomLog2 := cfg.maxRoundingDenomLog2)
              (maxDepth := cfg.maxDepth)
              (basisStrategy := cfg.basisStrategy)
              (maxSubsetCardinality := cfg.maxSubsetCardinality) then
            return some (.nonnegRefutation exponent cert)
      return none
  | .strict p gs strictIdxs ps =>
      if let some result ← SOS.Search.runStrict p gs ps
          (maxRoundingDenomLog2 := cfg.maxRoundingDenomLog2)
          (maxDepth := cfg.maxDepth)
          (basisStrategy := cfg.basisStrategy)
          (maxSubsetCardinality := cfg.maxSubsetCardinality) then
        return some (.strict result.ε result.hε result.cert)
      if let some result ← SOS.Search.runStrictProduct p gs strictIdxs ps
          (maxRoundingDenomLog2 := cfg.maxRoundingDenomLog2)
          (maxDepth := cfg.maxDepth)
          (basisStrategy := cfg.basisStrategy)
          (maxSubsetCardinality := cfg.maxSubsetCardinality) then
        return some (.strictProduct result.strictGs result.exponent result.cert)
      return none
  | .infeasible gs ps =>
      if let some cert ← SOS.Search.runSearch .infeasible gs ps
          (maxRoundingDenomLog2 := cfg.maxRoundingDenomLog2)
          (maxDepth := cfg.maxDepth)
          (basisStrategy := cfg.basisStrategy)
          (maxSubsetCardinality := cfg.maxSubsetCardinality) then
        return some (.infeasible cert)
      return none

end Engine

end SOS
