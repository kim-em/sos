/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Pure invariant checks for search / round / reconstruct helpers. These
exercise internal helpers (`monomialsUpTo`, `decodeSdpBlock`,
`LDL.reconstruct`, the rounding-denominator schedule) on degenerate
or boundary inputs, so a refactor that mis-handles the empty / null
case is caught here rather than only by the end-to-end `by sos`
examples in `SOSTest.Examples`.
-/
import SOS

open SOS CPoly

/-! ### Rounding-denominator schedule (#15, extended in #38, #77, #66)

The schedule is exactly Harrison's `sos.ml` `find_rounding`:
`map num (1--31) @ map pow2 (5--66)`, i.e. `[1..31]` followed by the
pure powers `2^5, …, 2^66`. The `maxRoundingDenomLog2` config field
(default exponent `66`, i.e. `2^66`, matching Harrison) caps this list
at the call site. -/

#guard SOS.Search.niceDenominators.length = 31 + 62
#guard (SOS.Search.niceDenominators.take 31) =
    ((List.range 31).map (fun i => (i + 1 : ℚ)))
#guard (SOS.Search.niceDenominators.drop 31).take 6 =
    [(32 : ℚ), 64, 128, 256, 512, 1024]
#guard SOS.Search.niceDenominators.getLast? = some ((2 ^ 66 : ℚ))

-- Pure powers only — the densified `3·2^(k-1)` entries are gone.
#guard SOS.Search.niceDenominators.contains (31 : ℚ)
#guard SOS.Search.niceDenominators.contains ((2 ^ 5 : ℚ))
#guard !SOS.Search.niceDenominators.contains (96 : ℚ)

/-! ### `niceRound` regression: large-denominator precision

Before the hybrid `niceRound`, the pure-`Float` path used
`Float.toUInt64` on `x * d + 0.5`, which saturates at `2^64 - 1`.
For denominators above roughly `2^53` this silently produced
nonsense rationals (e.g. `niceRound (2^66) 1.0 = (2^64-1)/2^66 ≈
1/4` instead of `1`). The exact-path fallback fixes this. -/

#guard SOS.Search.niceRound ((2 ^ 66 : Nat) : ℚ) 1.0 = 1
#guard SOS.Search.niceRound ((2 ^ 66 : Nat) : ℚ) 0.5 = 1 / 2
#guard SOS.Search.niceRound ((2 ^ 60 : Nat) : ℚ) (-1.0) = -1
#guard SOS.Search.niceRound ((2 ^ 49 : Nat) : ℚ) 1.0 = 1
-- Fast Float path still correct on schedule entries.
#guard SOS.Search.niceRound ((2 ^ 24 : Nat) : ℚ) 1.0 = 1
#guard SOS.Search.niceRound ((3 : ℚ)) 0.5 = 2 / 3
#guard SOS.Search.niceRound ((3 : ℚ)) (-0.5) = -2 / 3

/-! ### Exact rational row reduction -/

#guard
  let R := SOS.RatLinAlg.rref 2
    #[#[(1 : ℚ), 1, 3],
      #[(2 : ℚ), -1, 0]]
  R.pivots = #[0, 1] ∧ R.freeCols = #[] ∧
    R.rows = #[#[(1 : ℚ), 0, 1], #[(0 : ℚ), 1, 2]]

#guard
  let R := SOS.RatLinAlg.rref 3
    #[#[(1 : ℚ), 1, 0, 0]]
  R.pivots = #[0] ∧ R.freeCols = #[1, 2]

#guard
  match SOS.RatLinAlg.eliminateAll 2
      #[#[(1 : ℚ), 1, -3],
        #[(2 : ℚ), -1, 0]] with
  | some E =>
      E.freeCols = #[] ∧
        E.assignments.map (fun (v, row) => (v, row)) =
          #[(0, #[(0 : ℚ), 0, 1]), (1, #[(0 : ℚ), 0, 2])]
  | none => false

/-! ### `monomialsUpTo` -/

#guard (SOS.Search.monomialsUpTo 2 2).size = 6

#guard
  match (SOS.Search.monomialsUpTo 2 2)[1]? with
  | some m =>
    let a := CMvMonomial.degreeOf m ⟨0, by decide⟩
    let b := CMvMonomial.degreeOf m ⟨1, by decide⟩
    a = 1 ∧ b = 0
  | none => False

/-! ### Degenerate `decodeSdpBlock` / `LDL.reconstruct` -/

#guard
  match SOS.Search.decodeSdpBlock (1 : ℚ) 2 FloatArray.empty with
  | none => true
  | some _ => false

#guard
  match SOS.LDL.reconstruct 2 (#[] : Array ℚ)
      (#[] : Array (CMvPolynomial 1 ℚ)) with
  | none => true
  | some _ => false
