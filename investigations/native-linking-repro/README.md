# Transitive native-link interface reproducer

This fixture isolates the native-linking question from CSDP. In both variants,
a provider C wrapper calls a symbol from a second native library, a middle Lean
package imports the provider, and a root package imports only the middle. The
root lakefile contains no native link configuration.

The fixture targets Lean/Lake 4.32.0-rc1. Run commands from the relevant
consumer directory with that toolchain selected.

## Raw-link-argument variant

`provider/` declares its wrapper as an `extern_lib` and puts the hidden native
archive in package-level `moreLinkArgs`. `middle/` and `consumer/` are ordinary
path dependencies.

```text
provider (extern_lib + moreLinkArgs) → middle → consumer
```

From `consumer/`:

```sh
lake update
lake build RootPlain
lake build RootPrecompiled:shared
lake test
lake build consumer
```

The first three builds succeed; the test driver evaluates the native call and
prints `42`. The executable link fails with:

```text
undefined symbol: secondary_value
... provider.o:(provider_value) in archive libprovider.a
```

This demonstrates the distinction in current Lake: transitive `extern_lib`
static artifacts are collected, while the provider package's `moreLinkArgs`
are not part of the downstream link interface.

## Exported-artifact variant

`artifact-provider/` instead builds one fully resolved shared library as a
custom `Dynlib` target and exports that target through the provider Lean
library's `moreLinkLibs`. It does **not** register the corresponding static
archive as an `extern_lib`. `artifact-middle/` and `artifact-consumer/` remain
ordinary dependencies.

```text
provider (custom Dynlib + moreLinkLibs) → middle → consumer
```

From `artifact-consumer/`:

```sh
lake update
lake build ArtifactPlain ArtifactPrecompiled:shared
lake test
lake build artifactConsumer
.lake/build/bin/artifactConsumer
```

All commands succeed and both the test driver and executable print `42`.
On Linux, the executable has a `DT_NEEDED` entry and a Lake-generated `RUNPATH`
for `libartifact_provider.so`; the second native implementation is owned by
that shared library.

## Elaboration and server behavior

The test drivers elaborate and execute the native call successfully because
Lake passes the generated module setup data. The same setup can be used in a
manual Lean invocation:

```sh
lake env lean ArtifactProbe.lean \
  --setup=.lake/build/ir/ArtifactProbe.setup.json
```

A bare `lake env lean ArtifactProbe.lean` fails to load the external
implementation. That is a general limitation of invoking `lean` without
Lake's per-module `--setup` data, rather than a missing transitive link
interface. `lake serve` was also exercised through an LSP `didOpen`; it loaded
the native dependency without a missing-symbol diagnostic.

## Consequence for CSDP

Current Lake has the necessary artifact-propagation semantics. The production
implementation is in
[`csdp-ffi` PR #6](https://github.com/leanprover/csdp-ffi/pull/6), pinned by
SOS at its merge revision.

The provider owns platform discovery, flags, runtime ordering, and native
artifacts. Linux and macOS use a C-only resolved solver library plus a separate
Lean bridge. Windows keeps the solver and bridge in one binary so allocations
do not cross C-runtime heaps; distinct load and link names let Lake record the
interpreter DLL while native targets consume the combined static archive.
OpenBLAS is an explicit `Dynlib` dependency on Windows.

The provider CI exercises plain and precompiled libraries, the test driver, a
native executable, explicit module setup, editor loading on Linux, and
platform-artifact restoration. Linux, macOS, and Windows all build and run the
root and flag-free downstream solver fixtures. The Windows fixture also checks
that the native executable does not import the interpreter bridge or Lean's
shared runtime.

SOS therefore has no BLAS/LAPACK link configuration. Its own
`platformIndependent := true` downstream fixture imports `SOS`, elaborates
real `by sos` proofs, runs the Lake test driver and native executable, and uses
explicit setup without native flags. The SOS/CSDP native artifact remains
platform-specific; portable consumer oleans coexist with Lake-regenerated
module setup against the per-platform provider artifact.
