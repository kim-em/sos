# SOS engine

[![CI](https://github.com/leanprover/sos/actions/workflows/ci.yml/badge.svg)](https://github.com/leanprover/sos/actions/workflows/ci.yml)

A Mathlib-free sum-of-squares search engine for Lean 4, based on Harrison's
verified nonlinear-real-arithmetic procedure. The engine builds exact rational
certificates from semidefinite programs solved by CSDP.

The proof-producing `sos` tactic, real semantics, soundness theorems, goal
reifier, and user documentation live in `Mathlib.Tactic.SOS`. Most users should
import that Mathlib module. This repository is the native search dependency
behind it.

## Engine API

`SOS.Core` exposes the stable polynomial, goal, and certificate-checking data.
`SOS.Engine` additionally exposes the native search façade:

```lean
import SOS.Engine

open CPoly SOS

def problem : Engine.Problem 1 :=
  .closed ((CMvPolynomial.X 0 : CMvPolynomial 1 Rat) ^ 2 + 1) [] []

def findCertificate : IO Bool := do
  let some result ← Engine.solve {} problem
    | return false
  return result.check problem
```

The public interface is deliberately narrow:

- `SOS.Config` controls degree, denominator, basis, preordering, and refutation
  search limits;
- `SOS.Engine.Problem` represents closed, strict, and infeasibility problems;
- `SOS.Engine.Result` represents every certificate route;
- `SOS.Engine.solve` owns the complete fallback policy;
- `SOS.Engine.Result.check` deterministically rechecks the exact rational
  certificate obligation.

The floating-point CSDP solver is untrusted. Search failure merely returns
`none`, and successful results are accepted only after exact checking. Mathlib's
proof-facing layer proves the corresponding real-arithmetic soundness theorem
from the same Boolean certificate check.

## Architecture

The engine performs the computational stages of the tactic:

1. Construct a Putinar- or preordering-form semidefinite program over the
   Mathlib-free `Hex.MvPoly` representation.
2. Invoke CSDP and round its floating-point Gram matrices to rationals using
   Harrison's denominator schedule.
3. Reconstruct weighted sums of squares using rational LDLᵀ decomposition and
   Lagrange four-square decomposition.
4. Return a structured result together with an exact, kernel-reducible
   certificate check.

| Module | Purpose |
|---|---|
| `SOS.Raw` | Untyped and fixed-arity polynomial syntax. |
| `SOS.Polynomial` | Narrow operational `Hex.MvPoly` adapter. |
| `SOS.Certificate` | Goals, weighted SOS decompositions, certificates, and executable checking. |
| `SOS.Core` | Stable Mathlib-free proof-consumer interface. |
| `SOS.RatLinAlg` | Exact rational row reduction and elimination. |
| `SOS.RatSimplex` | Exact Phase-1 simplex used by Newton-polytope pruning. |
| `SOS.LDL` | Rational LDLᵀ and Gram reconstruction. |
| `SOS.Search` | SDP encoding, CSDP invocation, rounding, and reconstruction. |
| `SOS.Engine` | Public problem/result types, complete search policy, and result recheck. |

## Adding the engine to a project

In a `lakefile.lean`:

```lean
require sos from git
  "https://github.com/leanprover/sos.git" @ "main"
```

Or in `lakefile.toml`:

```toml
[[require]]
name = "sos"
git = "https://github.com/leanprover/sos.git"
rev = "main"
```

Downstream packages do not copy CSDP, BLAS, LAPACK, or Fortran link flags.
`csdp-ffi` owns the resolved solver and bridge artifacts and propagates the
required load/link metadata transitively.

## Building and testing

Install the native dependencies below, then run:

```sh
lake build SOS
lake test
scripts/check_mathlib_boundary.sh
scripts/test_downstream.sh
```

The boundary check rejects Mathlib source imports and Mathlib-facing packages
from both the engine tree and the resolved Lake graph. The downstream test
builds a portable library, a test driver, a native executable, and a direct
Lean setup path without native configuration; the executable performs a real
CSDP solve and exact result recheck.

### Native dependencies

| Platform | Packages |
|---|---|
| Linux | `liblapack-dev libblas-dev gfortran` |
| macOS | Apple Command Line Tools (`Accelerate`) |
| Windows | MSYS2 `mingw-w64-x86_64-openblas` and `mingw-w64-x86_64-gcc-fortran` |

To diagnose a missing runtime, run:

```sh
(cd .lake/packages/CSDP && lake script run checkNativeDeps)
```

## Dependencies

| Package | Purpose |
|---|---|
| [`leanprover/hex-mv-poly`](https://github.com/leanprover/hex-mv-poly) | Mathlib-free kernel-decidable multivariate polynomials. |
| [`leanprover/csdp-ffi`](https://github.com/leanprover/csdp-ffi) | FFI and native packaging for vendored CSDP 6.2.0. |

## Licence

The Lean and bridge code is Apache License 2.0; see [LICENSE](LICENSE).
Vendored CSDP is distributed under the
[Common Public License 1.0](https://github.com/leanprover/csdp-ffi/blob/main/vendored/csdp/LICENSE).

## References

- John Harrison, “Verifying Nonlinear Real Formulas Via Sums of Squares,” TPHOLs 2007.
- Pablo Parrilo, *Structured Semidefinite Programs and Semialgebraic Geometry*, 2000.
- Helena Peyrl and Pablo Parrilo, “Computing sum of squares decompositions with rational coefficients,” 2008.
- Brian Borchers, [CSDP](https://github.com/coin-or/Csdp).
