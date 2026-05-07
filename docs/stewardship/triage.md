# Triage

How proposed work gets evaluated against the stewardship docs.

Sources of proposed work are many: design proposals, refactor
ideas, library upgrades, feature requests, breaking-change
calls, "while I was in there" cleanups, cross-SDK divergence
flags, observations from review passes. The flow below applies
regardless of source. The underlying docs (`posture.md`,
`goals-and-non-goals.md`, `trust-model.md`, `resilience.md`,
`performance-bar.md`, `test-discipline.md`, `simplicity.md`,
`elm-invariants.md`, `dsl-discipline.md`,
`concurrency-shape.md`) are the authority on each axis; this
file is a consolidated routing tool.

## Outcomes

For any proposed work, one of:

- **Do.** Aligned with a stated goal, addresses a real bug,
  or is plain maintenance hygiene that does not warrant a
  stewardship-level question.
- **Defer to a roadmap item.** Real concern tied to a
  considered direction not currently scheduled. Append to
  the relevant `roadmap/<item>.md` "Observations" section as
  context for when the work is taken up.
- **Decline.** Misframed against the trust model, defends
  against speculative futures or impossible states, asks for
  work without the evidence the relevant doc requires, or
  otherwise lands on a stated non-goal.
- **Route to cross-SDK parity.** Concerns parity drift or an
  SDK API shape that affects parity. Goes through the
  `plushie-sdk-parity` workflow rather than being decided
  here.

## Routing flow

For a piece of proposed work, run these in order. First match
wins.

1. **Cross-SDK shape.** Does the work alter or surface drift
   in an API shape, behavior name, parameter ordering, event
   variant shape, or wire form across multiple SDKs? Route
   to the parity workflow. plushie-elixir is the shape
   tiebreaker; plushie-gleam follows. See `posture.md`.

2. **Elm invariants.** Does the work touch the
   `init`/`update`/`view` contract, the return-tuple shape,
   command shape, subscription diffing, widget event flow, or
   scoped IDs? Treat as a deliberate decision; default to no
   unless the change is genuinely a fix to the contract. The
   contract is the cross-SDK story; see `elm-invariants.md`.

3. **Trust-model misframe.** Does the proposal assume a
   threat model the project does not currently make a claim
   against (host as adversary under an unclaimed boundary,
   browser-grade isolation of arbitrary remote hosts, wire-
   as-its-own-crypto)? Decline; reference `trust-model.md`.

4. **Renderer-to-host integrity.** Does the work touch the
   decoder in a way that loosens the closed-shape contract
   (passing through unknown event variants as opaque values,
   spoofable response correlation, an unsafe parser shape, a
   `coerce` plumbed in)? Treat as a deliberate decision, not
   a routine refactor; default to no.

5. **Resilience axis.** Does the work address a real things-
   go-wrong path that fails ungracefully (a runtime crash
   that does not surface to the supervisor, a bridge that
   hangs instead of restarting, a stale request ID delivering
   to the wrong handler, a JS callback that throws through
   the dispatch queue)? Do; reference `resilience.md`.
   Conversely, does the proposal add defensive layers for
   conditions Gleam's type system already prevents or that
   cannot occur given surrounding invariants? Decline.

6. **Wire codec correctness.** Encode/decode symmetry,
   round-trip through MessagePack and JSONL, field-name drift
   between encoder and renderer, BEAM/JS encoder parity. Do;
   stated goal.

7. **Multi-target parity.** Does the work make the BEAM and
   JS targets diverge on user-visible API or behavior (a
   widget that works on one but not the other, an event
   variant emitted on one target only, a command with
   different semantics)? Treat as a deliberate decision;
   default to keeping parity. Target-specific FFI in
   `platform.gleam` and `runtime_web.gleam` is fine; user-
   facing divergence is not.

8. **Lightweight by default.** Does the work consolidate
   redundant work, choose a data structure better suited to
   the realistic profile, remove clearly unnecessary per-call
   cost (an extra `list` pass, redundant `PropValue`
   rebuilding, repeated `dict.get` chains), while preserving
   or improving readability? Do; reference `performance-bar.md`.
   Conversely, is the work clever-for-speed at the cost of
   intent, or a big-O claim without realistic N? Decline
   absent measurement.

9. **Test discipline.** Does the work move tests off the
   integration spine on BEAM (mocking the renderer with pure
   Gleam, replacing real binary tests with substitutes,
   peeking at supervisor children)? Decline; reference
   `test-discipline.md`. Does it move tests onto the spine
   (rewriting a substitute test to run through the binary)?
   Do.

10. **Builder/DSL extension.** Does the proposal add a new
    widget option, a new builder pattern, a new helper in
    `plushie/ui`, a new property type? Run the criteria in
    `dsl-discipline.md` (two real users, real bug class
    addressed, generated docs read cleanly, compile errors
    point at the call site). If it does not pass, decline or
    defer.

11. **Concurrency-shape change.** Does the work introduce a
    new long-lived process, change the BEAM supervisor
    strategy, alter the Bridge/Runtime split, change the JS
    dispatch queue semantics, or move work between targets?
    Treat as a stewardship-level question; reference
    `concurrency-shape.md`.

12. **Simplicity axis.** Single-user abstraction? Module
    split without a forcing function? Premature generic
    where specific would do? `coerce`-shaped helper?
    Internal `Dynamic` plumbing? Decline; reference
    `simplicity.md`. Conversely, three-similar-lines that
    have grown into a real concept and want to be
    abstracted? Do.

13. **Stated non-goal.** Backwards compatibility before 1.0,
    API stability hardening as standalone work, coverage
    milestones, refactoring without a forcing function,
    defending against a speculative deployment shape.
    Decline; reference `goals-and-non-goals.md`.

## Default behavior

If nothing matches and the work is plain maintenance
(advisories, portability bugs, broken examples, dead code,
typo-class corrections, obvious self-consistency restorations),
the default is to do it without a stewardship category. The
flow earns its keep on the harder cases: declining speculative
defenses, deferring to roadmap items, recognizing trust-model
misframes, distinguishing real algorithmic consolidation from
speculative micro-optimization, distinguishing real builder
extensions from costume abstractions.

## When the docs need updating

If the proposed work feels stewardship-level (a real direction
question, a new constraint, a posture the docs have not yet
taken) but does not match any axis above, that is a signal the
docs are missing a category. Surface the question to the
maintainer rather than improvising a category, and update the
docs once the direction is settled.

The docs decay when every novel question gets shoehorned into
the closest existing axis. They stay useful by being explicit
about what they cover and acknowledging when they do not cover
something.
