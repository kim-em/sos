/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Kim Morrison
-/

import HexMvPoly

namespace CPoly

open Hex

universe u

/-- SOS's fixed-arity monomial representation. -/
abbrev CMvMonomial (n : Nat) := Mono n

/-- SOS's canonical sparse polynomial representation, using lexicographic
monomial order.  This alias deliberately requires only the operational
`Zero` class from Lean core; algebraic laws belong to the Mathlib-facing
semantic layer. -/
abbrev CMvPolynomial (n : Nat) (R : Type u) [Zero R] :=
  Hex.MvPoly n R Mono.lex

namespace CMvMonomial

/-- Exponent lookup with SOS's established monomial argument order. -/
def degreeOf {n : Nat} (m : CMvMonomial n) (i : Fin n) : Nat :=
  Mono.degreeOf i m

end CMvMonomial

namespace CMvPolynomial

export Hex.MvPoly
  (C X monomial eval eval₂ bind bind₁)

/-- Coefficient lookup with SOS's established polynomial-first argument order. -/
def coeff {n : Nat} {R : Type u} [Zero R]
    (p : CMvPolynomial n R) (m : CMvMonomial n) : R :=
  Hex.MvPoly.coeff m p

/-- Monomials in the canonical order supplied by `Hex.MvPoly`. -/
def monomials {n : Nat} {R : Type u} [Zero R]
    (p : CMvPolynomial n R) : List (CMvMonomial n) :=
  Hex.MvPoly.monomials p

/-- Compatibility alias for the polynomial's canonical monomial support. -/
def support {n : Nat} {R : Type u} [Zero R]
    (p : CMvPolynomial n R) : List (CMvMonomial n) :=
  Hex.MvPoly.support p

/-- Maximum total degree among the polynomial's monomials. -/
def totalDegree {n : Nat} {R : Type u} [Zero R]
    (p : CMvPolynomial n R) : Nat :=
  Hex.MvPoly.totalDegree p

end CMvPolynomial

end CPoly
