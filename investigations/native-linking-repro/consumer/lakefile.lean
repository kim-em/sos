import Lake
open Lake DSL

package consumer

require middle from "../middle"

lean_lib RootPlain

@[test_driver]
lean_lib RootProbe

lean_lib RootPrecompiled where
  precompileModules := true

lean_exe consumer where
  root := `Main
