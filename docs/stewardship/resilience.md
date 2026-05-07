# Resilience

plushie-gleam is meant to behave predictably when things go
wrong: a panic in user code, a malformed wire message from the
renderer, the renderer process crashing, a broken pipe, a
subscription source that explodes, an async task that throws, a
WASM module that fails to load. Resilience here is graceful
behavior under those conditions, not hardening against an
attacker; that distinction lives in `trust-model.md`.

The user-facing promise is the host SDK's half of the broader
Plushie promise: a renderer crash auto-recovers with state
re-sync, a runtime panic does not corrupt state, neither side
takes the other down. This doc describes how plushie-gleam holds
up that half on each target.

## What resilience means here

Gleam's static type system and `Result`-first error model do
substantial resilience work for free: many "things go wrong"
classes that are runtime concerns in dynamic languages are
compile errors here. The runtime focuses on the conditions the
type system cannot enforce: process crashes, transport failure,
external panics in callbacks, malformed wire input.

- **Errors as values.** Recoverable conditions return
  `Result(t, e)`. The user reads them at the call site; the
  runtime does not throw across the Elm loop. Async tasks that
  fail surface as `AsyncResult(Error(...))` events, not
  uncaught exceptions.
- **Bridge-mediated renderer crash recovery (BEAM).** The bridge
  owns the Erlang Port and the renderer process lifecycle. On a
  non-zero exit, the bridge classifies messages as rebuildable
  (settings, snapshots, patches, subs, window ops) or transient
  (effects, widget ops, image ops, interact, advance_frame).
  Rebuildables are dropped during the restart window because the
  runtime regenerates them; transients are queued and flushed
  after the runtime signals resync is complete. Restart uses
  bounded exponential backoff with a configured cap on
  consecutive failures.
- **App model preserved across restart.** The runtime keeps the
  current model through bridge restarts. After the renderer
  comes back, settings are re-sent, the view is re-rendered as a
  fresh snapshot, subscriptions and windows are re-synced, stale
  coalescable events are discarded, and pending effects fail
  with a stable code (`renderer_restarted`).
- **Supervised process tree (BEAM).** A `RestForOne` supervisor
  with `auto_shutdown: AnySignificant` owns Bridge and Runtime,
  plus a DevServer in dev mode. If Bridge dies for a reason
  bridge-restart cannot handle, Runtime restarts too and the
  user's `start` caller decides recovery via the standard
  supervisor signal.
- **Subject ownership (BEAM).** Subjects are created inside the
  process that receives on them. Cross-process Subject delivery
  is a known foot-gun in Gleam; the runtime and bridge each own
  their own Subjects and do not hand them across boundaries.
- **JS callback isolation.** On the JS target, callbacks (timer
  fires, async resolutions, WASM messages) enter through the
  handle's dispatch queue. A callback that fires during an
  active update/render cycle is processed after the current
  cycle finishes; one slow callback does not interleave with
  another mid-update.
- **Defensive parsing on the wire.** The codec assumes its input
  could be wrong: malformed MessagePack, unknown event variants,
  missing required fields, type-coercion mismatches.
  `protocol/decode` returns errors as values; the bridge logs
  and continues rather than crashing the runtime.
- **Buffer-overflow framing cap.** `transport/framing` rejects
  frames that exceed `max_message_size` (64 MiB) with a
  structured `BufferOverflow` error. Silent truncation would
  risk desync.
- **Coalescing for high-frequency sources.** Mouse moves, sensor
  resizes, and similar high-frequency events are deferred and
  collapsed to the latest value per source. A flooding renderer
  cannot overwhelm the BEAM mailbox or the JS microtask queue.
- **Async nonces.** Every async/stream task carries a monotonic
  nonce. The runtime validates the nonce before dispatching
  results; stale results from cancelled tasks are silently
  discarded.
- **Dispatch-loop guard.** `Command.dispatch` chains synchronously
  through the runtime; a pathological update that keeps returning
  another dispatch would fill the BEAM mailbox or pump the JS
  microtask queue. The runtime caps chain depth and emits a
  typed diagnostic (`DispatchLoopExceeded`) when the cap fires.

## What is appropriate to fail fast on

Some conditions are not recoverable at the framework level and
should fail fast rather than degrade:

- **Programming errors that violate runtime invariants.** A
  Subject created in the wrong process, a patch path that is
  not `List(Int)`, a leaked metadata tag in a normalized tree.
  These are bugs in the SDK or in widget authoring code; the
  right behavior is a clear panic, not silent fallback.
- **Unrecoverable bridge startup.** If the renderer binary is
  not findable on BEAM, `start` returns
  `BinaryNotFound(BinaryError)`; the caller decides recovery.
  If the supervisor itself fails to start, `SupervisorStartFailed`
  surfaces with the underlying actor error.
- **Wire framing corruption.** A truncated or unparseable frame
  on the bridge's input is not a recoverable condition; the
  bridge surfaces it and shuts down so the supervisor can
  decide whether to restart.

The line: degrade gracefully on user-facing conditions (app code
errors, parse errors, transport hiccups, renderer crashes). Fail
fast on framework-level invariant violations.

## Patterns in the codebase

Worth maintaining as the project evolves:

- `Result(t, e)` for fallible operations; the SDK never returns
  a sentinel "bad" value of the success type.
- Wire-edge validation in `protocol/decode` and `tree`;
  structured errors, never silent passthrough of malformed input.
- Effect request tracking with timeout timers on BEAM; stale
  responses dropped, in-flight responses correlated by request
  ID.
- Bridge restart with fresh snapshot re-sync rather than
  attempting to replay buffered events.
- Coalescable event handling for high-frequency sources so a
  flooding renderer cannot overwhelm the runtime.
- Typed diagnostics (`event.Diagnostic`) for renderer-side
  conditions the runtime cannot fix on its own; surfaced to the
  user as `Error(ErrorEvent)` for visibility.

## What resilience is not

- **Not adversarial-input hardening.** The threat model is
  "things go wrong," not "attacker is trying to crash."
  Findings framed as the latter are usually misframed; see
  `trust-model.md`.
- **Not perfectionism.** The runtime does not try to fix the
  user's logic for them; it surfaces structured diagnostics.
- **Not retry-at-any-cost.** A failed command surfaces a
  structured event; the user's `update` decides whether to
  retry. The runtime does not retry on its own beyond the
  bounded bridge-restart loop.
- **Not defense against impossible states.** Adding a defensive
  branch for a condition that cannot occur given the surrounding
  invariants is accidental complexity, not resilience. The bar
  for "cannot occur" is reading the surrounding code and being
  confident in the invariant, not exhaustive proof. Gleam's
  type system already prunes most of these.

## Implications

- A real things-go-wrong path producing an ungraceful failure
  (a runtime crash that does not surface to the supervisor, a
  bridge that hangs instead of restarting, a stale effect tag
  delivering to the wrong handler, a JS callback that throws
  through the dispatch queue) is in scope today and earns
  priority.
- Inconsistency between resilience patterns (one site recovers,
  another swallows; one source logs and continues, another
  crashes) is itself a resilience bug because future maintainers
  cannot predict behavior.
- Defensive layers for conditions Gleam's type system already
  prevents are out of scope; they add accidental complexity
  without reducing real failure modes.
- Aborting on conditions where graceful degradation is the right
  answer ("this should panic on bad event content") is the
  wrong direction; the established pattern is reject-and-report.
