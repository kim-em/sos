# Contributing

Thanks for helping improve `sos`.

## Development Setup

Install Lean through `elan`, then from the repository root run:

```bash
lake exe cache get
lake test
```

`lake test` is the primary check for exact-rational search helpers. Run
`scripts/test_downstream.sh` as well to exercise a real CSDP solve and exact
certificate recheck through the public engine API.

## Pull Requests

- Keep changes focused and include a regression test when fixing engine behavior.
- Prefer `SOSTest/Internal.lean` for search and reconstruction invariants and
  `SOSTest/RatSimplexTests.lean` for exact-simplex and Newton-polytope coverage.
- User-facing tactic behavior and proof-producing regression examples belong in
  Mathlib's `MathlibTest/Tactic/SOS/` suite.
- Avoid adding `sorry` or `axiom` to `SOS/`; CI checks for both.
- Document known search limitations as comments near disabled examples rather than silently deleting them.

## Dependencies

The package is pinned by `lake-manifest.json`. If dependency revisions change, include the manifest update and mention why the bump is needed.
