/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Kim Morrison
-/
module

public import SOS.Certificate
public meta import Lean.Meta.AppBuilder

/-!
# Quoting SOS certificates as Lean source

Mathlib-facing tactics can use this module to quote certificates found by the
Mathlib-free search engine and render replayable `sos_witness` arguments.
-/

namespace SOS

open CPoly Lean

public meta section

namespace Poly

/-- Build a `Lean.Expr` denoting an `SOS.Poly n`. -/
partial def toExpr {n : Nat} (p : SOS.Poly n) : Lean.Expr :=
  let nE := Lean.mkNatLit n
  match p with
  | .const r => mkApp2 (.const ``SOS.Poly.const []) nE (Lean.toExpr r)
  | .var i => mkApp2 (.const ``SOS.Poly.var []) nE (Lean.toExpr i)
  | .neg p => mkApp2 (.const ``SOS.Poly.neg []) nE p.toExpr
  | .add p q => mkApp3 (.const ``SOS.Poly.add []) nE p.toExpr q.toExpr
  | .sub p q => mkApp3 (.const ``SOS.Poly.sub []) nE p.toExpr q.toExpr
  | .mul p q => mkApp3 (.const ``SOS.Poly.mul []) nE p.toExpr q.toExpr
  | .pow p k => mkApp3 (.const ``SOS.Poly.pow []) nE p.toExpr (Lean.mkNatLit k)

instance instToExpr (n : Nat) : Lean.ToExpr (SOS.Poly n) where
  toExpr := Poly.toExpr
  toTypeExpr := Lean.mkApp (.const ``SOS.Poly []) (Lean.mkNatLit n)

end Poly

end

@[expose] public section

/-- Render a rational as Lean source. -/
def formatRat (r : Rat) : String :=
  if r.den = 1 then s!"({r.num} : ℚ)"
  else s!"(({r.num} : ℚ) / {r.den})"

namespace Poly

/-- Decompile a canonical polynomial into the syntax tree used for quotation. -/
def decompile {n : Nat} (p : CPoly.CMvPolynomial n Rat) : SOS.Poly n :=
  p.1.toList.foldr
    (fun (term : CPoly.CMvMonomial n × Rat) (acc : SOS.Poly n) =>
      SOS.Poly.add acc (ofMonomial term.2 term.1))
    (SOS.Poly.const 0)
where
  ofMonomial (c : Rat) (mono : CPoly.CMvMonomial n) : SOS.Poly n :=
    Fin.foldr n (init := SOS.Poly.const c) fun i acc =>
      let e := mono[i]
      if e = 0 then acc else SOS.Poly.mul acc (SOS.Poly.pow (SOS.Poly.var i) e)

/-- Render a polynomial as Lean source using `CMvPolynomial.C` and
`CMvPolynomial.X`. -/
partial def format {n : Nat} (p : SOS.Poly n)
    (parenIfComposite : Bool := false) : String :=
  match p with
  | .add (.const r) q =>
    if r = 0 then format q parenIfComposite
    else composite parenIfComposite s!"CMvPolynomial.C {formatRat r} + {format q}"
  | .add p (.const r) =>
    if r = 0 then format p parenIfComposite
    else composite parenIfComposite s!"{format p} + CMvPolynomial.C {formatRat r}"
  | .add p q => composite parenIfComposite s!"{format p} + {format q}"
  | .sub p q => composite parenIfComposite s!"{format p} - {format q true}"
  | .mul (.const r) q =>
    if r = 1 then format q parenIfComposite
    else composite parenIfComposite s!"CMvPolynomial.C {formatRat r} * {format q true}"
  | .mul p (.const r) =>
    if r = 1 then format p parenIfComposite
    else composite parenIfComposite s!"{format p true} * CMvPolynomial.C {formatRat r}"
  | .mul p q => composite parenIfComposite s!"{format p true} * {format q true}"
  | .neg p => composite parenIfComposite s!"-{format p true}"
  | .pow p 1 => format p parenIfComposite
  | .pow p k => composite parenIfComposite s!"{format p true}^{k}"
  | .const r => s!"CMvPolynomial.C {formatRat r}"
  | .var i => s!"CMvPolynomial.X {i.val}"
where
  composite (parens : Bool) (s : String) : String :=
    if parens then s!"({s})" else s

end Poly

namespace Certificate

/-- A certificate expressed with quotable polynomial syntax trees. -/
structure Decompiled (n : Nat) where
  /-- Subset-indexed weighted-square terms. -/
  sigmas : List (List Nat × List (Rat × SOS.Poly n))
  /-- Equality cofactors. -/
  eqCofs : List (SOS.Poly n) := []

/-- Decompile a search certificate into quotable polynomial syntax trees. -/
def decompile {n : Nat} (cert : SOS.Certificate n) : Decompiled n :=
  { sigmas := cert.sigmas.map fun pair =>
      (pair.1, pair.2.terms.map fun term => (term.1, SOS.Poly.decompile term.2))
    eqCofs := cert.eqCofs.map SOS.Poly.decompile }

/-- Build a `SOS.Certificate n` expression from a decompiled certificate. -/
meta def Decompiled.toExpr {n : Nat} (cert : Decompiled n) : Lean.Meta.MetaM Lean.Expr := do
  Lean.Meta.mkAppOptM ``SOS.Certificate.fromDecompiled
    #[some (Lean.mkNatLit n), some (Lean.toExpr cert.sigmas), some (Lean.toExpr cert.eqCofs)]

/-- Render a decompiled certificate as a replayable `sos_witness` argument. -/
def Decompiled.format {n : Nat} (cert : Decompiled n) : String :=
  let eqSuffix :=
    if cert.eqCofs.isEmpty then "" else s!", eqCofs := {formatEqCofs cert.eqCofs}"
  s!"\{ sigmas := {formatSigmas cert.sigmas}{eqSuffix} }"
where
  formatTerms (terms : List (Rat × SOS.Poly n)) : String :=
    "[" ++ ", ".intercalate
      (terms.map fun term => s!"({formatRat term.1}, {term.2.format})") ++ "]"
  formatIndices (indices : List Nat) : String :=
    "[" ++ ", ".intercalate (indices.map toString) ++ "]"
  formatSigmas (sigmas : List (List Nat × List (Rat × SOS.Poly n))) : String :=
    let entries := sigmas.map fun pair =>
      s!"({formatIndices pair.1}, \{ terms := {formatTerms pair.2} })"
    "[" ++ ", ".intercalate entries ++ "]"
  formatEqCofs (eqCofs : List (SOS.Poly n)) : String :=
    "[" ++ ", ".intercalate (eqCofs.map Poly.format) ++ "]"

end Certificate

end

end SOS
