import Lake
open System Lake DSL

package artifactProvider where
  precompileModules := true

input_file secondarySrc where
  path := "native" / "secondary.c"
  text := true

target secondaryO pkg : FilePath := do
  let srcJob ← secondarySrc.fetch
  let oFile := pkg.buildDir / "native" / "secondary.o"
  buildO oFile srcJob #[] #["-fPIC"] "cc"

input_file providerSrc where
  path := "native" / "provider.c"
  text := true

target providerO pkg : FilePath := do
  let srcJob ← providerSrc.fetch
  let oFile := pkg.buildDir / "native" / "provider.o"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO oFile srcJob weakArgs #["-fPIC"] "cc"

target providerCombined pkg : FilePath := do
  let providerJob ← providerO.fetch
  let secondaryJob ← secondaryO.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "artifact_provider")
    #[providerJob, secondaryJob]

target providerDynlib _pkg : Dynlib := do
  let staticJob ← providerCombined.fetch
  let sharedJob ← buildLeanSharedLibOfStatic staticJob
  sharedJob.mapM fun path =>
    return {path, name := "artifact_provider"}

lean_lib ProviderArtifact where
  -- Unlike raw `moreLinkArgs`, imported libraries' `moreLinkLibs` are
  -- collected by downstream shared-library and executable link steps.
  moreLinkLibs := #[`@/providerDynlib]
