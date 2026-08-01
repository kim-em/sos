# sos

[![CI](https://github.com/leanprover/sos/actions/workflows/ci.yml/badge.svg)](https://github.com/leanprover/sos/actions/workflows/ci.yml)

Harrison's sum-of-squares decision procedure for nonlinear real
arithmetic, in Lean 4. Based on the design from
[Harrison 2007 (TPHOLs)](https://link.springer.com/chapter/10.1007/978-3-540-74591-4_9).

## Adding to your project

Add the following to your `lakefile.toml`:

```toml
[[require]]
name = "sos"
git = "https://github.com/leanprover/sos.git"
rev = "main"
```

Or, in a `lakefile.lean`:

```lean
require sos from git
  "https://github.com/leanprover/sos.git" @ "main"
```

Then `import SOS` and use `by sos`. The system BLAS/LAPACK runtime must
be installed; see [Native dependency troubleshooting](#native-dependency-troubleshooting).

## Status

The `by sos` tactic closes nonlinear-real-arithmetic goals end-to-end:
reify the goal, encode an SDP, call CSDP, round the float Gram matrix
to rationals, decompose via LDLᵀ + Lagrange four-square, and dispatch
the matching verifier-soundness lemma.

## Examples

A curated version of this section lives in
[`SOSTest/Showcase.lean`](SOSTest/Showcase.lean), so `lake test`
checks that these public examples continue to elaborate.

```lean
import SOS

-- Cauchy–Schwarz (rank 1, deg 4, 4 vars)
example (a b c d : ℝ) :
    0 ≤ (a^2 + b^2) * (c^2 + d^2) - (a*c + b*d)^2 := by sos

-- Cyclic Schur, 3 vars
example (a b c : ℝ) : 0 ≤ a^2 + b^2 + c^2 - a*b - b*c - a*c := by sos

-- AM ≥ GM squared
example (x y : ℝ) : 0 ≤ (x^2 + y^2)^2 - 4*x^2*y^2 := by sos

-- Strict positivity, multivariate
example (x y : ℝ) : 0 < x^2 + y^2 + 1 := by sos

-- Infeasibility
example (x : ℝ) : ¬ (x^4 + 1 ≤ 0) := by sos

-- Constrained
example (x : ℝ) (_h : 0 ≤ x) : 0 ≤ x^3 + x := by sos
example (x y : ℝ) (_hx : 0 ≤ x) (_hy : 0 ≤ y) :
    0 ≤ x^2 + 2*x*y + y^2 := by sos

-- Strict-inequality hypothesis (promoted to `0 ≤ x` via `le_of_lt`)
example (x : ℝ) (_h : 0 < x) : 0 ≤ x^3 + x := by sos

-- Equality constraint: discriminant of a real-rooted quadratic
example (a b c x : ℝ) (_h : a*x^2 + b*x + c = 0) :
    0 ≤ b^2 - 4*a*c := by sos

-- Discrete goal, lifted/refuted through ℝ
example : ∀ n : ℕ, n ≤ n * n := by sos

-- Euclidean division over ℕ
example : ∀ a b : ℕ, b ≠ 0 → a = b * (a / b) + a % b := by sos
```

`by sos?` reports the witness it found as a `Try this:` suggestion
that you can paste back as a `sos_witness …` invocation, freezing the
proof so it no longer depends on calling CSDP at compile time:

```lean
example (x : ℝ) : 0 ≤ x^2 + 1 := by sos?
-- Try this:
--   [apply] sos_witness
--     { sigmas := [([], { terms := [((1 : ℚ), CMvPolynomial.C (1 : ℚ)),
--                                   ((1 : ℚ), CMvPolynomial.X 0)] })] }
```

Witness terms are `(c, p)` pairs interpreted as `c · p²`, with
`0 ≤ c` enforced by `Certificate.checks`.

Atoms are recovered as arbitrary `ℝ`-typed subterms (free variables,
function applications, projections — anything the reifier doesn't
recognise as a known operator). Constraint hypotheses can come from
the local context or from `→`-introduced binders.

The Motzkin polynomial `x⁴y² + x²y⁴ + 1 - 3x²y²` is non-negative but
not a sum of squares (Hilbert 1888 / Motzkin 1967), so plain `by sos`
has no certificate to find and correctly fails, caught here by
`fail_if_success`:

```lean
example : True := by
  fail_if_success
    (have : ∀ x y : ℝ,
        0 ≤ x^4 * y^2 + x^2 * y^4 + 1 - 3*x^2*y^2 := by sos)
  trivial
```

Opting into the Positivstellensatz power refutation with
`maxRefutationPower` closes it anyway — `by sos` negates the goal to
`0 < -M`, searches for `-M = σ₀ + σ₁·(-M)` (Harrison's
`REAL_NONLINEAR_PROVER`), and recovers the exact rational certificate
from CSDP's rank-deficient solution by facial reduction:

```lean
example (x y : ℝ) : 0 ≤ x^4*y^2 + x^2*y^4 + 1 - 3*x^2*y^2 := by
  sos (config := { maxRefutationPower := 1 })
```

This is off by default because each power is a family of
growing-degree CSDP solves whose required degree is not known in
advance; see [Scope and limits](#scope-and-limits).

The soundness lemmas reduce to `IsSumSq.nonneg` (Mathlib) once the
goal has been transported through the `aeval` ring-hom on HexMvPoly's
`CMvPolynomial n ℚ` compatibility façade. Two design points worth flagging,
both following
Harrison's [TPHOLs 2007 paper]
(https://link.springer.com/chapter/10.1007/978-3-540-74591-4_9):

- **`min tr(X)` cost matrix.** CSDP's interior-point step has no
  preferred direction on a singleton boundary feasible set, so we
  give it the trace objective Harrison reports works empirically.
- **Zero-pivot LDLᵀ.** Rank-deficient SOS Grams (`(x + y)²` has
  Gram `[[1,1],[1,1]]`, rank 1) require the "completing the square"
  routine to accept a zero pivot when the residual column is also
  zero. Our `SOS.LDL.decompose` does this; `LDL.reconstruct` already
  drops the zero-D contributions.

## Implementation notes

The computational engine depends directly on the Mathlib-free
[`Hex.MvPoly`](https://github.com/leanprover/hex-mv-poly) library. Certificate
checking reduces against its kernel-decidable representation. The small
Mathlib-facing layer under `SOS/Mathlib/` supplies only the real interpretation
and operation laws needed by the soundness proofs; SOS does not depend on the
general `hex-mv-poly-mathlib` correspondence package.

## Scope and limits

- **Rational certificates only.** Witnesses live in
  `CMvPolynomial n ℚ` throughout. CSDP returns floats, which we round
  against a denominator schedule (Harrison's `find_rounding` exactly:
  the integers `[1..31]`, then the powers of two `2^5 … 2^66`, capped
  per-call by `Config.maxRoundingDenomLog2`, the base-2 log of the cap,
  default `66`) and decompose via rational LDLᵀ. Each σ-block is a
  weighted sum of squares `Σᵢ cᵢ · pᵢ²` with `cᵢ ∈ ℚ≥0`; the
  non-negativity is `decide +kernel`-checked at certificate time.
  There is no support for algebraic-extension coefficients — a goal
  whose only SOS witness involves `√2` (or any other irrational) is
  out of reach by construction.

- **Putinar form, with hypotheses as multipliers.** A certificate is
  `target = σ₀ + Σᵢ σᵢ · gᵢ` with each `σᵢ` an SOS, where the `gᵢ`
  are non-negativity hypotheses pulled from `intro`-binders and the
  local context. Recognised constraint shapes are `0 ≤ g`, `g ≤ 0`
  (encoded as `0 ≤ −g`), and `0 < g` (used via `le_of_lt`).
  Unconstrained goals reduce to `target = σ₀`. Strict positivity
  `0 < p` is handled by an LP-slack maximisation: one extra
  decision variable `λ ≥ 0` enters the SDP via the constant-monomial
  equality, CSDP maximises it to discover the largest admissible
  slack `λ*`, and then `ε = 2^-k` near `λ*` is fed to the standard
  feasibility pipeline to produce the verifiable certificate.
  Infeasibility uses `target = −1`.

- **Single fixed relaxation level by default.** Multiplier basis sizes
  are set once from a degree bound `D = max(deg(target), maxᵢ deg(gᵢ))`:
  the σ₀ basis is monomials up to `⌈D/2⌉`, and each σᵢ basis is monomials
  up to `⌈max(0, D − deg(gᵢ))/2⌉`. The default search runs no hierarchy
  walk that bumps the relaxation order on failure, so a goal needing a
  higher order is left open.

- **Non-SOS non-negative polynomials, opt-in.** A polynomial that is
  non-negative but not a sum of squares (Motzkin
  `x⁴y² + x²y⁴ + 1 − 3x²y²` is the canonical example) has no direct
  certificate, so the default search fails. Setting
  `maxRefutationPower := k` enables Harrison's `REAL_NONLINEAR_PROVER`
  power refutation: for `i = 1 … k` it searches for a certificate of
  `−(−p)^i` against `{−p ≥ 0}` (negate the goal, then refute `0 < −p`),
  and recovers the exact rational certificate from CSDP's rank-deficient
  boundary solution by **facial reduction** — rationalising the
  null-space projector of the float Gram and imposing it as exact linear
  constraints. This is off by default: each power is a family of
  growing-degree CSDP solves, the required degree is unknown a priori,
  and the recovery adds a symmetric eigendecomposition per block.

- **Search failure is not a soundness failure.** When CSDP returns an
  unusable status, when no rounding denominator validates, or when
  LDLᵀ reconstruction can't close the certificate, `by sos` reports
  "no certificate found" and leaves the goal open. The
  `Certificate.checks` predicate that closes the goal is
  `decide +kernel`-checked against `Certificate n` data, so a proof
  that goes through is independent of CSDP correctness.

## Building and testing

This repository is pinned to the Lean version in
[`lean-toolchain`](lean-toolchain); dependencies are pinned by
[`lake-manifest.json`](lake-manifest.json).

```
git clone https://github.com/leanprover/sos
cd sos
lake exe cache get
lake test
```

`lake test` elaborates `SOSTest`, which runs `by sos` against every
example in [`SOSTest/Examples.lean`](SOSTest/Examples.lean) — each
invocation calls CSDP, rounds the Gram matrix, reconstructs the
certificate, and checks it. A passing `lake test` is end-to-end
verification of the search/round/reconstruct/verify pipeline.

### Native dependency troubleshooting

The tactic calls CSDP through `csdp-ffi`, so BLAS/LAPACK must be
available before Lean can load the native solver. If `lake build` or
`lake test` fails while compiling or linking native code, run:

```
(cd .lake/packages/CSDP && lake script run checkNativeDeps)
```

That preflight reports the platform-specific packages or SDK paths
expected by the native build. For examples that invoke CSDP, prefer
Lake targets such as `lake test`; running a file directly with
`lake env lean SomeFile.lean` may bypass the native link setup needed
for the solver.

## Architecture

The tactic runs three stages on a `by sos` goal:

1. `SOS.Reify.parseGoalAtomic` in `SOS.Mathlib.Reify` walks the goal expression, collecting
   atomic ℝ-typed subterms into an array and producing untyped
   `SOS.Poly.Raw` ASTs for the conclusion and each constraint
   hypothesis (drawn from `intro`-binders and the local context).
2. `SOS.Engine.solve` owns the complete search policy. It builds the
   Putinar-form SDP, calls CSDP, rounds the float Gram matrix to rationals,
   runs LDLᵀ, and returns a structured result covering every proof route.
3. `SOS.Mathlib.Tactic` reruns `SOS.Engine.Result.check` and discharges the
   real-arithmetic goal via the matching soundness lemma in
   `SOS.Mathlib.Verifier`.

| Module | What it provides |
|---|---|
| `SOS.Raw` | Mathlib-free `Poly.Raw` and typed `Poly n` ASTs. |
| `SOS.Polynomial` | The narrow operational `Hex.MvPoly` API used by the engine. |
| `SOS.Certificate` | `Goal n`, `SOSDecomp`, `Certificate n`, `checks` predicate. |
| `SOS.Core` | Stable Mathlib-free data and executable-checking interface for proof-facing consumers. |
| `SOS.LDL` | Rational LDLᵀ and Gram→weighted-square reconstruction. |
| `SOS.Search` | Putinar-form SDP encoding, CSDP integration, rounding and reconstruction. |
| `SOS.Engine` | Native solver façade: public `Config`, `Problem`, `Result`, `solve`, and deterministic `Result.check`. |
| `SOS.Mathlib.Raw` | Interpretation of the raw and typed polynomial syntax over `ℝ`. |
| `SOS.Mathlib.Certificate` | Interpretation of certificate decompositions and checked identities over `ℝ`. |
| `SOS.Mathlib.Polynomial` | Narrow real interpretation and operation-preservation lemmas. |
| `SOS.Mathlib.Verifier` | Certificate/result soundness over `ℝ`. |
| `SOS.Mathlib.Reify` | Atom-collecting Lean-`Expr` walker → `ParsedGoal`. |
| `SOS.Mathlib.Lift` | Lifting and refutation bridges for `ℕ`, `ℤ`, and `ℚ`. |
| `SOS.Mathlib.Tactic` | `by sos`, `by sos?`, `by pure_sos`, and witness elaborators. |
| `SOSTest.Examples` | Worked examples invoking the tactic; serves as the `lake test` driver. |
| `SOSTest.Showcase` | Curated launch/demo examples that are also covered by `lake test`. |

## Dependencies

| Package | Purpose |
|---|---|
| [`leanprover-community/mathlib4`](https://github.com/leanprover-community/mathlib4) | Real semantics, soundness proofs, reification, lifting and tactic elaboration under `SOS/Mathlib/`. |
| [`leanprover/hex-mv-poly`](https://github.com/leanprover/hex-mv-poly) | Mathlib-free kernel-decidable multivariate-polynomial substrate. |
| [`leanprover/csdp-ffi`](https://github.com/leanprover/csdp-ffi) | FFI wrapper around CSDP 6.2.0. Vendored CSDP source. |

System dependencies (BLAS/LAPACK, transitively via csdp-ffi):

| Platform | Packages |
|----------|---|
| Linux    | `liblapack-dev libblas-dev gfortran` |
| macOS    | Apple Command Line Tools (Accelerate framework) |
| Windows  | MSYS2 mingw-w64 with `mingw-w64-x86_64-openblas` |

CI runs Linux-only.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development workflow and
test expectations.

## Licence

Apache License 2.0 (see [LICENSE](LICENSE)). Transitively, CSDP is
distributed under the
[Eclipse Public License 1.0](https://github.com/coin-or/Csdp/blob/master/LICENSE).

## References

- John Harrison, "Verifying Nonlinear Real Formulas Via Sums of Squares" (TPHOLs 2007).
- Pablo Parrilo, *Structured Semidefinite Programs and Semialgebraic Geometry* (Caltech PhD, 2000).
- Helena Peyrl & Pablo Parrilo, "Computing sum of squares decompositions with rational coefficients" (Theor. Comput. Sci. 2008).
- Brian Borchers, [CSDP](https://github.com/coin-or/Csdp).
- [Coq Micromega `psatz`](https://coq.inria.fr/refman/addendum/micromega.html) — design template.
