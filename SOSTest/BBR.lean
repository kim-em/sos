/-
Copyright (c) 2026 Kim Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import SOS

open SOS CPoly

/-! ## BBR Lemma 7.2

Regression test for the degree-8 bivariate polynomial of Lemma 7.2 in
Blomer–Brumley–Radziwill (https://arxiv.org/abs/2603.05609,
https://github.com/maksym-radziwill/BBR), reported on
[Zulip](https://leanprover.zulipchat.com/#narrow/channel/423402-PrimeNumberTheorem.2B/topic/sum.20of.20squares.20tactic.3A.20seeking.20users/near/595692701)
by Maksym Radziwill on 2026-05-18.

Pre-fix: `by sos` returned `search failed to find a certificate`.
The polynomial has integer coefficients up to `5.8 × 10¹²`. The
weighted-square certificate format (`Σᵢ cᵢ · pᵢ²` with `cᵢ ≥ 0`)
dropped the four-squares bottleneck but was not enough on its own:
no float Gram CSDP returns at depth-0 rounds to a rational matrix
that exactly reproduces the target.

Issue #75 added the Artin-form Positivstellensatz fallback (`sos
(config := { maxArtinExponent := … })`), which proves `0 ≤ p` via a
closed cert of `p^{2k+1}` against `gs ++ [−p]`. The structural path
is now in place but the SDP conditioning for BBR — coefficients
`O(5×10¹²)^{2k+1}` and bases of size hundreds — remains beyond CSDP's
reach at the denominator schedule and depth we currently expose.
Closing it for real likely needs both a wider denominator schedule
(Harrison goes up to `2^66`) and a much larger relaxation depth. -/

-- BBR (degree 8 in 2 vars, integer coefficients up to ~5.8×10¹²) is
-- still out of reach for `by sos`, even with the Artin-form
-- Positivstellensatz fallback enabled. Recorded as `fail_if_success`
-- so the test suite captures the regression target without blocking
-- on it. The infrastructure (issue #75) is in place — once the
-- denominator schedule and relaxation depth grow to Harrison's
-- `REAL_SOS` levels, flip this to a direct `by sos (config := {
-- maxArtinExponent := 7 })`.
example : True := by
  fail_if_success
    (have : ∀ x y : ℝ,
        0 ≤ 5217874549248 + 16623868928 * y - 3336250252672 * y ^ 2
          - 25477793408 * y ^ 3 + 655195946720 * y ^ 4 + 10587831584 * y ^ 5
          - 152613570520 * y ^ 6 - 1371845320 * y ^ 7 + 41790603610 * y ^ 8
          - 16640770048 * x + 5796896462336 * x * y + 2432177280 * x * y ^ 2
          - 2074067626368 * x * y ^ 3 - 167534816 * x * y ^ 4
          - 3336702739328 * x ^ 2 - 2399492480 * x ^ 2 * y
          + 5223381207392 * x ^ 2 * y ^ 2 + 2035437600 * x ^ 2 * y ^ 3
          - 1238781629424 * x ^ 2 * y ^ 4 + 25484108416 * x ^ 3
          - 2074041622592 * x ^ 3 * y - 2039508160 * x ^ 3 * y ^ 2
          + 914071084096 * x ^ 3 * y ^ 3 + 409594776 * x ^ 3 * y ^ 4
          + 655694115936 * x ^ 4 + 155563456 * x ^ 4 * y
          - 1238844857440 * x ^ 4 * y ^ 2 - 407914952 * x ^ 4 * y ^ 3
          + 359512561893 * x ^ 4 * y ^ 4 - 10586722304 * x ^ 5
          - 152799075816 * x ^ 6 + 1371693928 * x ^ 7
          + 41813434533 * x ^ 8 := by sos)
  trivial
