# App behaviour

`toddy/app` defines the application structure. It follows the
Elm architecture: model, update, view.

## Constructors

The simplest app uses `app.simple`, where `update` receives `Event` directly:

```gleam
import toddy/app
import toddy/command
import toddy/event.{type Event}
import toddy/node.{type Node}

let my_app = app.simple(init, update, view)
```

For apps that need a custom message type, use `app.application` with an
`on_event` mapper:

```gleam
let my_app = app.application(init, update, view, on_event)
```

Both have `_with_opts` variants (`simple_with_opts`, `application_with_opts`)
where `init` receives `Dynamic` app options from the start call.

Optional callbacks are added via pipeline:

```gleam
let my_app =
  app.simple(init, update, view)
  |> app.with_subscriptions(subscribe)
  |> app.with_settings(settings)
  |> app.with_window_config(window_config)
  |> app.with_on_renderer_exit(handle_exit)
```

## Functions

```gleam
init: fn() -> #(model, Command(Event))
update: fn(model, Event) -> #(model, Command(Event))
view: fn(model) -> Node

// Optional (set via pipeline):
subscribe: fn(model) -> List(Subscription)
settings: fn() -> Settings
window_config: fn(model) -> Dict(String, PropValue)
on_renderer_exit: fn(model, Dynamic) -> model
```

### init

Returns the initial model and command tuple. Called once when the
runtime starts.

```gleam
fn init() {
  #(
    Model(todos: [], input: "", filter: All),
    command.none(),
  )
}

// Or with a command:
fn init() {
  let model = Model(todos: [], loading: True)
  #(model, command.async(load_todos_from_disk, "todos_loaded"))
}
```

The model can be any type, but custom types work best. The runtime does not
inspect or modify the model -- it is fully owned by the app.

When using `simple_with_opts` or `application_with_opts`, `init` receives
a `Dynamic` value passed through from the start call's `app_opts` field.

### update

Receives the current model and an event, returns a tuple of the next model
and a command. Always returns `#(model, command)` -- use `command.none()`
when no side effects are needed.

```gleam
import toddy/event.{WidgetClick, WidgetInput, WidgetSubmit}

fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "add_todo", ..) -> {
      let todo = Todo(id: next_id(model), text: model.input, done: False)
      #(
        Model(..model, todos: [todo, ..model.todos], input: ""),
        command.none(),
      )
    }

    WidgetInput(id: "todo_field", value:, ..) ->
      #(Model(..model, input: value), command.none())

    // Returning commands:
    WidgetSubmit(id: "todo_field", ..) -> {
      let todo = Todo(id: next_id(model), text: model.input, done: False)
      #(
        Model(..model, todos: [todo, ..model.todos], input: ""),
        command.focus("todo_field"),
      )
    }

    _ -> #(model, command.none())
  }
}
```

See [commands.md](commands.md) for the full command API.

Events are constructors of the `Event` type in `toddy/event`. See
[events.md](events.md) for the full event taxonomy. Common families:

- `WidgetClick(id: id, ..)` -- button press
- `WidgetInput(id: id, value: val, ..)` -- text input change
- `WidgetSelect(id: id, value: val, ..)` -- selection change
- `WidgetToggle(id: id, value: val, ..)` -- checkbox/toggler change
- `WidgetSubmit(id: id, value: val, ..)` -- form field submission
- `KeyPress(key: key, modifiers: mods, ..)` -- keyboard event (via subscription)
- `KeyRelease(key: key, ..)` -- keyboard release (via subscription)
- `WindowCloseRequested(window_id: id)` -- window close requested
- `WindowResized(window_id: id, width: w, height: h)` -- window resized
- `CanvasPress(id: id, x: x, y: y, button: btn, ..)` -- canvas interaction
- `SensorResize(id: id, width: w, height: h, ..)` -- sensor size change
- `PaneClicked(id: id, pane: pane, ..)` -- pane grid click

### view

Receives the current model, returns a UI tree.

```gleam
import toddy/ui
import toddy/prop/padding

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(8)], [
      ui.row("input-row", [ui.spacing(8)], [
        ui.text_input("todo_field", model.input, [
          ui.placeholder("What needs doing?"),
          ui.on_submit(True),
        ]),
        ui.button_("add_todo", "Add"),
      ]),
      ..list.index_map(filtered_todos(model), fn(todo, idx) {
        ui.row("todo-" <> int.to_string(idx), [ui.spacing(8)], [
          ui.checkbox("toggle-" <> int.to_string(idx), todo.done, []),
          ui.text_("text-" <> int.to_string(idx), todo.text),
        ])
      })
    ]),
  ])
}
```

The view function is called after every update. It must be a pure function
of the model. The runtime diffs the returned tree against the previous one
and sends only the changes to the renderer.

UI trees are `Node` values. The `toddy/ui` module provides builder functions
for composition. The `toddy/widget/*.gleam` modules offer typed builders with
chainable setters for more control.

## Lifecycle

```
toddy.start(app, opts)
  |
  v
init() -> #(model, commands)
  |
  v
subscribe(model) -> active subscriptions
  |
  v
view(model) -> initial tree -> send snapshot to renderer
  |
  v
[event from renderer / subscription / command result]
  |
  v
update(model, event) -> #(model, commands)
  |
  v
subscribe(model) -> diff subscriptions (start/stop as needed)
  |
  v
view(model) -> next tree -> diff -> send patch to renderer
  |
  v
[repeat from event]
```

### subscribe (optional)

Returns a list of active subscriptions based on the current model. Called
after every `update`. The runtime diffs the list and starts/stops
subscriptions automatically. Set via `app.with_subscriptions`.

```gleam
import toddy/subscription

fn subscribe(model: Model) -> List(subscription.Subscription) {
  let subs = [subscription.on_key_press("key_event")]

  case model.auto_refresh {
    True -> [subscription.every(5000, "refresh"), ..subs]
    False -> subs
  }
}
```

Default: `[]` (no subscriptions). See [commands.md](commands.md) for the
full subscription API.

### on_renderer_exit (optional)

Called when the renderer process exits unexpectedly. Return the model to
use when the renderer restarts. Default: return model unchanged.
Set via `app.with_on_renderer_exit`.

```gleam
fn handle_renderer_exit(model: Model, _reason: Dynamic) -> Model {
  Model(..model, status: RendererRestarting)
}
```

### window_config (optional)

Called when windows are opened, including at startup and after renderer
restart. Returns a dict of window property overrides.
Set via `app.with_window_config`.

```gleam
import gleam/dict

fn window_config(_model: Model) -> Dict(String, PropValue) {
  dict.new()
}
```

### settings (optional)

Called once at startup to provide application-level settings to the
renderer. Returns a `Settings` record. Set via `app.with_settings`.

```gleam
import toddy/app.{Settings}
import gleam/option.{None, Some}

fn settings() -> Settings {
  Settings(
    ..app.default_settings(),
    default_text_size: 16.0,
    antialiasing: True,
    fonts: ["priv/fonts/Inter.ttf"],
  )
}
```

`Settings` fields:

- `default_font` -- `Option(PropValue)`. Font specification. Default: `None`.
- `default_text_size` -- `Float`. Pixels. Default: `16.0`.
- `antialiasing` -- `Bool`. Default: `True`.
- `fonts` -- `List(String)`. Font file paths to load. Default: `[]`.
- `vsync` -- `Bool`. Vertical sync. Default: `True`.
- `scale_factor` -- `Float`. Global UI scale (1.0 = 100%). Default: `1.0`.
- `theme` -- `Option(Theme)`. `None` follows the system theme. Default: `None`.
- `default_event_rate` -- `Option(Int)`. Max events/sec for coalescable sources.
  Default: `None` (unlimited).

To follow the OS light/dark preference automatically, set the window
`theme` prop to `"system"`. The renderer detects the current OS theme
and applies the matching built-in light or dark theme.

Default: `app.default_settings()` (renderer uses its own defaults).

## Starting the runtime

```gleam
import gleam/erlang/process
import toddy
import toddy/app

pub fn main() {
  let my_app = app.simple(init, update, view)
  let assert Ok(_) = toddy.start(my_app, toddy.default_start_opts())
  process.sleep_forever()
}

// With custom options:
pub fn main() {
  let my_app = app.simple(init, update, view)
  let opts = toddy.StartOpts(
    ..toddy.default_start_opts(),
    binary_path: option.Some("/path/to/toddy"),
  )
  let assert Ok(_) = toddy.start(my_app, opts)
  process.sleep_forever()
}
```

## Testing

Apps can be tested without a renderer:

```gleam
import gleeunit/should
import toddy/event.{WidgetInput, WidgetClick}
import toddy/command

pub fn adding_a_todo_test() {
  let #(model, _) = init()
  let #(model, _) = update(model, WidgetInput(
    id: "todo_field", scope: [], value: "Buy milk",
  ))
  let #(model, _) = update(model, WidgetClick(id: "add_todo", scope: []))

  should.equal(model.input, "")
  should.be_true(list.any(model.todos, fn(t) { t.text == "Buy milk" }))
}

pub fn view_renders_todo_list_test() {
  let model = Model(
    todos: [Todo(id: 1, text: "Buy milk", done: False)],
    input: "",
    filter: All,
  )
  let tree = view(model)
  // tree is a Node value -- inspect or search it directly
}
```

Since `update` is a pure function and `view` returns `Node` values, no special
test infrastructure is needed. The renderer is not involved.

## Multi-window

Toddy supports multiple windows driven declaratively from `view`. Windows
are nodes in the tree -- if a window node is present, the window is open; if
it disappears, the window closes.

### Returning multiple windows

`view` returns a window node (or a list-like structure for multi-window apps).
Use conditional logic in the view to open/close secondary windows:

```gleam
fn view(model: Model) -> Node {
  let main =
    ui.window("main", [ui.title("My App")], [
      main_content(model),
    ])

  case model.inspector_open {
    True ->
      ui.window_group([
        main,
        ui.window("inspector", [ui.title("Inspector"), ui.size(400.0, 600.0)], [
          inspector_panel(model),
        ]),
      ])
    False -> main
  }
}
```

Single-window apps can return a single window node directly. The runtime
normalizes both forms internally.

### Window identity

Each window node has an `id` (like all nodes). The renderer uses this ID
to track which OS window corresponds to which tree node:

- **New ID appears** -- renderer opens a new OS window.
- **Existing ID present** -- renderer updates that window's content.
- **ID disappears** -- renderer closes that OS window.

Window IDs must be stable strings. Do not generate random IDs per render
or the renderer will close and reopen the window on every update.

### Window properties

```gleam
ui.window("main", [
  ui.title("My App"),
  ui.size(800.0, 600.0),
  ui.min_size(400.0, 300.0),
  ui.max_size(1920.0, 1080.0),
  ui.position(100.0, 100.0),
  ui.resizable(True),
  ui.closeable(True),
  ui.minimizable(True),
  ui.decorations(True),
  ui.transparent(False),
  ui.visible(True),
  ui.theme_attr("dark"),
  ui.level("normal"),
  ui.window_scale_factor(1.5),
], [
  content(model),
])
```

Properties are set when the window first appears. To change properties
after creation, use window commands:

```gleam
fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "go_fullscreen", ..) ->
      #(model, command.SetWindowMode(window_id: "main", mode: "fullscreen"))
    _ -> #(model, command.none())
  }
}
```

### Window events

Window events include the window ID so your app knows which window they
came from:

```gleam
fn update(model: Model, event: Event) {
  case event {
    WindowCloseRequested(window_id: "inspector") ->
      #(Model(..model, inspector_open: False), command.none())

    WindowCloseRequested(window_id: "main") ->
      case model.unsaved_changes {
        True -> #(Model(..model, confirm_exit: True), command.none())
        False -> #(model, command.close_window("main"))
      }

    WindowResized(window_id: "main", width:, height:) ->
      #(Model(..model, window_width: width, window_height: height), command.none())

    WindowFocused(window_id:) ->
      #(Model(..model, active_window: window_id), command.none())

    _ -> #(model, command.none())
  }
}
```

### Window close behaviour

By default, when the user clicks the close button on a window, the
renderer sends a `WindowCloseRequested(window_id: id)` event instead
of closing immediately. Your app decides what to do:

```gleam
case event {
  // Let it close (remove it from view):
  WindowCloseRequested(window_id: "settings") ->
    #(Model(..model, settings_open: False), command.none())

  // Block the close:
  WindowCloseRequested(window_id: "main") ->
    #(Model(..model, show_save_dialog: True), command.none())
  _ -> #(model, command.none())
}
```

If `WindowCloseRequested` is not handled (falls through to the catch-all), the
window stays open. This prevents accidental closes. To close a window
programmatically, remove it from the tree (return `view` without it) or
use `command.close_window(id)`.

### Opening windows declaratively

Windows are opened by adding window nodes to the tree returned by
`view`. There is no `open_window` command. To open a new window, set a
flag in your model and include the window node conditionally:

```gleam
fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "open_settings", ..) ->
      #(Model(..model, settings_open: True), command.none())
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  let main =
    ui.window("main", [ui.title("My App")], [
      main_content(model),
    ])

  case model.settings_open {
    True ->
      ui.window_group([
        main,
        ui.window("settings", [ui.title("Settings"), ui.size(500.0, 400.0)], [
          settings_panel(model),
        ]),
      ])
    False -> main
  }
}
```

### Primary window

The first window in the tree is the primary window.
When the primary window is closed, the runtime exits (unless
`on_renderer_exit` is set to prevent it).

Secondary windows can be opened and closed freely without affecting the
runtime lifecycle.

### Focus and active window

The renderer tracks which window has OS focus. Window focus/unfocus events
are delivered as:

```gleam
WindowFocused(window_id: window_id)
WindowUnfocused(window_id: window_id)
```

The app can use these to adjust behaviour (e.g., pause animations in
unfocused windows, track the active window for keyboard shortcuts).

### Example: dialog window

```gleam
fn view(model: Model) -> Node {
  let main =
    ui.window("main", [ui.title("App")], [
      main_content(model),
    ])

  case model.confirm_dialog {
    True ->
      ui.window_group([
        main,
        ui.window("confirm", [
          ui.title("Confirm"),
          ui.size(300.0, 150.0),
          ui.resizable(False),
          ui.level("always_on_top"),
        ], [
          ui.column("dialog", [ui.padding(padding.all(16.0)), ui.spacing(12)], [
            ui.text_("prompt", "Are you sure?"),
            ui.row("buttons", [ui.spacing(8)], [
              ui.button_("confirm_yes", "Yes"),
              ui.button_("confirm_no", "No"),
            ]),
          ]),
        ]),
      ])
    False -> main
  }
}
```


## How props reach the renderer

Values returned by `view` go through several transformation stages
before reaching the wire. Understanding this pipeline helps when
debugging unexpected behaviour or writing custom extensions.

1. **Widget builders** (`toddy/ui` functions, `toddy/widget/*.gleam` builders)
   return `Node` values with typed Gleam values -- custom types, strings,
   floats. Prop values are encoded to `PropValue` at `build()` time.

2. **`toddy/tree.normalize`** walks the tree and applies scoped ID
   prefixing and a11y reference resolution. By this stage, all prop
   values are already wire-compatible `PropValue` primitives.

3. **Protocol encoding** (`toddy/protocol/encode`) serializes the
   `PropValue` tree to wire bytes using gleam_json (JSONL mode) or
   glepack (MessagePack mode).

Each stage has a single responsibility. Widget builders handle value
encoding, normalization handles scoped IDs, and protocol encoding handles
serialization format.

See [running.md](running.md) for more detail on the encoding pipeline
and transport modes.

## Renderer limits

The renderer enforces hard limits on various resources. Exceeding them
results in rejection, truncation, or clamping (depending on the
resource). Design your app to stay within these bounds.

| Resource | Limit | Behavior when exceeded |
|---|---|---|
| Font data (`load_font`) | 16 MiB decoded | Rejected with warning |
| Runtime font loads | 256 per process | Rejected with warning |
| Image handles | 4096 | Error response |
| Total image bytes | 1 GiB | Error response |
| Markdown content | 1 MiB | Truncated at UTF-8 boundary with warning |
| Text editor content | 10 MiB | Truncated at UTF-8 boundary with warning |
| Window size | 1..16384 px | Clamped with warning |
| Window position | -32768..32768 | Clamped with warning |
| Tree depth | 256 levels | Rendering/caching stops descending |

Image and font limits are per-process and survive Reset. Content limits
truncate at a UTF-8 character boundary.
