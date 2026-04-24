# App Lifecycle

A Plushie app implements the [Elm architecture](https://guide.elm-lang.org/architecture/):
`init` produces a model, `update` handles messages, `view` returns a
list of top-level windows. The runtime drives the loop, the bridge
manages the renderer process, and an OTP supervisor ties them
together.

The `App(model, msg)` type and its constructors live in
`plushie/app`. Lifecycle entry points (`start`, `stop`, `wait`) and
runtime state queries live in `plushie`.

## The App value

`plushie/app.App(model, msg)` is an opaque record bundling all
callbacks. It is parameterised over both the app's model type and
its message type. Construct it with one of the smart constructors:

| Constructor | Signature | Message type |
|---|---|---|
| `app.simple(init, update, view)` | `fn() -> #(model, Command(Event))`, `fn(model, Event) -> #(model, Command(Event))`, `fn(model) -> List(Node)` | `Event` |
| `app.application(init, update, view, on_event)` | as above with `fn() -> #(model, Command(msg))`, `fn(model, msg) -> #(model, Command(msg))`, plus `fn(Event) -> msg` | custom `msg` |
| `app.simple_with_opts(init, update, view)` | `init` receives the raw `app_opts: Dynamic` from `StartOpts` | `Event` |
| `app.application_with_opts(init, update, view, on_event)` | same, with a custom `msg` type | custom `msg` |

`app.simple` is the common case: the runtime hands renderer events
straight to `update`. `app.application` inserts an `on_event`
mapper that converts each `Event` to the app's own message type, so
`update` sees typed domain messages plus mapped events.

Optional callbacks are added with chainable setters:

| Setter | Purpose |
|---|---|
| `app.with_subscriptions(app, subscribe)` | `fn(model) -> List(Subscription)` |
| `app.with_settings(app, settings)` | `fn() -> app.Settings` |
| `app.with_window_config(app, window_config)` | `fn(model) -> Dict(String, PropValue)` |
| `app.with_on_renderer_exit(app, handler)` | `fn(model, RendererExit) -> model` |

Unset optionals default to no-op implementations: `subscribe`
returns `[]`, `settings` returns `app.default_settings()`,
`window_config` returns `dict.new()`, and no renderer exit handler
runs.

## Callbacks

### init

```gleam
fn init() -> #(model, Command(msg))
```

Called once when `plushie.start` runs. Returns the initial model
paired with an initial command (`command.none()` when no side
effect is needed). Commands returned from `init` run after the
initial snapshot is sent to the renderer, so the first paint is
never blocked by command execution.

The `_with_opts` constructors use
`fn(app_opts: Dynamic) -> #(model, Command(msg))` instead. Pass the
value via `StartOpts.app_opts`; the default is `dynamic.nil()`.

### update

```gleam
fn update(model, msg) -> #(model, Command(msg))
```

Called for every message. Returns the next model and a command.
Use a catch-all `_ -> #(model, command.none())` as the last `case`
arm. Unhandled `case` branches cause an `update` panic; the runtime
catches the exception, reverts to the pre-dispatch model, and logs
the error (see [Panic recovery](#panic-recovery)), but the noise is
avoidable.

### view

```gleam
fn view(model) -> List(Node)
```

Called after every successful update. Returns a list of top-level
`window` nodes. Return `[]` to render an empty tree, a single
`[window.build(...)]` for a single window, or multiple windows for
a multi-window app.

`view` runs unconditionally after a successful update, even when
the model is structurally unchanged. Wire traffic is avoided at the
diff stage: if the normalised tree is identical to the previous
one, no patch is sent. When `update` or `view` raises, the previous
tree is preserved.

### subscribe

```gleam
fn subscribe(model) -> List(Subscription)
```

Called after each update cycle. The runtime diffs the returned
list against the currently active set, starting new subscriptions
and stopping removed ones. See the
[Subscriptions reference](subscriptions.md) for the full catalog
and the [Events reference](events.md) for event shapes.

### settings

```gleam
fn settings() -> app.Settings
```

Called once on startup and again after every renderer restart. The
returned `Settings` record is serialised and sent to the renderer
before any snapshot. Fields include `antialiasing`,
`default_text_size`, `theme`, `fonts`, `vsync`, `scale_factor`,
`default_font`, `default_event_rate`, `validate_props`,
`widget_config`, and `required_widgets`. Use
`app.default_settings()` as a base and override only what you need.

See the [Configuration reference](configuration.md) for the key
table and environment overrides.

### window_config

```gleam
fn window_config(model) -> Dict(String, PropValue)
```

Called when new windows appear in the view tree (including after a
renderer restart). Returns a dict of default per-window props
merged into each window before the per-window opts from the view
tree are applied. Useful for shared defaults across windows (title
prefix, theme, size constraints). See
[Windows and Layout](windows-and-layout.md) for the window opt
catalog.

### on_renderer_exit

```gleam
fn on_renderer_exit(model, RendererExit) -> model
```

Called when the renderer process exits before the runtime attempts
a restart. The handler receives the current model and a
`plushie/renderer_exit.RendererExit` record:

| Field | Type | Description |
|---|---|---|
| `reason` | `RendererExitType` | `Crash`, `ConnectionLost`, `Shutdown`, or `HeartbeatTimeout` |
| `message` | `String` | Human-readable description |
| `details` | `Option(Int)` | Exit status code when available |

Return a potentially adjusted model. Use this to reset state tied
to renderer-side resources (scroll offsets, animation progress,
in-flight uploads). If the handler itself raises, the model is
preserved and a `System(RecoveryFailed(kind, error, renderer_exit))`
event is dispatched through `update`.

## Startup sequence

`plushie.start(app, opts)` builds an OTP `rest_for_one` supervisor
with `auto_shutdown: AnySignificant`. Children start in this
order:

1. **Bridge** (`plushie/bridge`). Transient, significant. Opens the
   renderer port (`Spawn`), attaches to stdio, or wires up an
   external iostream adapter.
2. **Runtime** (`plushie/runtime`). Transient, significant. Owns
   the app model, runs the Elm loop, and talks to the bridge.
3. **DevServer** (`plushie/dev_server`). Transient, added only
   when `StartOpts.dev` is `True`.

On startup the runtime:

1. Calls `init(app_opts)` to produce the initial model and any
   init commands.
2. Calls `settings()` and sends the settings message to the
   renderer. A crashing `settings` callback is caught and
   `app.default_settings()` is used instead.
3. Renders the initial view, normalises it (applying scoped IDs
   and resolving accessibility refs), and sends a full snapshot
   to the renderer.
4. Derives the widget handler registry from the tree.
5. Executes the init commands.
6. Syncs subscriptions via `subscribe(model)`.
7. Detects window nodes in the tree, calls `window_config(model)`
   for each, merges per-window props, and sends open operations.

`plushie.start` returns an `Instance(model)` parameterised over
the same model type as `App(model, msg)`, so later queries like
`plushie.get_model(instance)` return the typed model directly
without a `Dynamic` coercion at the call site.

## Update cycle

Each inbound event goes through a fixed pipeline:

1. **Widget handlers.** The runtime walks the scope chain
   innermost-first so custom widgets can emit, transform, consume,
   or ignore the event.
2. **Event mapping.** For `app.simple` apps the event is the
   message. For `app.application` apps the `on_event` mapper
   produces the app's `msg`.
3. **`update(model, msg)`** produces a new model and a command.
4. **Command execution.** Commands run before the next view:
   synchronous commands are applied immediately, async and stream
   commands spawn tagged tasks, effect commands are forwarded to
   the renderer, and window / system commands are dispatched. See
   [Commands reference](commands.md).
5. **`view(new_model)`** produces a new tree.
6. **Diff and patch.** The new normalised tree is compared against
   the previous one. A patch is sent only when they differ.
7. **Subscription sync.** The new subscription list is diffed
   against the active set.
8. **Window sync.** New, removed, and changed windows trigger
   open, close, and update operations on the renderer. Window IDs
   must be stable strings; changing an ID reads as close plus
   open.

Coalescable events (`Widget(Move)`, `Widget(Resize)`) are buffered
and flushed by a zero-delay timer before the next non-coalescable
event, so rapid pointer traffic collapses to the latest value per
source without reordering across event families.

## Panic recovery

`update` and `view` run inside `platform.try_call`. When either
raises, the runtime logs the failure and preserves earlier state:

- **`update` panic.** The pre-dispatch model is kept. The error
  counter on `HealthStatus.errors` increments. The first ten
  consecutive `update` errors log at warning level; further
  errors continue to count but stop logging to avoid flooding.
  The counter resets on the next successful update.
- **`view` panic.** Commands already applied for the triggering
  message are kept; the model and tree revert to their pre-view
  state. `HealthStatus.consecutive_view_errors` increments. On
  the fifth consecutive view failure the runtime logs a "UI is
  stale" warning and injects a frozen-UI indicator into the
  rendered tree. The counter resets on the next successful
  render.

Query the counters via `plushie.get_health(instance)`. A helper
`plushie.is_view_desynced(instance)` returns `True` whenever
`consecutive_view_errors > 0`.

The runtime additionally caps synchronous `command.dispatch`
chains at `runtime_core.dispatch_depth_limit` (100). Chains that
exceed the cap are dropped with a typed
`Error(Diagnostic(DispatchLoopExceeded))`.

## Bridge restart

The bridge supports automatic restart only for the `Spawn`
transport. `Stdio` and `Iostream` exit with the renderer.

When a `Spawn` renderer crashes or heartbeat-times out, the bridge
restarts it with exponential backoff:
`min(100ms * 2^attempt, 5000ms)` up to five consecutive failures.
On successful reconnection the counter resets. If the cap is
exceeded, the bridge stops and the supervisor tears down the app.

On each successful restart the runtime:

1. Calls `on_renderer_exit(model, RendererExit)` if one is
   registered, giving the app a chance to adjust the model.
2. Re-sends the settings message (via `settings()` called again).
3. Re-renders the view with a fresh diff baseline, producing a
   full snapshot rather than a patch.
4. Re-derives the widget handler registry.
5. Re-syncs subscriptions against the fresh renderer.
6. Re-opens every detected window (via `window_config` plus the
   per-window tree props).
7. Fails any in-flight effects and pending `interact` replies
   with `"renderer_restarted"`.
8. Discards stale coalesced events.

App-side state (the model, async task state tracked by the
runtime) is preserved. Renderer-side state (scroll offsets, cursor
positions, text editor state, registered images) resets because
the new renderer process has no memory of the old one.

Clean renderer exit (status 0, `Shutdown`) does not trigger a
restart; the runtime stops and the supervisor shuts down.

## Exit semantics

Plushie receives `System(AllWindowsClosed)` from the renderer
whenever the last window closes. The runtime's reaction depends on
`StartOpts.daemon`:

| Mode | After `AllWindowsClosed` |
|---|---|
| Normal (`daemon: False`, default) | `update` runs on the event, then the runtime stops. `auto_shutdown: AnySignificant` tears down the rest of the supervision tree. |
| Daemon (`daemon: True`) | `update` runs, the runtime continues. Re-open windows by returning them from `view` on a later update. |

Whether a specific window closing counts toward
"all windows closed" is controlled by the window opt
`window.ExitOnCloseRequest(Bool)`. Setting it to `False` on a
secondary window lets the window close without flagging the app
for exit. See [Windows and Layout](windows-and-layout.md) for the
full opt list.

## Runtime state queries

The runtime exposes synchronous queries on a running
`Instance(model)`:

| Function | Returns | Description |
|---|---|---|
| `plushie.get_model(instance)` | `Result(model, Nil)` | Current app model, typed via the `Instance(model)` parameter |
| `plushie.get_tree(instance)` | `Result(Option(Node), Nil)` | Current normalised view tree |
| `plushie.get_focused(instance)` | `Result(Option(String), Nil)` | ID of the focused widget |
| `plushie.get_health(instance)` | `Result(runtime.HealthStatus, Nil)` | Error counters and view desync flag |
| `plushie.is_view_desynced(instance)` | `Result(Bool, Nil)` | `True` when consecutive view errors are non-zero |
| `plushie.get_prop_warnings(instance)` | `Result(List(runtime.PropWarning), Nil)` | Accumulated prop validation warnings, cleared after retrieval |
| `plushie.dispatch_event(instance, event)` | `Nil` | Inject an event into the runtime's message loop |
| `plushie.await_async(instance, tag, timeout)` | `Result(Nil, Nil)` | Block until the tagged async task completes |
| `plushie.wait(instance)` | `Nil` | Block until the supervisor exits |
| `plushie.stop(instance)` | `Nil` | Send the supervisor a shutdown exit |

`HealthStatus` fields: `errors`, `consecutive_view_errors`,
`prop_warning_count`, `view_desynced`.

`dispatch_event` bypasses the bridge and the renderer: the event
enters the widget handler chain and reaches `update` as if it
came from the renderer. Useful for integration tests and for
custom integrations that need to feed events into the runtime
without going through the wire.

## Dev mode and hot reload

Setting `StartOpts.dev: True` adds a `DevServer` child to the
supervision tree. The dev server watches `src/` for `.gleam`
changes, runs `gleam build` as a subprocess, hot-loads changed
BEAM modules through `code:purge` plus `code:load_file`, and
sends a `ForceRerender` message to the runtime.

`ForceRerender` re-runs `view(model)` with the freshly loaded code
without touching the model or any in-flight state. Subscriptions
stay active, commands in flight are unaffected, widget registries
update as part of the rerender. A build failure is logged and the
previous successful tree remains rendered.

## See also

- [Commands reference](commands.md) - the command constructors
  returned from `init` and `update`
- [Events reference](events.md) - the event shapes delivered to
  `update`
- [Subscriptions reference](subscriptions.md) - declarative event
  sources returned from `subscribe`
- [Windows and Layout](windows-and-layout.md) - window opts and
  the view return shape
- [Configuration reference](configuration.md) - `Settings` keys
  and environment overrides
