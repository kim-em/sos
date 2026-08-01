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

Current Lake appears to have the necessary artifact propagation semantics.
The promising CSDP packaging shape is:

1. compile the CSDP and Lean-wrapper objects into a combined private archive;
2. build a custom platform-specific shared-library target from that archive,
   resolving BLAS/LAPACK/Fortran (or Accelerate) in that build job;
3. return a `Dynlib` for the resolved artifact;
4. expose that target as `CSDP`'s `moreLinkLibs`;
5. do not register the unresolved archive as an `extern_lib`, so downstream
   executables do not also receive the static CSDP objects.

The provider owns platform discovery and flags. Imported Lean libraries'
`moreLinkLibs` are collected by downstream Lean-library and executable link
steps, so SOS and Mathlib need no BLAS/LAPACK knowledge.

This fixture validates the semantics on Linux. Before adopting the model in
`csdp-ffi`, its implementation still needs Linux/macOS/Windows CI. In
particular, Windows must either colocate runtime DLLs or describe them through
`Dynlib.deps`, and the macOS target must resolve Accelerate while building the
provider-owned dylib. The SOS/CSDP native artifact remains platform-specific;
Mathlib oleans can remain platform-independent, with Lake regenerating module
setup data against the per-platform dependency artifact.
