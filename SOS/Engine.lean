/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import SOS.Search

namespace SOS

open CPoly

/-- Search configuration independent of any tactic frontend. -/
structure Config where
  /-- Iterative-deepening cap for polynomial bases. -/
  maxDepth : Nat := 1
  /-- Base-2 logarithm of the largest rationalisation denominator. -/
  maxRoundingDenomLog2 : Nat := 66
  /-- Basis pruning strategy used by the SDP search. -/
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

/-- Deterministically recheck an engine result against its original problem.
This is the trust boundary used by the Mathlib-facing elaborator: no result
from CSDP is consumed without this executable polynomial identity check. -/
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
fallback choices so the Mathlib tactic frontend only reifies, invokes the
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
