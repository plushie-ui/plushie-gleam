# Elm-architecture invariants

The contract between user apps and the runtime. These
invariants hold across every plushie-gleam app, on both BEAM
and JavaScript targets; the runtime enforces them and the test
framework relies on them. Other host SDKs implement the same
shape (modulo language idiom); plushie-elixir is the canonical
reference per `posture.md`. Where Gleam's expression of an
invariant differs from Elixir's (typed return tuples instead
of dynamic shape validation, custom-type unions instead of
struct families), the underlying contract is the same.

## The three callbacks

A Plushie app builds an `App(model, msg)` value via
`app.simple` or `app.application`. The shapes:

- `init(app_opts: Dynamic) -> #(model, Command(msg))`. Called
  once at startup. Returns the initial model and an initial
  command (`command.none()` if no side effects).
- `update(model, msg) -> #(model, Command(msg))`. Called for
  every message. Returns the next model and a command.
- `view(model) -> List(Node)`. Called after every update.
  Returns a list of top-level window nodes. An empty list
  renders nothing (loading, transition, error states); a
  single-element list renders that window; a multi-element
  list renders peer windows.

Optional callbacks set on `App`: `on_event` (Event -> msg
mapping for custom-msg apps), `subscribe` (model -> list of
subscriptions), `handle_renderer_exit` (model + RendererExit ->
model on BEAM bridge restart).

`app.simple(init, update, view)` constructs an App where
`msg = Event` directly. `app.application(init, update, view,
on_event)` lets the user define a custom message type and map
events through `on_event` at the dispatch boundary.

## Return-shape correctness is type-checked

The Gleam type system enforces what Elixir's
`unwrap_result/1` enforces dynamically: `init` and `update`
must return a `#(model, Command(msg))` tuple. There is no
"misshapen return" runtime category here; the compiler refuses
to build the SDK against an `init` or `update` that returns
the wrong shape.

`Command(msg)` is the unit of "no side effect" via
`command.none()`. There is no separate "noreply" shape, no
implicit list-flatten, no shape that returns "no change." A
returned model unchanged from the input model is the no-change
shape; the runtime diffs the resulting view against the
previous view and emits an empty patch list.

For `Batch(commands)`, an empty list is valid and means "no
side effect" (equivalent to `command.none()`). The runtime
handles list order and execution; user code does not.

## Commands are pure data

`Command(msg)` is a parameterized union type. The runtime
executes it; user code never executes a command directly. This
is what makes `update` testable without going through I/O: the
test asserts the command was returned; the runtime is what
would have run it.

Command categories (`plushie/command`):

- `None`, `Batch(commands)`.
- Async work: `Async(work, tag)`, `Stream(work, tag)`,
  `Cancel(tag)`, `Done(value, mapper)`.
- `SendAfter(delay_ms, msg)` for delayed self-dispatch.
- `Exit` for runtime shutdown.
- `Renderer(RendererCommand)` for everything that targets the
  renderer: focus, scroll, widget ops, window ops, image ops,
  effects, widget commands, animation frame advance.

A user dispatching a side effect that is not a command is a
design problem with the side effect, not a request for a new
escape hatch. If a needed side effect cannot be expressed as
a command, the missing command is the work.

## View is a pure function of model

`view(model)` returns the UI tree from the model. It does not
access process state, does not call out to other actors, does
not read mutable globals, does not perform I/O. The runtime
calls `view` after every update; it must be deterministic
from the model alone.

Pure-Gleam composite widgets defined via `plushie/widget`
that take internal state are the exception, but the state is
owned by the runtime and threaded into the widget's `view`
function deterministically; the widget body is still pure
with respect to the inputs it receives.

The top level of the view must be a list of `window` nodes.
The runtime detects window nodes and emits the appropriate
open/close/update wire ops. A non-window node at the top
level surfaces as a renderer diagnostic.

## Subscriptions are declarative

`subscribe(model) -> List(Subscription)` returns the list of
active subscriptions. The runtime diffs the list each cycle
using a stable key per subscription: same key means kept
alive; new keys trigger a subscribe message to the renderer;
removed keys trigger an unsubscribe.

Subscription kinds (`plushie/subscription`):

- `Every(interval_ms, tag)`: timer that fires every interval,
  delivering a `TimerTick` event with the tag.
- `Renderer(kind, max_rate, window_id)`: renderer-side event
  source (key, mouse, window events, etc.). The renderer
  filters and delivers matching events; `max_rate` bounds
  high-frequency sources; `window_id` scopes to a single
  window.

Subscription failures surface as events through the normal
dispatch path; they do not crash the runtime.

## Widget event flow

Events from the renderer arrive at the runtime, flow through
custom-widget event handlers in the scope chain, and reach
`update`:

1. Event arrives from bridge (BEAM) or WASM transport (JS).
2. Runtime walks the widget handler scope chain (innermost
   first) for handlers registered for this event family/id.
3. Each handler returns one of:
   - `Ignored` - handler did not capture; continue to next.
   - `Consumed` - captured, no output; stop the chain.
   - `Emit(kind, data)` - captured, replace the event with
     a `CustomWidget` event carrying the new kind/data;
     continue with the new event up the chain.
   - Variants that also persist widget state.
4. If the chain returns an event (or the original was not
   captured), it reaches `on_event` (custom-msg apps) or
   directly `update` (simple apps).

Canvas-internal events that no handler captures are auto-
consumed by the runtime; they never reach `update`. View-
only widgets (no events, no state) are transparent; events
pass through.

This matches iced's captured/ignored model on the renderer
side and is part of the cross-SDK shape.

## Scoped IDs

Wire IDs use the canonical format `window#scope/path/id`:

- `"main#form/email"` is widget `email` inside scope `form`
  inside window `main`.
- `"main"` is the window itself.

Events on the runtime side carry split fields via
`EventTarget`: `id` (local), `scope` (reversed ancestor
chain, immediate parent first), `window_id` (window). This
shape is what user pattern matching operates on:

```gleam
case event {
  Widget(Click(target: EventTarget(id: "save", scope: ["form", ..], ..))) -> ...
  Widget(Click(target: EventTarget(id: "done", scope: [item_id, ..], ..))) -> ...
  _ -> ...
}
```

Commands use forward-order path strings; helper functions in
`plushie/command` build the canonical form. Auto-ID
containers (no explicit ID) do not create a scope. Window
nodes do not create a scope; they are the window component
of the wire ID. `"/"` is forbidden in user-provided IDs.

## What these invariants buy

- **Tests can be written.** A pure `update` plus pure data
  commands plus a pure `view` is exercisable through the
  integration spine without elaborate setup. The user never
  needs to "wait for an effect" in their tests; they assert
  on what was returned.
- **The runtime can revert on panic.** Because `update` is a
  pure function that returns the new model, the runtime can
  keep the previous model and recover by reverting on a
  caught panic. Same for `view`: a previous tree is
  preserved and used as the fallback.
- **The bridge can re-sync after a renderer crash.** The
  current model is enough to regenerate the full tree and
  re-establish state. The renderer holds no app state the
  runtime cannot reconstruct.
- **Multi-target parity is meaningful.** The pure layer
  (widgets, events, commands, tree) compiles unchanged on
  both BEAM and JS; the user's `App(model, msg)` runs on
  both targets without modification. The Elm contract is
  what makes that possible.
- **Cross-SDK parity is meaningful.** "What does
  plushie-elixir do here" has a precise answer; plushie-
  gleam implements the same contract.
