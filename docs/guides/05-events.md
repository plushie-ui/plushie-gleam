# Events

Every interaction in a Plushie app produces an event. A button click, a
keystroke in a text input, a checkbox toggle. Each one arrives in your
`update` as a typed value from the `plushie/event.Event` union.
Understanding what events look like and how to match on them is essential
for building anything beyond a static layout.

In this chapter we take a closer look at events and add an **event log** to
the pad that shows every event as it happens. Interact with a widget in the
preview, see the event it produces.

## The Event union

`plushie/event.Event` is a flat sum type. Every callback your `update`
receives is one of its variants:

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

The outer variant tells you the family. The inner record carries the
details. Pattern-match on both in one `case` arm. This chapter focuses on
the families you reach for daily: `Widget`, `Key`, and the `EventTarget`
that every widget event carries. For the full taxonomy, see the
[Events reference](../reference/events.md).

## WidgetEvent

Most user-interaction events arrive as `Widget(...)` wrapping a
`WidgetEvent` variant. Every variant carries an `EventTarget`:

```gleam
pub type EventTarget {
  EventTarget(window_id: String, id: String, scope: List(String), full: String)
}
```

`id` is the widget's local ID. `scope` is the ancestor container chain
(nearest parent first, with the window ID last). `window_id` is the source
window. `full` is the canonical wire ID like `"main#sidebar/form/save"`.

### Click

No payload beyond the target:

```gleam
case event {
  Widget(Click(target: EventTarget(id: "save", ..))) -> save(model)
  _ -> model
}
```

The `..` elides fields we don't care about.

### Input

Text content changed. `value` carries the full current text, not the delta.
Fires on every keystroke while the input is focused:

```gleam
case event {
  Widget(Input(target: EventTarget(id: "search", ..), value: text)) ->
    Model(..model, query: text)
  _ -> model
}
```

### Toggle

A toggler or checkbox flipped. `value` is the new boolean state:

```gleam
case event {
  Widget(Toggle(target: EventTarget(id: "dark_mode", ..), value: on)) ->
    Model(..model, dark_mode: on)
  _ -> model
}
```

### Submit

A text input was submitted with Enter (requires
`text_input.OnSubmit(True)` on the builder). `value` is the submitted text:

```gleam
case event {
  Widget(Submit(target: EventTarget(id: "new-name", ..), value: name)) ->
    create(model, name)
  _ -> model
}
```

### Slide

A slider moved during a drag. `value` is the current float position:

```gleam
case event {
  Widget(Slide(target: EventTarget(id: "volume", ..), value: level)) ->
    Model(..model, volume: level)
  _ -> model
}
```

Match `SlideRelease` instead if you only want the final value on release.

### Select

A pick list or combo box selection:

```gleam
case event {
  Widget(Select(target: EventTarget(id: "theme", ..), value: choice)) ->
    Model(..model, theme: choice)
  _ -> model
}
```

## Scope: identifying widgets in lists

When many widgets share the same local ID (like a "delete" button in each
row of a list), `scope` tells you which container they belong to. Match on
the head of the list to recover the row's dynamic ID:

```gleam
case event {
  Widget(Click(target: EventTarget(id: "delete", scope: [file, ..], ..))) ->
    delete_file(model, file)
  _ -> model
}
```

We'll use scope extensively in [chapter 6](06-lists-and-inputs.md) when
building the file list. For now, know that scope exists and carries the
container ancestry.

## Keyboard events

Keyboard events come from a subscription, not a widget. They arrive as
`Key(KeyEvent(...))`:

```gleam
case event {
  Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) ->
    close_dialog(model)
  _ -> model
}
```

The `modifiers` field is a `Modifiers` record with `shift`, `ctrl`, `alt`,
`logo`, and `command`. Use `command` for cross-platform shortcuts: it's
Ctrl on Linux and Windows, Command on macOS.

```gleam
case event {
  // Save on Ctrl+S / Cmd+S.
  Key(KeyEvent(event_type: KeyPressed, key: "s", modifiers: m, ..))
    if m.command
  -> save(model)

  // Undo on Ctrl+Z / Cmd+Z (without Shift).
  Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..))
    if m.command && !m.shift
  -> undo(model)

  _ -> model
}
```

The guard runs after the structural match, so key and modifier conditions
compose naturally. Subscribing to key events requires
`subscription.on_key_press()`, covered in
[chapter 10](10-subscriptions.md).

## Pointer events

Canvas input, `pointer_area`, and the `sensor` widget deliver pointer
events as `WidgetEvent` variants: `Press`, `Release`, `Move`, `Scroll`,
`Enter`, `Exit`, `DoubleClick`. The `pointer` field identifies the device
(`Mouse`, `Touch`, `Pen`) and `button` identifies the mouse button.

```gleam
case event {
  Widget(Press(
    target: EventTarget(id: "canvas", ..),
    pointer: Mouse,
    button: LeftButton,
    x: x,
    y: y,
    ..,
  )) -> select_at(model, x, y)

  Widget(Press(
    target: EventTarget(id: "canvas", ..),
    pointer: Touch,
    finger: Some(fid),
    ..,
  )) -> touch_start(model, fid)

  _ -> model
}
```

One unified pointer family handles every input device. There is no
separate `MouseEvent` or `TouchEvent`.

## Other families at a glance

The rest of the `Event` variants surface in later chapters:

- `Window(WindowEvent(...))` for lifecycle (open, close, resize).
- `Timer(TimerEvent(...))` for subscription ticks.
- `Async(AsyncEvent(...))` for `command.async` results.
- `Stream(StreamEvent(...))` for `command.stream` values.
- `Effect(EffectEvent(...))` for file dialogs, clipboard, notifications.

Each gets its own chapter. For the full field lists, see the
[Events reference](../reference/events.md).

## Adding an event log to the pad

The best way to learn events is to see them. We'll add an event log at the
bottom of the pad that shows every event as it fires.

### Update the model

Add an `event_log` field and initialize it to `[]` in `init`:

```gleam
pub type Model {
  Model(
    source: String,
    preview: Option(Node),
    error: Option(String),
    event_log: List(String),
  )
}
```

### The catch-all logs events

The catch-all clause at the bottom of `update` is the perfect place to
log. Anything not handled by a specific arm gets recorded:

```gleam
fn update(model: Model, evt: Event) -> #(Model, Command(Event)) {
  case evt {
    Widget(Input(target: EventTarget(id: "editor", ..), value: s)) ->
      #(Model(..model, source: s), command.none())

    Widget(Click(target: EventTarget(id: "save", ..))) ->
      #(save_and_render(model), command.none())

    // Log everything else for the event-log panel.
    _ -> #(log_event(model, evt), command.none())
  }
}
```

### The log_event helper

Each event becomes one trimmed `string.inspect` entry, prepended to the
log and capped at 20 entries:

```gleam
import gleam/list
import gleam/string

fn log_event(model: Model, evt: Event) -> Model {
  let entry = string.inspect(evt)
  let trimmed = case string.length(entry) > 80 {
    True -> string.slice(entry, 0, 77) <> "..."
    False -> entry
  }
  Model(..model, event_log: [trimmed, ..list.take(model.event_log, 19)])
}
```

`string.inspect` formats the event as a Gleam literal. Clicking a button
produces an entry like:

    Widget(Click(target: EventTarget(window_id: "main", id: "btn", ..)))

Typing in a text input produces:

    Widget(Input(target: EventTarget(..), value: "hello"))

The log shows you exactly what to pattern-match on.

### The event log view

Render the log as a scrollable column of monospace text lines beneath the
editor and toolbar:

```gleam
import plushie/prop/font.{Monospace}
import plushie/prop/length.{Fixed}
import plushie/widget/column
import plushie/widget/scrollable
import plushie/widget/text

fn event_log_pane(model: Model) -> Node {
  ui.scrollable("event-log", [scrollable.Height(Fixed(120.0))], [
    ui.column(
      "log-lines",
      [column.Spacing(2.0), column.Padding(padding.all(4.0))],
      list.map(model.event_log, fn(entry) {
        ui.text(entry, entry, [text.Size(11.0), text.Font(Monospace)])
      }),
    ),
  ])
}
```

Each entry uses itself as the text widget's ID; because inspected events
differ by field values, IDs stay unique within the column. Drop
`event_log_pane(model)` into the root column after the toolbar and the
log fills in as you interact with the preview.

## A gallery experiment

Load an experiment with a gallery of common widgets and watch the log as
you click:

```gleam
ui.column("root", [column.Padding(padding.all(16.0)), column.Spacing(12.0)], [
  ui.text("title", "Widget Gallery", [text.Size(20.0)]),
  ui.button_("btn", "Button"),
  ui.checkbox("check", "Check me", False, []),
  ui.text_input("input", "", [text_input.Placeholder("Type here...")]),
  ui.slider("slide", #(0.0, 100.0), 50.0, []),
  ui.toggler("toggle", "Switch", False, []),
])
```

- Click the button: `Widget(Click(..))` with `id: "btn"`.
- Toggle the checkbox: `Widget(Toggle(..))` with `value: True` or `False`.
- Type in the input: `Widget(Input(..))` with the current text as `value`.
- Drag the slider: `Widget(Slide(..))` with the numeric value.

The event log is your best teacher from here on. Every new widget you
encounter produces events, and the log shows you their shape without
having to check the reference.

## Try it

- Add a `text_input` with `text_input.OnSubmit(True)`. Type and press
  Enter. Watch for `Widget(Submit(..))` in the log with your text as
  `value`.
- Add a `pick_list` with a few options. Pick one and see
  `Widget(Select(..))`.
- Add two buttons with the same label but different IDs. Click each and
  notice the `id` field distinguishes them.

---

Next: [Lists and Inputs](06-lists-and-inputs.md)
