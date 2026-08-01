import Lake
open Lake DSL

package sosDownstream where
  /- Model a cache-producing consumer such as Mathlib. Engine oleans are
  portable; CSDP remains a platform artifact owned by its provider package. -/
  platformIndependent := true

require sos from "../.."

lean_lib SosConsumerPlain

@[test_driver]
lean_lib SosConsumerTest

lean_exe sosConsumer where
  root := `Main
