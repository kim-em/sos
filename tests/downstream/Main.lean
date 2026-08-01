import SosConsumerPlain

def main : IO Unit := do
  unless ← SosConsumer.solveChecked do
    throw <| IO.userError "SOS downstream solve or exact recheck failed"
  IO.println "SOS downstream engine solve: OK"
