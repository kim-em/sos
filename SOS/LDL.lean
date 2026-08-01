/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Rational LDLᵀ decomposition for weighted-square Gram reconstruction.

These are pure executable algorithms. Their *output* is verified
downstream (the certificate's polynomial identity, and the
non-negativity of each weighted-square coefficient, are checked by
`decide +kernel` against `Certificate.checks`); no Lean-side
correctness proofs are needed at this layer. If LDL fails (matrix is
not PSD on its diagonal pivots) we return `none` and the search loop
tries the next denominator.
-/
import SOS.Certificate

namespace SOS.LDL

open CPoly

/-! ### Rational LDLᵀ decomposition -/

/-- Index into the upper-triangle row-major flat array for an n×n matrix.
We store entries `Q[i,j]` for `0 ≤ i ≤ j < n` at position
`i*n - i*(i+1)/2 + j`. -/
@[inline] def upperIdx (n : Nat) (i j : Nat) : Nat :=
  i * n - i * (i + 1) / 2 + j

/-- Number of entries in the upper-triangle storage for an `n × n`
symmetric matrix. -/
@[inline] def upperSize (n : Nat) : Nat :=
  n * (n + 1) / 2

/-- Read entry `(i, j)` from a symmetric matrix stored as upper-triangle.
The caller may pass `i > j`; we transpose. -/
@[inline] def readSym (n : Nat) (Q : Array Rat) (i j : Nat) : Rat :=
  if i ≤ j then Q[upperIdx n i j]! else Q[upperIdx n j i]!

/-- Result of LDLᵀ: `L` (n×n lower-unit-triangular, row-major dense) and
`D` (length-n diagonal). -/
structure LDLT where
  n : Nat
  L : Array Rat
  D : Array Rat
  deriving Inhabited, Repr

namespace LDLT

@[inline] def get (ldl : LDLT) (i j : Nat) : Rat := ldl.L[i * ldl.n + j]!

end LDLT

/-- Compute the rational LDLᵀ decomposition of a symmetric matrix `Q`
(upper-triangle flat form). Returns `none` if any pivot is strictly
negative or if the matrix is not PSD. Zero pivots are accepted when
the corresponding residual column is also zero — this is the
"completing the square" convention from Harrison's HOL Light
`Examples/sos.ml`, and lets us decompose rank-deficient PSD matrices
whose Gram lies on the boundary of the PSD cone (e.g. the unique SOS
Gram of `(x + y)²`). When `D[j] = 0` we set `L[i, j] := 0` for
`i > j`; `LDL.reconstruct` and `transposeMulBasis` already drop
zero-`D` and zero-`L` contributions. -/
def decompose (n : Nat) (Q : Array Rat) : Option LDLT := Id.run do
  if Q.size ≠ upperSize n then return none
  let mut L : Array Rat := Array.replicate (n * n) 0
  let mut D : Array Rat := Array.replicate n 0
  for j in [0:n] do
    let mut djAcc : Rat := readSym n Q j j
    for k in [0:j] do
      let ljk := L[j * n + k]!
      djAcc := djAcc - D[k]! * ljk * ljk
    if djAcc < 0 then return none
    D := D.set! j djAcc
    L := L.set! (j * n + j) 1
    if djAcc = 0 then
      -- Rank deficient at this pivot. The matrix is PSD iff the
      -- residual column for this `j` is also zero. Check; reject if
      -- any residual is non-zero, otherwise leave `L[i, j] = 0`.
      for i in [j+1:n] do
        let mut numer : Rat := readSym n Q i j
        for k in [0:j] do
          numer := numer - D[k]! * L[i * n + k]! * L[j * n + k]!
        if numer ≠ 0 then return none
    else
      for i in [j+1:n] do
        let mut numer : Rat := readSym n Q i j
        for k in [0:j] do
          numer := numer - D[k]! * L[i * n + k]! * L[j * n + k]!
        L := L.set! (i * n + j) (numer / djAcc)
  return some { n := n, L := L, D := D }

/-! ### Reconstruction: Gram matrix → list of weighted-square terms -/

/-- Compute `Lᵀ · z`. The result has length `ldl.n`; element `i` is
`Σ_k L[k,i] · z[k]`. -/
def transposeMulBasis {nVar : Nat} (ldl : LDLT)
    (basis : Array (CMvPolynomial nVar Rat)) :
    Option (Array (CMvPolynomial nVar Rat)) := Id.run do
  let n := ldl.n
  if basis.size ≠ n then return none
  let mut w : Array (CMvPolynomial nVar Rat) := Array.mkEmpty n
  for i in [0:n] do
    let mut acc : CMvPolynomial nVar Rat := CMvPolynomial.C 0
    for k in [0:n] do
      let lki := ldl.get k i
      if lki ≠ 0 then
        let some bk := basis[k]? | return none
        acc := acc + CMvPolynomial.C lki * bk
    w := w.push acc
  return some w

/-- Given a PSD rational matrix `Q` and a basis polynomial vector `z`,
produce a list of weighted-square terms `(Dᵢ, wᵢ)` representing
`Σᵢ Dᵢ · wᵢ²ᵢ` where `D` is LDLᵀ's diagonal and `w = Lᵀ · z`. Pivots
satisfy `Dᵢ ≥ 0` by `decompose`'s precondition; zero pivots are
dropped. -/
def reconstruct {nVar : Nat} (n : Nat) (Q : Array Rat)
    (basis : Array (CMvPolynomial nVar Rat)) :
    Option (List (Rat × CMvPolynomial nVar Rat)) := Id.run do
  if Q.size ≠ upperSize n then return none
  if basis.size ≠ n then return none
  let some ldl := decompose n Q | return none
  let some w := transposeMulBasis ldl basis | return none
  let mut acc : Array (Rat × CMvPolynomial nVar Rat) := #[]
  for i in [0:n] do
    let Di := ldl.D[i]!
    let some wi := w[i]? | return none
    if Di ≠ 0 then
      acc := acc.push (Di, wi)
  return some acc.toList

end SOS.LDL
