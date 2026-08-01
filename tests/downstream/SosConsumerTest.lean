import SosConsumerPlain

example : SosConsumer.polynomial =
    (CPoly.CMvPolynomial.X 0 : CPoly.CMvPolynomial 1 Rat) ^ 2 + 1 := by
  rfl
