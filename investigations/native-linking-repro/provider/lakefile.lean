import Lake
open System Lake DSL

package provider where
  precompileModules := true
  extraDepTargets := #[`secondary]
  -- This is the link interface which current Lake uses only for this package's
  -- own link steps. It deliberately names an otherwise-hidden native archive.
  moreLinkArgs := #[
    (__dir__ / ".lake" / "build" / "lib" /
      nameToStaticLib "secondary").toString
  ]

input_file secondarySrc where
  path := "native" / "secondary.c"
  text := true

target secondary pkg : FilePath := do
  let srcJob ← secondarySrc.fetch
  let oFile := pkg.buildDir / "native" / "secondary.o"
  let oJob ← buildO oFile srcJob #[] #["-fPIC"] "cc"
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "secondary") #[oJob]

input_file providerSrc where
  path := "native" / "provider.c"
  text := true

target providerO pkg : FilePath := do
  let srcJob ← providerSrc.fetch
  let oFile := pkg.buildDir / "native" / "provider.o"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO oFile srcJob weakArgs #["-fPIC"] "cc"

extern_lib providerNative pkg := do
  let oJob ← providerO.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "provider") #[oJob]

lean_lib Provider
