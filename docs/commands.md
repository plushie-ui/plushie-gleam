# Commands and subscriptions

Iced has two mechanisms beyond the basic update/view cycle: `Task` (async
commands from update) and `Subscription` (ongoing event sources). Toddy
provides Gleam equivalents for both.

## Commands

Sometimes `update` needs to do more than return a new model. It might
need to focus a text input, start an HTTP request, open a new window, or
schedule a delayed event. These are commands.

### Returning commands from update

`update` always returns a `#(model, Command(msg))` tuple. Use
`command.none()` when no side effects are needed:

```gleam
import toddy/command
import toddy/event.{type Event, WidgetClick, AsyncResult}

fn update(model: Model, event: Event) {
  case event {
    // No commands -- return none:
    WidgetClick(id: "simple", ..) ->
      #(model, command.none())

    // With commands:
    WidgetClick(id: "save", ..) ->
      #(model, command.async(fn() { save_to_disk(model) }, "save_result"))

    AsyncResult(tag: "save_result", result: Ok(_)) ->
      #(Model(..model, saved: True), command.none())

    AsyncResult(tag: "save_result", result: Error(_)) ->
      #(Model(..model, error: "save failed"), command.none())

    _ -> #(model, command.none())
  }
}
```

### Available commands

#### Async work

```gleam
// Run a function asynchronously. Result is delivered as an AsyncResult event.
command.async(work, tag)

// work: fn() -> Dynamic
// tag: String
// Delivers: AsyncResult(tag: tag, result: Ok(value)) or
//           AsyncResult(tag: tag, result: Error(reason))
```

```gleam
fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "fetch", ..) -> {
      let cmd = command.async(fn() {
        // In a real app: HTTP request, file read, etc.
        dynamic.string("fetched data")
      }, "data_fetched")
      #(Model(..model, loading: True), cmd)
    }

    AsyncResult(tag: "data_fetched", result: Ok(value)) -> {
      let data = case decode.run(value, decode.string) {
        Ok(s) -> s
        Error(_) -> "unexpected"
      }
      #(Model(..model, loading: False, data:), command.none())
    }

    _ -> #(model, command.none())
  }
}
```

#### Streaming async work

`command.stream` spawns a process that can emit multiple values over time.
The function receives an `emit` callback; each call to `emit` delivers a
`StreamValue(tag: tag, value: value)` event through the normal update cycle.
The function's final return value is delivered as
`AsyncResult(tag: tag, result: Ok(value))`.

```gleam
command.stream(work, tag)

// work: fn(fn(Dynamic) -> Nil) -> Dynamic
// tag: String
// Each emit call dispatches StreamValue(tag: tag, value: value)
// Final return dispatches AsyncResult(tag: tag, result: Ok(value))
```

```gleam
fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "import", ..) -> {
      let cmd = command.stream(fn(emit) {
        // Process rows, emitting progress along the way
        let rows = process_csv("big.csv", fn(n) {
          emit(dynamic.int(n))
        })
        dynamic.list(rows, dynamic.string)
      }, "file_import")
      #(Model(..model, importing: True), cmd)
    }

    StreamValue(tag: "file_import", value:) -> {
      let n = case decode.run(value, decode.int) {
        Ok(n) -> n
        Error(_) -> 0
      }
      #(Model(..model, rows_imported: n), command.none())
    }

    AsyncResult(tag: "file_import", result: Ok(_rows)) ->
      #(Model(..model, importing: False), command.none())

    _ -> #(model, command.none())
  }
}
```

#### Cancelling async work

`command.cancel` cancels a running `async` or `stream` command by its
tag. The runtime tracks running tasks by tag and terminates the
associated process. If the task has already completed, this is a no-op.

```gleam
command.cancel(tag)
```

```gleam
WidgetClick(id: "cancel_import", ..) ->
  #(Model(..model, importing: False), command.cancel("file_import"))
```

#### Done (lift a value)

`command.done` wraps an already-resolved value as a command. The runtime
immediately dispatches `mapper(value)` through `update` without spawning
a task. Useful for lifting a pure value into the command pipeline.

```gleam
command.done(value, mapper)
```

```gleam
WidgetClick(id: "reset", ..) ->
  #(model, command.done(dynamic.nil(), fn(_) { ConfigLoaded(defaults()) }))
```

#### Exit

`command.exit()` terminates the application.

```gleam
command.exit()
```

#### Widget operations

##### Focus

```gleam
command.focus(widget_id)        // Focus a text input
command.focus_next()            // Focus next focusable widget
command.focus_previous()        // Focus previous focusable widget
```

Example:

```gleam
WidgetClick(id: "new_todo", ..) ->
  #(Model(..model, input: ""), command.focus("todo_input"))
```

##### Text operations

```gleam
command.select_all(widget_id)                    // Select all text
command.MoveCursorToFront(widget_id: widget_id)  // Cursor to start
command.MoveCursorToEnd(widget_id: widget_id)    // Cursor to end
command.MoveCursorTo(widget_id: widget_id, position: pos)  // Cursor to char position
command.SelectRange(widget_id: widget_id, start: s, end: e)  // Select character range
```

Example:

```gleam
WidgetClick(id: "select_word", ..) ->
  #(model, command.SelectRange(widget_id: "editor", start: 5, end: 10))
```

##### Scroll operations

```gleam
command.ScrollTo(widget_id: id, offset: offset)    // Scroll to absolute position
command.SnapTo(widget_id: id, x: x, y: y)          // Snap scroll to absolute offset
command.SnapToEnd(widget_id: id)                    // Snap to end of scrollable content
command.ScrollBy(widget_id: id, x: x, y: y)        // Scroll by relative delta
```

Example:

```gleam
WidgetClick(id: "scroll_bottom", ..) ->
  #(model, command.SnapToEnd(widget_id: "chat_log"))
```

#### Window management

Windows are opened declaratively by including window nodes in the view tree.
There is no `open_window` command. To open a window, add a `window` node to
the tree returned by `view`. To close one, remove it or use
`close_window`.

```gleam
command.close_window(window_id)                    // Close a window
command.resize_window(window_id, width, height)    // Resize
command.move_window(window_id, x, y)               // Move
command.maximize_window(window_id)                 // Maximize
command.minimize_window(window_id)                 // Minimize
command.toggle_maximize(window_id)                 // Toggle maximize state
command.toggle_decorations(window_id)              // Toggle title bar/borders
command.gain_focus(window_id)                      // Bring window to front
command.screenshot(window_id, tag)                 // Capture window pixels
command.SetWindowMode(window_id: id, mode: mode)   // "fullscreen", "windowed", etc.
command.SetWindowLevel(window_id: id, level: level) // "normal", "always_on_top", etc.
command.DragWindow(window_id: id)                   // Initiate OS window drag
command.DragResizeWindow(window_id: id, direction: dir) // Initiate OS resize from edge
command.RequestUserAttention(window_id: id, urgency: option.Some("critical"))
command.SetResizable(window_id: id, resizable: True)
command.SetMinSize(window_id: id, width: w, height: h)
command.SetMaxSize(window_id: id, width: w, height: h)
command.EnableMousePassthrough(window_id: id)
command.DisableMousePassthrough(window_id: id)
command.ShowSystemMenu(window_id: id)
command.SetIcon(window_id: id, rgba_data: data, width: w, height: h)
command.SetResizeIncrements(window_id: id, width: option.Some(w), height: option.Some(h))
command.AllowAutomaticTabbing(enabled: True)
```

Example:

```gleam
WidgetClick(id: "go_fullscreen", ..) ->
  #(model, command.SetWindowMode(window_id: "main", mode: "fullscreen"))

WidgetClick(id: "pin_on_top", ..) ->
  #(model, command.SetWindowLevel(window_id: "main", level: "always_on_top"))
```

`SetIcon` sends raw RGBA pixel data. The `rgba_data` must be a `BitArray`
of `width * height * 4` bytes.

#### Window queries

Window queries are commands whose results arrive as events in `update`.
Window property queries use the **effect response** transport -- results
arrive as `EffectResponse(request_id: id, result: EffectOk(data))` where
`id` is the **window_id string**. System queries use a separate path
where the tag is used.

##### Window property queries

These go through the effect/window_op system. Results arrive in `update`
as `EffectResponse(request_id: window_id, result: EffectOk(data))`.

```gleam
command.GetWindowSize(window_id: id, tag: tag)
// Result: EffectResponse(request_id: id, result: EffectOk(data))
// data contains width and height

command.GetWindowPosition(window_id: id, tag: tag)
// Result: EffectResponse with x and y

command.GetMode(window_id: id, tag: tag)
// Result: EffectResponse with mode ("windowed", "fullscreen", "hidden")

command.GetScaleFactor(window_id: id, tag: tag)
// Result: EffectResponse with factor

command.IsMaximized(window_id: id, tag: tag)
command.IsMinimized(window_id: id, tag: tag)
command.RawWindowId(window_id: id, tag: tag)
command.MonitorSize(window_id: id, tag: tag)
```

Example:

```gleam
WidgetClick(id: "check_size", ..) ->
  #(model, command.GetWindowSize(window_id: "main", tag: "got_size"))

EffectResponse(request_id: "main", result: EffectOk(data)) -> {
  // Decode width/height from data using gleam/dynamic/decode
  #(model, command.none())
}
```

**Note:** Because the response is keyed by `window_id` rather than `tag`,
issuing multiple different queries against the same window will produce
results that share the same `window_id` key. Distinguish them by the shape
of the data.

##### System queries

System-level queries use a different transport path. Results arrive as
dedicated event constructors where the **tag** identifies the response.

```gleam
command.GetSystemTheme(tag: tag)
// Result: SystemTheme(tag: tag, theme: mode)
// mode is "light", "dark", or "none"

command.GetSystemInfo(tag: tag)
// Result: SystemInfo(tag: tag, data: info)
// Requires the renderer to be built with the `sysinfo` feature.
```

```gleam
WidgetClick(id: "detect_theme", ..) ->
  #(model, command.GetSystemTheme(tag: "theme_detected"))

SystemTheme(tag: "theme_detected", theme: mode) ->
  #(Model(..model, os_theme: mode), command.none())
```

#### Image operations

In-memory images can be created, updated, and deleted at runtime. The
`Image` widget references them via a handle string as its source.

```gleam
command.create_image(handle, data)                     // From PNG/JPEG bytes (BitArray)
command.CreateImageRgba(handle: h, width: w, height: h_, pixels: px) // From raw RGBA
command.UpdateImage(handle: h, data: data)              // Update with PNG/JPEG
command.UpdateImageRgba(handle: h, width: w, height: h_, pixels: px)
command.delete_image(handle)                            // Remove in-memory image
command.clear_images()                                  // Remove all images
command.ListImages(tag: tag)                            // List handles -> ImageList event
```

Example:

```gleam
WidgetClick(id: "load_preview", ..) -> {
  let cmd = command.async(fn() {
    let assert Ok(data) = simplifile.read_bits("preview.png")
    dynamic.unsafe_coerce(dynamic.from(data))
  }, "preview_loaded")
  #(model, cmd)
}

AsyncResult(tag: "preview_loaded", result: Ok(value)) -> {
  // decode BitArray from value, then:
  #(model, command.create_image("preview", data))
}
```

#### PaneGrid operations

Commands for manipulating panes in a `PaneGrid` widget.

```gleam
command.PaneSplit(pane_grid_id: id, pane_id: pane, axis: "horizontal", new_pane_id: new_pane)
command.PaneClose(pane_grid_id: id, pane_id: pane)
command.PaneSwap(pane_grid_id: id, pane_a: a, pane_b: b)
command.PaneMaximize(pane_grid_id: id, pane_id: pane)
command.PaneRestore(pane_grid_id: id)
```

Example:

```gleam
WidgetClick(id: "split_editor", ..) ->
  #(model, command.PaneSplit(
    pane_grid_id: "pane_grid",
    pane_id: dynamic.from("editor"),
    axis: "horizontal",
    new_pane_id: dynamic.from("new_editor"),
  ))
```

#### Timers

```gleam
command.send_after(delay_ms, msg)  // Send msg to update after delay
```

Sending another `send_after` with an identical `msg` cancels the
previous timer (deduplication via stable hashing).

```gleam
WidgetClick(id: "flash_message", ..) -> {
  let model = Model(..model, message: option.Some("Saved!"))
  #(model, command.send_after(3000, ClearMessage))
}
```

#### Batch

```gleam
command.batch([
  command.focus("name_input"),
  command.send_after(5000, AutoSave),
])
```

Commands in a batch are dispatched sequentially. Async commands spawn
concurrent tasks, but the dispatch loop itself processes each command in
order.

#### Extension commands

Push data directly to a native Rust extension widget without triggering the
view/diff/patch cycle. Used for high-frequency data like terminal output or
streaming log lines.

```gleam
// Single command
command.ExtensionCommand(node_id: "term-1", op: "write", payload: data)

// Batch (all processed before next view cycle)
command.ExtensionCommands(commands: [
  #("term-1", "write", data1),
  #("log-1", "append", data2),
])
```

Extension commands are only meaningful for widgets backed by a
`WidgetExtension` Rust implementation. They are silently ignored for
widgets without an extension handler.

#### No-op

```gleam
command.none()
```

Return `command.none()` when `update` has no side effects.

### Chaining commands

In iced, commands support `.then()` and `.chain()` for sequencing async
work. Toddy does not need dedicated chaining combinators because the Elm
update cycle provides this naturally: each `update` can return
`#(model, command)`, and the result of each command feeds back into
`update` as an event, which can return more commands.

The model is updated and `view` is re-rendered between each step. This
is actually more powerful than iced's chaining because you get full model
updates and UI refreshes at every link in the chain, not just at the end.

```gleam
// Step 1: user clicks "deploy" -- validate first
WidgetClick(id: "deploy", ..) ->
  #(Model(..model, status: Validating), command.async(fn() {
    validate_config(model.config)
  }, "validated"))

// Step 2: validation result arrives -- if OK, start the build
AsyncResult(tag: "validated", result: Ok(_)) ->
  #(Model(..model, status: Building), command.async(fn() {
    build_release(model.config)
  }, "built"))

AsyncResult(tag: "validated", result: Error(reason)) ->
  #(Model(..model, status: Failed(reason)), command.none())

// Step 3: build result arrives -- if OK, push it
AsyncResult(tag: "built", result: Ok(artifact)) ->
  #(Model(..model, status: Deploying), command.async(fn() {
    push_artifact(artifact)
  }, "deployed"))

// Step 4: done
AsyncResult(tag: "deployed", result: Ok(_)) ->
  #(Model(..model, status: Live), command.none())
```

Each step is a separate case clause with its own model state. The
UI reflects progress at every stage. No special chaining API needed --
the architecture is the API.

### How commands work internally

Commands are data. They describe what should happen, not how. The runtime
interprets them:

- **Async commands** spawn an Erlang process managed by the runtime.
  When the task completes, the result is wrapped in `AsyncResult` and
  dispatched through `update`.
- **Widget operations** are encoded as wire messages and sent to the
  renderer.
- **Window commands** are encoded as wire messages to the renderer.
- **Window property queries** are sent as window_op wire messages. The
  renderer responds with an `EffectResponse` keyed by window_id.
  **System queries** use a separate wire message keyed by tag.
- **Image operations** are encoded as wire messages to the renderer.
- **PaneGrid operations** are encoded as widget ops sent to the renderer.
- **Timers** use Erlang's `send_after` under the hood.

Commands are not side effects in `update`. They are descriptions of side
effects that the runtime executes after `update` returns. This keeps
`update` testable:

```gleam
pub fn clicking_fetch_returns_async_command_test() {
  let model = Model(loading: False, data: "")
  let #(model, cmd) = update(model, WidgetClick(id: "fetch", scope: []))
  should.be_true(model.loading)
  // cmd is an Async(..) constructor -- inspect if needed
}
```

## Subscriptions

Subscriptions are ongoing event sources. Unlike commands (one-shot),
subscriptions produce events continuously as long as they are active.

**Important: tag semantics differ by subscription type.** For timer
subscriptions (`every`), the tag identifies the event -- `update`
receives `TimerTick(tag: tag, timestamp: ts)`. For all renderer
subscriptions (keyboard, mouse, window, etc.), the tag is management-only
and does NOT appear in the event. Renderer events arrive as their own
constructors like `KeyPress(..)` regardless of what tag you chose.

### The subscribe callback

```gleam
import toddy/subscription

fn subscribe(model: Model) -> List(subscription.Subscription) {
  let subs = []

  // Tick every second while the timer is running
  let subs = case model.timer_running {
    True -> [subscription.every(1000, "tick"), ..subs]
    False -> subs
  }

  // Always listen for keyboard shortcuts
  [subscription.on_key_press("key_event"), ..subs]
}
```

`subscribe` is called after every `update`. The runtime diffs the
returned subscription list against the previous one and starts/stops
subscriptions as needed. Subscriptions are identified by their
specification -- returning the same `subscription.every(1000, "tick")` on
consecutive calls keeps the existing subscription alive; removing it stops
it.

### Available subscriptions

#### Time

```gleam
subscription.every(interval_ms, tag)
// Delivers: TimerTick(tag: tag, timestamp: ts) every interval_ms
```

#### Keyboard

```gleam
subscription.on_key_press(tag)
// Delivers: KeyPress(key: key, modifiers: mods, ..)

subscription.on_key_release(tag)
// Delivers: KeyRelease(key: key, ..)

subscription.on_modifiers_changed(tag)
// Delivers: ModifiersChanged(modifiers: mods, ..)

// The tag is used by the runtime to register/unregister the
// subscription with the renderer. It is NOT included in the event
// delivered to update. See docs/events.md for the full event definitions.
```

#### Window lifecycle

```gleam
subscription.on_window_close(tag)
// Delivers: WindowClosed(window_id: id)

subscription.on_window_open(tag)
// Delivers: WindowOpened(window_id: id, width: w, height: h, ..)

subscription.on_window_resize(tag)
// Delivers: WindowResized(window_id: id, width: w, height: h)

subscription.on_window_focus(tag)
// Delivers: WindowFocused(window_id: id)

subscription.on_window_unfocus(tag)
// Delivers: WindowUnfocused(window_id: id)

subscription.on_window_move(tag)
// Delivers: WindowMoved(window_id: id, x: x, y: y)

subscription.on_window_event(tag)
// Delivers: various Window* constructors (catch-all for window events)
```

#### Mouse

```gleam
subscription.on_mouse_move(tag)
// Delivers: MouseMoved(x: x, y: y, captured: captured)

subscription.on_mouse_button(tag)
// Delivers: MouseButtonPressed(button: btn, captured: c) or
//           MouseButtonReleased(button: btn, captured: c)

subscription.on_mouse_scroll(tag)
// Delivers: MouseWheelScrolled(delta_x: dx, delta_y: dy, unit: unit, captured: c)
```

#### Touch

```gleam
subscription.on_touch(tag)
// Delivers: TouchPressed(finger_id: fid, x: x, y: y, captured: c)
//           TouchMoved(..)
//           TouchLifted(..)
//           TouchLost(..)
```

#### IME (Input Method Editor)

```gleam
subscription.on_ime(tag)
// Delivers: ImeOpened(captured: c)
//           ImePreedit(text: text, cursor: cursor, captured: c)
//           ImeCommit(text: text, captured: c)
//           ImeClosed(captured: c)
```

#### System

```gleam
subscription.on_theme_change(tag)
// Delivers: ThemeChanged(theme: mode)  (mode is "light" or "dark")

subscription.on_animation_frame(tag)
// Delivers: AnimationFrame(timestamp: ts)

subscription.on_file_drop(tag)
// Delivers: WindowFileDropped(window_id: id, path: path)
//           WindowFileHovered(window_id: id, path: path)
//           WindowFilesHoveredLeft(window_id: id)
```

#### Catch-all

```gleam
subscription.on_event(tag)
// Receives all renderer events.
```

### Event rate limiting

The renderer supports rate limiting for high-frequency events (mouse moves,
scroll, animation frames, slider drags, etc.). This reduces wire traffic
and host CPU usage. Three configuration levels, in order of priority:

#### Per-widget `event_rate` prop

Widgets that emit high-frequency events accept an `event_rate` attribute:

```gleam
// Volume slider limited to 15 events/sec, seek bar at 60:
ui.slider("volume", 0.0, 100.0, model.volume, [ui.event_rate(15)])
ui.slider("seek", 0.0, model.duration, model.position, [ui.event_rate(60)])
```

Supported on: `Slider`, `VerticalSlider`, `Canvas`, `MouseArea`, `Sensor`,
`PaneGrid`, and all extension widgets.

#### Per-subscription `max_rate`

Renderer subscriptions accept a `max_rate` via `set_max_rate`:

```gleam
// Rate-limit mouse moves to 30 events per second:
subscription.on_mouse_move("mouse")
  |> subscription.set_max_rate(30)

// Animation frames at 60fps:
subscription.on_animation_frame("frame")
  |> subscription.set_max_rate(60)

// Subscribe but never emit (capture tracking only):
subscription.on_mouse_move("mouse")
  |> subscription.set_max_rate(0)
```

Timer subscriptions (`every`) do not support `max_rate`.

#### Global `default_event_rate` setting

A global default applied to all coalescable event types:

```gleam
fn settings() -> Settings {
  Settings(
    ..app.default_settings(),
    default_event_rate: option.Some(60),
  )
}
```

Set to 60 for most apps. Lower for dashboards or remote rendering.
`None` for unlimited (default behavior).

### Subscription lifecycle

Subscriptions are declarative. You do not start or stop them imperatively.
You return a list from `subscribe`, and the runtime manages the rest:

```gleam
fn subscribe(model: Model) -> List(subscription.Subscription) {
  case model.polling {
    True -> [subscription.every(5000, "poll")]
    False -> []
  }
}

fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "start_polling", ..) ->
      #(Model(..model, polling: True), command.none())

    WidgetClick(id: "stop_polling", ..) ->
      #(Model(..model, polling: False), command.none())

    TimerTick(tag: "poll", ..) ->
      #(model, command.async(fetch_data, "data_received"))

    _ -> #(model, command.none())
  }
}
```

When `polling` becomes `True`, the runtime starts the timer. When it becomes
`False`, the runtime stops it. No explicit cleanup needed.

### How subscriptions work internally

- **Time subscriptions** use Erlang's timer facilities.
- **Keyboard, mouse, touch, and window subscriptions** are registered with
  the renderer via wire messages. The renderer sends events when they occur.
- **System subscriptions** (theme change, animation frame, file drop) are
  also renderer-side event sources.

Subscriptions that require the renderer (everything except timers) are
paused during renderer restart and resumed once the renderer is back.

## Application settings

The `settings` callback is documented in
[app-behaviour.md](app-behaviour.md). Notable settings relevant to
commands and rendering:

- `vsync` -- `Bool` (default `True`). Controls vertical sync. Set to
  `False` for uncapped frame rates (useful for benchmarks or animation-heavy
  apps at the cost of higher GPU usage).
- `scale_factor` -- `Float` (default `1.0`). Global UI scale factor applied
  to all windows. Values greater than 1.0 make the UI larger; less than 1.0
  makes it smaller.
- `default_event_rate` -- `Option(Int)`. Maximum events per second for
  coalescable event types. `None` for unlimited (default). See
  [Event rate limiting](#event-rate-limiting).

```gleam
fn settings() -> Settings {
  Settings(
    ..app.default_settings(),
    antialiasing: True,
    vsync: False,
    scale_factor: 1.5,
    default_event_rate: option.Some(60),
  )
}
```

## Commands vs. effects

Commands are Gleam-side operations handled by the runtime. Effects are
native platform operations handled by the renderer (see [effects.md](effects.md)).

| | Commands | Effects |
|---|---|---|
| Handled by | Gleam runtime | Rust renderer |
| Examples | async work, timers, focus | file dialogs, clipboard, notifications |
| Transport | internal | wire protocol request/response |
| Return from | `update` | `update` (via `toddy/effects` functions) |

Widget operations and window commands are a hybrid -- they are initiated
from the Gleam side but executed by the renderer. They use the command
mechanism for the API but effect/effect_response for the transport.
