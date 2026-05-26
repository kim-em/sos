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

This file pins the two structural pieces already in place — the
weighted-square certificate format (PR #72) and the Harrison-style
parameterised reduced encoding (this PR's `tryReducedPureSdp`
generalisation) — but BBR still does not close. The remaining
barrier is PSD-rounding margin: at every relaxation depth in the cap,
CSDP returns a feasible float `y*` for the reduced parameter space,
but rounding `y*` to any rational in the schedule produces a Gram
just outside the PSD cone. Closing BBR needs shrinkage toward the
analytic centre of the feasible set (a richer mitigation than the
boundary `y* → 0` direction we currently expose), or a different SDP
solver formulation that returns interior points.

Recorded as `fail_if_success` so the regression target is captured. -/

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
