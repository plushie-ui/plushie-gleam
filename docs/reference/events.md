# Events

All user interactions, system responses, and asynchronous results
are delivered to your `update` callback as variants of
`plushie/event.Event`.

This page is a comprehensive reference. For a gentler introduction,
see the [Events guide](../guides/05-events.md).

## Event union

`plushie/event.Event` is a flat sum type whose variants wrap one of
several typed sub-records:

```gleam
pub type Event {
  Widget(WidgetEvent)
  Key(KeyEvent)
  Window(WindowEvent)
  Timer(TimerEvent)
  Async(AsyncEvent)
  Stream(StreamEvent)
  Effect(EffectEvent)
  System(SystemEvent)
  Ime(ImeEvent)
  ModifiersChanged(ModifiersEvent)
  Error(ErrorEvent)
  Session(SessionEvent)
}
```

Each `update` clause pattern-matches on the outer `Event` variant
and, for widget interactions, on the inner `WidgetEvent`
constructor. Apps built with `app.simple` use `Event` as the
message type directly; apps built with `app.application` map
`Event` through an `on_event` function to a custom `msg` type.

## Event taxonomy

| Category | Outer variant | Inner constructor(s) | Source |
|---|---|---|---|
| Widget interaction | `Widget` | `Click`, `Input`, `Toggle`, `Select`, etc. | Renderer (widget callbacks) |
| Keyboard | `Key` | `KeyEvent` record | Subscription (key press / release) |
| Modifier state | `ModifiersChanged` | `ModifiersEvent` record | Subscription (modifier change) |
| Pointer (mouse, touch, pen) | `Widget` | `Press`, `Release`, `Move`, `Scroll`, `Enter`, `Exit`, `DoubleClick` | Canvas, pointer_area, sensor, global pointer subscription |
| IME | `Ime` | `ImeEvent` record | Subscription (input method editor) |
| Window lifecycle | `Window` | `WindowEvent` record | Renderer |
| System | `System` | `SystemInfo`, `SystemTheme`, `AnimationFrame`, ... | Renderer |
| Timer | `Timer` | `TimerEvent` record | Subscription (`subscription.every`) |
| Async result | `Async` | `AsyncEvent` record | Command (`command.async`) |
| Stream value | `Stream` | `StreamEvent` record | Command (`command.stream`) |
| Effect response | `Effect` | `EffectEvent` record | Renderer (file dialogs, clipboard, etc.) |
| Errors and diagnostics | `Error` | `CommandError`, `RendererError`, `Diagnostic`, `ProtocolVersionMismatch`, ... | Renderer / runtime |
| Session (multiplexed) | `Session` | `SessionError`, `SessionClosed` | Renderer (multiplexed mode) |

## WidgetEvent variants

Every widget-level interaction is one variant of `WidgetEvent`,
carried inside an outer `Widget(...)`. All variants carry an
`EventTarget` record identifying the widget, its scope chain, and
its window. Additional fields depend on the variant.

### Standard widget events

| Variant | Payload | Description |
|---|---|---|
| `Click` | — | Button pressed |
| `Input` | `value: String` | Text input / editor content changed |
| `Submit` | `value: String` | Text input submitted (Enter) |
| `Toggle` | `value: Bool` | Toggler / checkbox toggled |
| `Select` | `value: String` | Pick list / combo box / radio selection |
| `Slide` | `value: Float` | Slider moved during drag |
| `SlideRelease` | `value: Float` | Slider released at final value |
| `Paste` | `value: String` | Paste action on a text input |
| `Open` | — | Expandable (combo_box, pick_list) opened |
| `Close` | — | Expandable closed |
| `OptionHovered` | `value: String` | Pick list / combo box option hovered |
| `Sort` | `value: String` | Table column sort requested (column key) |
| `Scrolled` | `data: ScrollData` | Scrollable viewport offset changed |
| `KeyBinding` | `value: String` | Named key binding activated on a widget |
| `LinkClicked` | `link: String` | Hyperlink in rich_text or markdown activated |
| `TransitionComplete` | `tag: String`, `prop: String` | Renderer-side transition finished |
| `Status` | `value: Dynamic` | Interaction status changed (used internally for focus tracking) |

`ScrollData` carries `absolute_x`, `absolute_y`, `relative_x`,
`relative_y`, `bounds_width`, `bounds_height`, `content_width`,
`content_height`.

### Pointer events

Unified pointer events for canvas-level, pointer_area, and sensor
interactions. The `pointer` field identifies the input device
(`Mouse`, `Touch`, `Pen`) and `button` identifies which button was
involved.

| Variant | Fields |
|---|---|
| `Press` | `target`, `x`, `y`, `button`, `pointer`, `finger`, `modifiers`, `captured` |
| `Release` | `target`, `x`, `y`, `button`, `pointer`, `finger`, `modifiers`, `captured`, `lost: Option(Bool)` |
| `Move` | `target`, `x`, `y`, `pointer`, `finger`, `modifiers`, `captured` |
| `Scroll` | `target`, `x`, `y`, `delta_x`, `delta_y`, `pointer`, `modifiers`, `unit: Option(ScrollUnit)`, `captured` |
| `Enter` | `target`, `x: Option(Float)`, `y: Option(Float)` |
| `Exit` | `target`, `x: Option(Float)`, `y: Option(Float)` |
| `DoubleClick` | `target`, `x`, `y`, `pointer`, `modifiers` |
| `Resize` | `target`, `width: Float`, `height: Float` |

`MouseButton` is one of `LeftButton`, `RightButton`,
`MiddleButton`, `BackButton`, `ForwardButton`,
`OtherButton(String)`.

`PointerType` is one of `Mouse`, `Touch`, `Pen`.

`finger` is `Some(Int)` for touch events and `None` for mouse /
pen.

`ScrollUnit` is `Line` or `Pixel`. Some trackpads report line units,
others pixel; inspect `unit` when you need to distinguish.

Note: `Scroll` is pointer input (wheel delta at a position);
`Scrolled` (standard widget event, above) is container state - a
scrollable widget reporting that its viewport offset changed.

### Generic element events

Focus, blur, drag, and widget-scoped key events.

| Variant | Fields |
|---|---|
| `Focused` | `target` |
| `Blurred` | `target` |
| `Drag` | `target`, `x`, `y`, `delta_x`, `delta_y` |
| `DragEnd` | `target`, `x`, `y` |
| `WidgetKeyPress` | `target`, `key`, `modified_key`, `physical_key`, `modifiers`, `location`, `text`, `repeat` |
| `WidgetKeyRelease` | `target`, `key`, `modified_key`, `physical_key`, `modifiers`, `location`, `text` |

`WidgetKeyPress` / `WidgetKeyRelease` are distinct from the
subscription-level `Key` event: they deliver keystrokes to a widget
that holds keyboard focus, scoped via `target`, without needing a
global subscription.

### Pane grid events

| Variant | Fields |
|---|---|
| `PaneClicked` | `target`, `pane: Dynamic` |
| `PaneResized` | `target`, `split: Dynamic`, `ratio: Float` |
| `PaneDragged` | `target`, `pane: Dynamic`, `drop_target: Dynamic`, `action: String`, `region: Option(String)`, `edge: Option(String)` |
| `PaneFocusCycle` | `target`, `pane: Dynamic` |

Pane identifiers and split keys are typed `Dynamic` because they
can be any term the pane grid was configured with (atoms or
strings). Use `gleam/dynamic` decoders at the call site to recover
typed values.

### Custom widget events

Custom widgets declared with the widget system emit a
`CustomWidget(kind, target, value, data)` variant. `kind` is the
widget's type name; `value` and `data` carry the custom payload as
`Dynamic` for typed decoding by the app. See the [Custom Widgets
reference](custom-widgets.md) for declaration and dispatch.

## Event record reference

### `KeyEvent`

Keyboard press and release events from subscriptions.

| Field | Type | Description |
|---|---|---|
| `event_type` | `KeyEventType` (`KeyPressed` / `KeyReleased`) | Key action |
| `window_id` | `String` | Source window |
| `key` | `String` | Logical key label |
| `modified_key` | `String` | Key after modifier transforms (Shift+a -> "A") |
| `physical_key` | `Option(String)` | Physical scan code |
| `location` | `KeyLocation` (`Standard`, `LeftSide`, `RightSide`, `Numpad`) | Key location on the keyboard |
| `modifiers` | `Modifiers` | Modifier state at the time of the event |
| `text` | `Option(String)` | Text produced by the key, if any |
| `repeat` | `Bool` | Whether this is an OS-generated repeat |
| `captured` | `Bool` | Whether a widget handler captured this event |

#### Modifiers

The `modifiers` field is a `Modifiers` record:

| Field | Purpose |
|---|---|
| `shift` | Shift key |
| `ctrl` | Control key |
| `alt` | Alt key (Option on macOS) |
| `logo` | Logo / Super key (Windows key, Command on macOS) |
| `command` | **Platform-aware**: Ctrl on Linux / Windows, Command on macOS |

Match on `command: True` for cross-platform shortcuts. The `command`
field is the one to use unless you specifically want to distinguish
Ctrl from Command.

Use `event.modifiers_none()` for a no-modifiers sentinel value.

### `ModifiersEvent`

Modifier state change event from a modifier-tracking subscription.

| Field | Type | Description |
|---|---|---|
| `window_id` | `String` | Source window |
| `modifiers` | `Modifiers` | Current modifier state |
| `captured` | `Bool` | Whether a widget handler captured this event |

### `ImeEvent`

Input Method Editor events for complex-script input. Lifecycle:
`ImeOpened` -> `ImePreedit` (repeated) -> `ImeCommit` -> `ImeClosed`.

| Field | Type | Description |
|---|---|---|
| `event_type` | `ImeEventType` | IME phase |
| `window_id` | `String` | Source window |
| `text` | `Option(String)` | Composition / commit text |
| `cursor` | `Option(#(Int, Int))` | Byte offsets in preedit |
| `captured` | `Bool` | Whether a widget handler captured this event |

### `WindowEvent`

Window lifecycle events from the renderer.

| Field | Type | Description |
|---|---|---|
| `event_type` | `WindowEventType` | See below |
| `window_id` | `String` | Window identifier |
| `width`, `height` | `Option(Float)` | Size (for `Resized`) |
| `x`, `y` | `Option(Float)` | Position (for `Moved`) |
| `scale_factor` | `Option(Float)` | DPI scale (for `Rescaled`) |
| `path` | `Option(String)` | File path (for file drop events) |

`WindowEventType`: `Opened`, `Closed`, `CloseRequested`, `Resized`,
`Moved`, `WindowFocused`, `WindowUnfocused`, `Rescaled`,
`FileHovered`, `FileDropped`, `FilesHoveredLeft`.

### `SystemEvent`

System query responses and runtime events. Each variant carries
its own fields:

| Variant | Fields |
|---|---|
| `SystemInfo` | `tag: String`, `value: Dynamic` |
| `SystemTheme` | `tag: String`, `theme: String` |
| `ThemeChanged` | `theme: String` |
| `AnimationFrame` | `timestamp: Int` |
| `AllWindowsClosed` | — |
| `ImageList` | `tag: String`, `handles: List(String)` |
| `TreeHash` | `tag: String`, `hash: String` |
| `FocusedWidget` | `tag: String`, `widget_id: Option(String)` |
| `ScreenshotData` | `tag: String`, `hash: String`, `width: Int`, `height: Int`, `pixels: BitArray` |
| `Announce` | `text: String` |
| `RecoveryFailed` | `kind: String`, `error: String`, `renderer_exit: RendererExit` |

`SystemTheme` and `ThemeChanged` keep the renderer's raw string for
compatibility. Convert concrete OS preferences with
`theme.system_theme_from_string(value)`, which returns `Ok(Light)` or
`Ok(Dark)` for `"light"` and `"dark"` and `Error(Nil)` for `"none"` or
unknown values.

### `TimerEvent`

Timer tick events from `subscription.every`.

| Field | Type | Description |
|---|---|---|
| `tag` | `String` | User-defined tag from the subscription |
| `timestamp` | `Int` | Monotonic millisecond timestamp |

### `AsyncEvent`

Results from `command.async`.

| Field | Type | Description |
|---|---|---|
| `tag` | `String` | User-defined tag |
| `result` | `Result(Dynamic, Dynamic)` | `Ok(value)` or `Error(reason)` |

The payloads are `Dynamic` because `async` carries the caller's
result type through an FFI boundary. Decode at the call site using
`gleam/dynamic` decoders for the type you produced.

### `StreamEvent`

Intermediate values from `command.stream`.

| Field | Type | Description |
|---|---|---|
| `tag` | `String` | User-defined tag |
| `value` | `Dynamic` | Emitted stream value |

### `EffectEvent`

Platform effect responses (file dialogs, clipboard, notifications).

| Field | Type | Description |
|---|---|---|
| `tag` | `String` | User-defined tag |
| `result` | `EffectResult` | Typed outcome |

`EffectResult` variants include `FileOpened(path)`, `FilesOpened(paths)`,
`FileSaved(path)`, `DirectorySelected(path)`, `ClipboardText(text)`,
`ClipboardHtml(html, alt_text)`, `ClipboardWritten`,
`NotificationShown`, `EffectCancelled`, `EffectTimeout`,
`EffectError(message)`, `EffectUnsupported`, `RendererRestarted`.
`EffectCancelled` is a normal outcome (user dismissed the dialog),
not an error.

### `ErrorEvent`

Errors and diagnostics surfaced to the app.

| Variant | Fields |
|---|---|
| `CommandError` | `reason`, `id`, `family`, `widget_type`, `message` |
| `RendererError` | `id`, `data: Dynamic` |
| `DuplicateNodeIds` | `details: Dynamic` |
| `Diagnostic` | `session`, `level`, `payload: Diagnostic` |
| `PropValidation` | `node_id`, `node_type`, `warnings: List(String)` |
| `ProtocolVersionMismatch` | `expected: Int`, `got: Int` |

`Diagnostic` is a typed sum type mirroring the renderer's
diagnostic taxonomy (duplicate IDs, empty IDs, tree depth limits,
font cap exhaustion, widget panics, settings validation errors,
etc.). See `plushie/event.gleam` for the full variant list.

### `SessionEvent`

Lifecycle events in multiplexed mode (`--max-sessions > 1`).

| Variant | Fields |
|---|---|
| `SessionError` | `session: String`, `code: String`, `error: String` |
| `SessionClosed` | `session: String`, `reason: String` |

## Pattern matching cookbook

### Match by widget ID

```gleam
case event {
  Widget(Click(target: EventTarget(id: "save", ..))) -> save(model)
  _ -> model
}
```

### Match by variant with payload

```gleam
case event {
  Widget(Input(target: EventTarget(id: "search", ..), value: text)) ->
    Model(..model, query: text)

  Widget(Toggle(target: EventTarget(id: "dark_mode", ..), value: on)) ->
    Model(..model, dark_mode: on)

  Widget(Slide(target: EventTarget(id: "volume", ..), value: level)) ->
    Model(..model, volume: level)

  _ -> model
}
```

### Match by scope (dynamic lists)

When items are rendered in a named container with a dynamic ID,
the container's ID appears at the head of the event's scope chain:

```gleam
case event {
  Widget(Click(target: EventTarget(id: "delete", scope: [item_id, ..], ..))) ->
    Model(..model, items: dict.delete(model.items, item_id))
  _ -> model
}
```

### Match a key with modifiers

```gleam
case event {
  Key(KeyEvent(event_type: KeyPressed, key: "s", modifiers: m, ..)) if m.command ->
    save(model)

  Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) ->
    close_dialog(model)

  _ -> model
}
```

### Match a pointer event with device type

```gleam
case event {
  // Mouse click
  Widget(Press(
    target: EventTarget(id: "area", ..),
    pointer: Mouse,
    button: LeftButton,
    ..,
  )) -> select(model)

  // Touch press
  Widget(Press(
    target: EventTarget(id: "area", ..),
    pointer: Touch,
    finger: Some(fid),
    ..,
  )) -> touch_start(model, fid)

  _ -> model
}
```

### Match a pointer event with modifiers

```gleam
case event {
  // Shift-click for multi-select
  Widget(Press(
    target: EventTarget(id: "item", ..),
    modifiers: m,
    ..,
  )) if m.shift -> add_to_selection(model)

  // Ctrl-drag for panning
  Widget(Move(
    target: EventTarget(id: "canvas", ..),
    x: x,
    y: y,
    modifiers: m,
    ..,
  )) if m.ctrl -> pan(model, x, y)

  _ -> model
}
```

### Match a custom widget event

```gleam
import gleam/dynamic/decode

case event {
  Widget(CustomWidget(kind: "color_picker", value: v, ..)) -> {
    case decode.run(v, decode.field("hue", "hue", decode.float)) {
      Ok(hue) -> Model(..model, hue: hue)
      Error(_) -> model
    }
  }
  _ -> model
}
```

### Match an async result

```gleam
case event {
  Async(AsyncEvent(tag: "fetch", result: Ok(data))) ->
    Model(..model, items: decode_items(data), loading: False)

  Async(AsyncEvent(tag: "fetch", result: Error(reason))) ->
    Model(..model, error: Some(describe_error(reason)), loading: False)

  _ -> model
}
```

### Match a stream value

```gleam
case event {
  Stream(StreamEvent(tag: "download", value: v)) ->
    apply_progress(model, v)
  _ -> model
}
```

### Match an effect result

```gleam
case event {
  Effect(EffectEvent(tag: "open_file", result: FileOpened(path))) ->
    load_file(model, path)

  Effect(EffectEvent(tag: "open_file", result: EffectCancelled)) ->
    model

  _ -> model
}
```

### Match a timer tick

```gleam
case event {
  Timer(TimerEvent(tag: "tick", ..)) ->
    Model(..model, ticks: model.ticks + 1)
  _ -> model
}
```

### Match window events

```gleam
case event {
  Window(WindowEvent(event_type: CloseRequested, window_id: wid, ..)) ->
    close_window(model, wid)

  Window(WindowEvent(
    event_type: Resized,
    width: Some(w),
    height: Some(h),
    ..,
  )) -> Model(..model, width: w, height: h)

  _ -> model
}
```

### Reach for the fully scoped path

`EventTarget` already carries a `full` field with the canonical
wire ID (e.g. `"main#sidebar/form/save"`). Use it as-is, or build
from `id` + `scope` + `window_id` if you need a different separator.

### Catch-all clause

Always include a catch-all as the last `case` branch so unhandled
events return the model unchanged:

```gleam
case event {
  // ... handled variants
  _ -> model
}
```

## Event flow

Events travel through a fixed pipeline before reaching your
`update` callback:

1. **Renderer.** The renderer detects a user interaction and
   encodes an event message on the wire.
2. **Bridge.** `plushie/bridge` receives the wire frame, decodes
   it via `plushie/protocol/decode`, and forwards the typed event
   to the runtime.
3. **Runtime.** `plushie/runtime` receives the event. If the
   event targets a widget whose subtree registered an
   `on_event` handler, the runtime walks the scope chain
   (innermost widget handler first) before delivering to the
   app. Widget handlers can emit, transform, consume, or ignore
   events.
4. **App.** Your `update` receives the event (unless a widget
   handler consumed it).

### Coalescable events

High-frequency events are coalescable to prevent queue backup
during rapid mouse movement or window resizing:

- `Widget(Move(...))` - pointer moves
- `Widget(Resize(...))` - sensor resizes

When multiple events of the same type arrive for the same source
before the runtime processes them, only the latest is delivered.
A zero-delay timer flushes coalesced events before the next
non-coalescable event, preserving relative ordering across event
families.

### Widget handler interception

Custom widgets with an `on_event` callback are registered in a
handler registry derived from the current view tree. When an event
arrives, the runtime checks the scope chain for registered
handlers. Each handler can return one of:

- `widget.Emit(kind, data)` - suppress the event and replace it
  with a `CustomWidget` event carrying `kind` and `data`
- `widget.UpdateState` - suppress the event, trigger a re-render
  (used when the handler mutated internal widget state)
- `widget.Consumed` - suppress the event entirely
- `widget.Ignored` - pass through to the next handler in the scope
  chain

Render-only widgets (no events, no state) are skipped in the
registry and have zero overhead in the event path. See the
[Custom Widgets reference](custom-widgets.md) for full details.

## See also

- [Events guide](../guides/05-events.md) - pattern matching and
  event shapes applied to a running app
- [Subscriptions reference](subscriptions.md) - keyboard, timer,
  and other subscription-delivered events
- [Commands reference](commands.md) - the command constructors
  that produce async, stream, and effect events
- [Scoped IDs reference](scoped-ids.md) - how container scoping
  shapes the `scope` field on events
- [Custom Widgets reference](custom-widgets.md) - declaring
  custom widget event families
