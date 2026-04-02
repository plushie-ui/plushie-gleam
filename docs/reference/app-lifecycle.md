# App Lifecycle

A Plushie app implements the Elm architecture: `init` produces a model,
`update` handles events, `view` returns a UI tree.

## App constructors

### app.simple

For apps where the message type is `Event` directly:

```gleam
import plushie/app

let my_app = app.simple(init, update, view)
```

| Callback | Signature | Required |
|---|---|---|
| `init` | `fn(Dynamic) -> model` | yes |
| `update` | `fn(model, Event) -> model` | yes |
| `view` | `fn(model) -> Node` | yes |

`update` can return `model` or `#(model, Command(Event))`.

### app.application

For apps with custom message types:

```gleam
let my_app = app.application(init, update, view, on_event)
```

The `on_event` callback maps `Event -> msg` at the dispatch boundary.

## Optional callbacks

| Callback | Purpose |
|---|---|
| `subscribe` | Return active subscription specs based on model |
| `settings` | Renderer-level defaults (font, theme, event rate) |

Set these via `app.with_subscribe` and `app.with_settings`.

## Startup sequence

1. Runtime calls `init`, producing initial model and optional commands
2. Settings sent to renderer
3. `view` called, full snapshot sent to renderer
4. Init commands execute (after the first snapshot)
5. Subscriptions synced via `subscribe`

## Update cycle

1. `update` called with event and current model
2. Commands executed
3. `view` called, tree diffed, patch sent if changed
4. `subscribe` called, subscriptions diffed

## Error recovery

If `update` panics, the model reverts to its pre-exception state. The
UI stays on the previous successful render.

## Renderer crash

The bridge manages renderer restart with exponential backoff (100ms base,
5s cap, 5 max failures). On successful restart: settings re-sent, view
re-rendered as fresh snapshot, subscriptions re-synced. The app's model
is preserved across restarts. Clean exit (status 0) stops the runtime.

## Process model

The runtime is a plain linked process (not an OTP actor). It spawns
internally and owns all state. Subjects are created inside the spawned
process (critical for correct Gleam message delivery). The bridge actor
manages the Erlang Port to the Rust binary.

## Daemon mode

Pass `Daemon(True)` to `plushie.start`. The app keeps running after the
last window closes. `AllWindowsClosed` arrives in `update`, and you can
open new windows by returning them from `view`.

## See also

- `plushie/app` - App type, Settings, constructors
- `plushie/runtime` - update loop internals
- `plushie/bridge` - wire protocol, transport modes, restart logic
- [Configuration reference](configuration.md)
