# Concurrency shape

How plushie-gleam's runtime is structured under the two
targets, why the parts split the way they do, and the
disciplines that hold them together. Other host SDKs have
their own concurrency shapes; this is plushie-gleam's, and it
is downstream of Gleam's two-target story rather than cross-
SDK convergence.

The pure Elm-loop logic lives in `plushie/runtime_core` and is
shared between both targets. What differs is the concurrency
model: BEAM uses OTP actors and process messages, JS uses
callbacks and the microtask queue. User code does not see
this difference; the runtime hides it behind the same
`Instance(model)` shape.

## The Bridge/Runtime split (BEAM)

Two actors, one supervisor:

- **Bridge** owns the Erlang Port (or the iostream adapter, or
  the BEAM's own stdin/stdout for `Stdio` mode). It owns wire
  framing, transport I/O, renderer process lifecycle, and the
  bounded-backoff restart-on-crash behavior. It knows nothing
  about apps, models, views, or commands. Messages it accepts
  are classified as rebuildable (`Send`) or transient
  (`SendTransient`); rebuildables drop during the restart
  window because the runtime regenerates them; transients
  queue and flush after the runtime signals resync complete.
- **Runtime** owns the app's `init/update/view` loop, the
  current model and tree, the subscription set, the widget
  handler registry, and command execution. It knows nothing
  about the wire format or the renderer process. It receives
  notifications from the bridge (inbound events, renderer
  exits, restart-complete) and sends pre-encoded wire bytes
  back.

Bridge speaks wire, Runtime speaks Elm. They communicate
through Gleam Subjects: the runtime's notification subject
goes to the bridge so the bridge can deliver inbound events;
the bridge's message subject is reachable by the runtime
(through the `BridgeMessage` type) for sending wire bytes.

This split exists because the two responsibilities have
different lifetimes and different failure modes. Bridge
crashes are renderer crashes; the recovery is restart the
binary and replay state. Runtime crashes are app code
crashes; the recovery is supervisor-driven. Mixing the two
would couple recovery paths that should be independent.

## Supervision: RestForOne (BEAM)

The top-level supervisor uses `RestForOne` with
`auto_shutdown: AnySignificant`:

```
plushie supervisor (RestForOne, auto_shutdown: AnySignificant)
- Bridge       (started first)
- Runtime      (registers with bridge after start)
- DevServer    (dev mode only)
```

Order matters:

- **Bridge** starts first and opens the port to the renderer.
  Runtime startup can immediately begin sending settings and
  snapshots without racing the bridge.
- **Runtime** starts second and sends `RegisterRuntime` to
  the bridge with its own notification subject. Any events
  the bridge received before that point are buffered and
  flushed on receipt.
- **DevServer** is dev-mode only; it watches `src/` for
  changes and signals `ForceRerender` to the runtime.

Supervision behavior:

- **Bridge crashes for a reason its own restart cannot
  handle**: Runtime restarts too (rest_for_one). Fresh start.
- **Runtime crashes alone**: Runtime restarts; the bridge
  keeps running and the new runtime re-registers and re-syncs.
- `auto_shutdown: AnySignificant` lets a clean shutdown of
  either child tear down the supervisor cleanly so the user's
  caller sees the exit.

## Subject ownership (BEAM)

Gleam Subjects deliver to the process that called
`process.new_subject()`, not to the process that holds a
reference. Cross-process Subject delivery is a known foot-
gun.

The runtime and bridge each create their own Subjects inside
their spawned process. They hand each other the typed message
constructors, not the Subjects themselves where avoidable.
This is one of the project's load-bearing invariants; tests
that exercise multi-process behavior catch breakage here
quickly because the messages just stop arriving.

## Bridge restart with bounded backoff (BEAM)

When the renderer exits non-zero, the bridge:

1. Marks the port down and notifies the runtime with
   `RendererExited(reason)` so user code can react via
   `handle_renderer_exit`.
2. Drops queued rebuildable messages; queues transient
   messages.
3. Schedules `RestartPort` after a bounded exponential backoff
   delay (capped consecutive failures).
4. On successful reopen, notifies the runtime with
   `RendererRestarted`. Runtime re-sends settings, a fresh
   snapshot of the view, subscriptions, and window state.
5. Once the runtime signals `ResyncComplete`, the bridge
   flushes queued transient messages.

A clean exit (status 0) stops the runtime via the supervisor;
the application has nothing to recover.

## JS runtime: callback-driven loop

On JavaScript, the `runtime_web` module provides a callback-
driven equivalent of the BEAM actor:

- State is stored in a mutable JS object via FFI. There is
  no process boundary; the update cycle is synchronous.
- Async work uses Promises and `setTimeout`/`setInterval`
  through `runtime_web_ffi.mjs`.
- Event coalescing uses `queueMicrotask` to batch high-
  frequency events.
- Callbacks (timer fires, async resolutions, WASM messages)
  enter through the handle's dispatch queue. A callback that
  fires while an update is running is processed after the
  current update/render cycle finishes; one slow callback
  does not interleave with another mid-update.

The pure Elm logic is the same as BEAM: `app.get_update`,
`tree.normalize_view`, `tree.diff`, `protocol/encode` all live
in `runtime_core` and are shared. What differs is which
concurrency primitive holds the state and dispatches events.

The JS bridge (`bridge_web`) talks to the renderer compiled
to WASM through a transport callback. The same wire protocol
flows; framing is handled per-message rather than over a byte
stream because the WASM boundary already delivers discrete
messages.

## Transport boundary (BEAM)

`bridge.gleam` supports three transport modes:

- **Spawn** (default): spawns the renderer binary as a child
  process via an Erlang Port. Standard production transport
  for desktop apps.
- **Stdio**: reads/writes the BEAM's own stdin/stdout. Used
  when the renderer spawns the Gleam process (`plushie-
  renderer-parent exec mode).
- **Iostream(adapter)**: sends and receives via an external
  process implementing the `IoStreamMessage` protocol. Used
  for custom transports (TCP, WebSocket, SSH, etc.) where an
  adapter handles the underlying I/O.

A `TransportOps` record-of-functions centralizes transport
behavior so the bridge's message handler does not branch on
transport variant for every operation. Adding a transport
mode means implementing the operations record; the bridge's
message-handling code does not change.

This is the kind of small, well-justified abstraction that
earns its place: three real implementations from day one, the
shared shape (send, is_ready, restart, close) is genuinely
the same concept, and the Bridge code reads cleanly against
the record.

## SessionPool architecture (BEAM tests)

The test framework runs sessions through a pool when the
backend supports multiplexing:

- **Pooled mock/headless**: one renderer process started with
  `--max-sessions N`; each test gets a session ID. Wire
  messages are tagged with the session ID; the renderer
  routes to per-session state internally. Session startup is
  microseconds; renderer startup is amortized across the
  suite.
- **Windowed**: one renderer process per session because real
  iced windows do not multiplex cleanly. Slower; used when
  window lifecycle matters.

eunit runs tests within a module in the same process, so the
pool sends a `reset` to clear the previous test's renderer
state before reusing the session, preventing widget state
leaks between tests.

## What's not used

- **No `:sys` debug functions** in tests. Tests use the
  public `get_model`, `get_tree`, and `dispatch_event` APIs.
- **No registry-based dynamic supervision for runtimes.**
  Multiple Plushie instances are independent supervisors;
  hundreds of dynamically-spawned plushie instances are not
  in the use case.
- **No staged event pipeline.** The runtime processes events
  serially. Coalescing happens at message arrival.
- **No distributed messaging.** plushie-gleam is a desktop
  runtime; distribution is not in scope.
- **No automatic application start.** The user starts plushie
  under their own supervisor; the SDK is a library, not a
  registered OTP application.

## Implications

- A change that introduces a new long-lived process gets a
  supervision-level question first: where does it fit in
  the rest_for_one chain on BEAM, what is its restart
  strategy, what does its crash mean for the rest of the
  tree.
- A change that makes Bridge or Runtime do something the
  other one already does is suspect. Wire framing in the
  Runtime is wrong; app state in the Bridge is wrong.
- A change that touches `runtime_core` is a multi-target
  question by definition; both targets pick up the change.
- A change that diverges BEAM and JS user-facing behavior
  is a parity bug unless the divergence is explicitly
  documented as a target-shape consequence (e.g., effect
  responses that need a real OS process for file dialogs
  on JS).
- Tests that rely on internal process structure or assume a
  specific actor name are brittle and get rewritten to use
  the public test framework.
