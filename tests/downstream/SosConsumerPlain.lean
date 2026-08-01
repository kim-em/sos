import SOS.Engine

open CPoly SOS

namespace SosConsumer

/-- A small positive polynomial used to exercise the external engine API. -/
def polynomial : CMvPolynomial 1 Rat :=
  (CMvPolynomial.X 0) ^ 2 + 1

/-- An unconstrained search problem whose certificate requires CSDP. -/
def problem : Engine.Problem 1 :=
  .closed polynomial [] []

/-- Search for and independently recheck the exact certificate. -/
def solveChecked : IO Bool := do
  let some result ← Engine.solve {} problem
    | return false
  return result.check problem

end SosConsumer
