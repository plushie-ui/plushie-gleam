# Goals and non-goals

The objectives plushie-gleam optimizes for, and the explicit
non-objectives it declines work against. The lists are
deliberately short; they earn their place by being recurring
decision criteria, not by enumerating every aspiration.

## Goals

Testable shipping criteria. Findings that improve any of these
are real work.

- **Wire protocol fidelity on the host side.** Messages encode
  and decode identically against every other SDK and the
  renderer; the codec stays in lockstep with the renderer's spec
  (authority lives in plushie-rust); values round-trip through
  MessagePack and JSONL without coercion drift.
- **Cross-SDK concept parity.** Concepts (event variants, widget
  options, command constructors, subscription types) converge
  with the other host SDKs at the semantic level. plushie-elixir
  is the shape tiebreaker; see `posture.md`.
- **Elm-architecture purity.** `init/update/view` is the user's
  contract. Return shapes are typed at the SDK boundary; commands
  are pure data; effects push to the edges; `view` is a pure
  function of model. The runtime preserves these invariants on
  both targets. See `elm-invariants.md`.
- **Lightweight runtime.** Idle apps do no measurable work. No
  polling, no per-frame walking when nothing changed, no
  spinning subscription threads, no microtask hot loop on JS.
  Tree diffs are minimal. See `performance-bar.md`.
- **Fault tolerance across the wire.** On BEAM, renderer crash
  is detected by the bridge, which restarts the binary with
  bounded backoff, replays settings, and re-syncs the tree from
  a fresh snapshot. App panic in the runtime loop reverts to the
  last good state. Neither side takes the other down. See
  `resilience.md`.
- **Multi-target parity.** BEAM and JavaScript targets run the
  same `App(model, msg)` against the same widget vocabulary.
  Pure modules (widgets, events, commands, tree, protocol)
  compile unchanged on both. The runtime shape differs (actors
  on BEAM, callbacks on JS); user code does not.
- **Type-system clarity.** Events are a flat union with typed
  fields per variant; commands are a parameterized union; widget
  builders are opaque types with chainable setters. Invalid
  states should be unrepresentable where the cost is reasonable.

## Non-goals

Explicit non-objectives. Findings or proposals that push the
project toward them get declined; they are not candidates that
lost a priority contest.

- **Backwards compatibility before 1.0.** The right design wins;
  the rename happens. Hex-style version pinning plus the
  CHANGELOG is the contract.
- **Per-Gleam API ergonomics that diverge from cross-SDK shape.**
  See `posture.md`. "More idiomatic in Gleam" alone is not
  sufficient; the shape question routes through the parity
  workflow with plushie-elixir as the tiebreaker.
- **API stability hardening before 1.0.** Sealed-union audits,
  opaque-everywhere passes, doc-comment audits, public/internal
  separation audits. These happen in a single planned sweep at
  the 1.0 cut, not piecemeal during normal development.
- **Coverage targets as a metric.** Test discipline is "exercise
  real surfaces through the renderer," not "hit a percentage."
  See `test-discipline.md`.
- **Mocking the renderer for speed on BEAM.** mock-mode in the
  real binary is already fast (microseconds to milliseconds per
  test); a pure-Gleam mock that bypasses the wire is faster only
  at the cost of the exact bug class the integration spine
  catches. The JS target uses an in-memory session backend
  because the renderer compiles to WASM there; that is target
  shape, not a corner-cut for speed.
- **Micro-optimization at the cost of readability.** Clever
  encoding, lookup, or layout schemes in hot paths need to earn
  the obscurity with measurement. Optimizations that look clean
  and do not damage readability are welcome; see
  `performance-bar.md`.
- **Refactoring without a forcing function.** Module size or
  file length alone is not a reason to refactor. The trigger is
  a real change that the existing structure cannot accommodate
  cleanly.
- **General-purpose Dynamic plumbing.** `Dynamic` belongs at
  wire-edge decode, async result payloads, and the `app_opts`
  boundary. Internal modules pass typed values. A new internal
  call site that takes `Dynamic` is a design problem; the type
  upstream wants to be parameterized instead.
- **DSL extensions for hypothetical future widgets.** A new
  builder option, a new builder pattern, a new helper earns its
  place when at least two real users would benefit. "We might
  want this someday" is a reason not to extend.
- **Defending against speculative deployment shapes.** Untrusted
  multi-tenant runtimes, browser-as-arbitrary-host on the wire,
  sandboxed user apps inside other Gleam runtimes. None of
  these are current goals. Defenses against them are out of
  scope unless and until the shape is taken up.
