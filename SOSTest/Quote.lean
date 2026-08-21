/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Kim Morrison
-/
module

meta import SOS.Quote
meta import Lean.Elab.Tactic.Basic

open CPoly SOS

private meta def p : CMvPolynomial 1 Rat :=
  CMvPolynomial.C 1 + CMvPolynomial.X 0

private meta def cert : Certificate 1 :=
  { sigmas := [([], { terms := [(1, p)] })] }

example : True := by
  run_tac
    let actual := (SOS.Poly.decompile p).format
    let expected := "CMvPolynomial.X 0 + CMvPolynomial.C (1 : ℚ)"
    unless actual == expected do
      throwError "polynomial formatting mismatch:\n{actual}"
  exact True.intro

example : True := by
  run_tac
    let actual := cert.decompile.format
    let expected :=
      "{ sigmas := [([], { terms := [((1 : ℚ), CMvPolynomial.X 0 + CMvPolynomial.C (1 : ℚ))] })] }"
    unless actual == expected do
      throwError "certificate formatting mismatch:\n{actual}"
  exact True.intro
