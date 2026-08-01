import Lake
open Lake DSL

package artifactConsumer

require artifactMiddle from "../artifact-middle"

lean_lib ArtifactPlain

lean_lib ArtifactPrecompiled where
  precompileModules := true

@[test_driver]
lean_lib ArtifactProbe

lean_exe artifactConsumer where
  root := `ArtifactMain
