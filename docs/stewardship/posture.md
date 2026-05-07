# Project posture

What plushie-gleam is, who it is for, and the disciplines that
keep it that way.

## What plushie-gleam is

The Gleam host SDK for Plushie. An Elm-architecture app runtime
that drives the renderer (Rust binary, native windows via iced)
over a typed wire protocol on stdin/stdout. The SDK ships as a
hex/Gleam package; user apps build an `App(model, msg)` from
`init/update/view`, declare their UI with the typed widget
builders, and the runtime handles diffing, command dispatch,
subscriptions, and bridge lifecycle.

Gleam compiles to both BEAM (Erlang VM) and JavaScript. The SDK
supports both targets: BEAM apps run as OTP-supervised actors
talking to the renderer subprocess; JS apps run a callback-driven
loop talking to the renderer compiled to WASM (or remote, via the
same wire protocol). The pure layer (widgets, events, commands,
tree, protocol) is the same on both targets; the concurrency
shape differs (see `concurrency-shape.md`).

This SDK is one of six host SDKs sharing the renderer (Elixir,
Rust, Gleam, Python, Ruby, TypeScript). The renderer binary is
shared; each SDK implements its own runtime against it.

## Audience

- App developers writing Plushie apps in Gleam. They see the
  `App` type, the typed widget builders under `plushie/widget/*`
  and `plushie/ui`, the command and subscription APIs, and the
  test framework.
- Widget authors writing pure-Gleam composite widgets via
  `plushie/widget`, or wiring native (Rust) widgets in through
  `plushie/native_widget`.
- SDK maintainers. The runtime, the bridge, the wire codecs, the
  cross-target story, the test backends.

The package's public API is anything documented with `///` doc
comments. Internal modules carry no public-API obligation. The
top-level `plushie`, `plushie_web`, `plushie/app`, `plushie/event`,
`plushie/command`, `plushie/node`, `plushie/ui`, the per-widget
modules under `plushie/widget/*`, and the property types under
`plushie/prop/*` are public. Modules under `plushie/protocol/*`,
`plushie/transport/*`, `plushie/testing/*`, and the FFI layer are
internal.

## Cross-SDK relationship

Six host SDKs is a load-bearing constraint, not an accident.

- **plushie-elixir is the shape tiebreaker.** When a concept's
  name, structure, or parameter ordering is contested across SDKs,
  plushie-elixir is the answer. plushie-gleam follows.
- **plushie-rust is the protocol authority.** Wire format, message
  variants, codec spec live in plushie-rust's `docs/protocol.md`.
  A wire change is a six-SDK change.
- **plushie-gleam is not the reference SDK.** "More idiomatic in
  Gleam" alone is not justification for breaking parity. Within-
  language idiom prevails on syntax (snake_case, custom types over
  enums-as-strings, builder pipelines, `Result` over exceptions).
  Concepts, names, parameter ordering, and behavior converge with
  the other SDKs.
- **Cross-SDK parity audits live in `plushie-sdk-parity/`.**
  Findings about parity drift route through that workflow rather
  than as standalone work here.

A plushie-gleam API rename that does not propagate to the other
SDKs is drift, not refactoring. The bar for renaming a widget
field, an event constructor, a command shape, or a subscription
type is "is the new name actually better across every SDK," with
plushie-elixir as the tiebreaker.

## Stage

Pre-1.0. There is no backwards-compatibility obligation today.
When the best design requires renaming a constructor, a field, or
restructuring a module, that is the right call. The CHANGELOG
notes breaking changes explicitly.

The 1.0 boundary is when stability obligations begin. Until then,
the priority is getting the shape right, not preserving the
current shape. Pre-1.0 is the time to settle questions about API
shape, naming, and structure that will be expensive to revisit.

API stability hardening (sealed unions, opaque-where-possible
audits, doc comment audits) lands in a single planned sweep at
the 1.0 cut, not piecemeal during normal development.

## Disciplines

Recurring decision rules. Not negotiable on a per-ticket basis.

- **Tests run through the real renderer.** On BEAM, the default
  backend runs `plushie-renderer --mock`: real binary, real wire,
  real Core engine, no GPU. A test that passes against a
  pure-Gleam substitute and would fail against the binary is
  worse than no test. See `test-discipline.md` for the JS-target
  story and where stubs are acceptable.
- **Cross-SDK claims are verified, not assumed.** When the
  question is "does plushie-elixir do this the same way," the
  answer comes from reading source on each side. "It looks like"
  is not a verification.
- **Design before code at boundaries.** Public Gleam API, the
  widget builder shape, the wire protocol on the Gleam side, the
  `App` type, the test-backend contract. Internal refactors can
  iterate fast; boundary changes pay the design tax up front.
- **Clarity is the bar.** Code reads clearly to someone new to
  the file; abstractions earn their place by use, not by
  hypothesis; complexity is a cost. See `simplicity.md`.
- **No half-built features.** A feature lands fully or not at
  all. Half-built features create drift in the parity surface
  and accumulate into "the docs say it does X but three SDKs
  do not actually."
- **Use the type system aggressively.** Custom types over
  string enums; opaque builders over open records where the
  invariant matters; `Result` over panics for recoverable
  conditions; no general-purpose `coerce` or `unsafe_coerce`.
- **Local cleanup, not scope creep.** Small, low-risk
  improvements to code under active modification are welcome.
  Larger or risky adjacent improvements get noted and advocated
  for as follow-on work, not silently rolled into the current
  change.
- **No legacy or compatibility shims.** Pre-1.0; remove dead
  paths cleanly rather than preserving old behavior.
