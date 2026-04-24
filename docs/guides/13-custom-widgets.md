# Custom Widgets

As the pad has grown, the view function has gotten larger. The file list,
event log, and preview pane are each self-contained pieces of UI with their
own rendering logic. In this chapter we extract them into **custom widgets**,
reusable modules that encapsulate UI and behaviour.

Plushie has two kinds of custom widgets: pure Gleam (compose existing
widgets or draw custom visuals with canvas and SVG) and native (Rust-backed,
for custom GPU rendering). This chapter covers pure Gleam widgets. Native
widgets get a brief section at the end, with full details in the
[Custom Widgets reference](../reference/custom-widgets.md).

## What is a custom widget?

A custom widget is a value of type `WidgetDef(state, props)` plus a small
function that turns an ID and props into a placeholder `Node`. The runtime
recognises the placeholder during tree normalisation, threads per-instance
state through the widget's `view`, and routes events to the widget's
handler before they reach the app's `update`.

```gleam
import plushie/widget.{type WidgetDef, WidgetDef}

pub type WidgetDef(state, props) {
  WidgetDef(
    init: fn() -> state,
    view: fn(String, props, state) -> Node,
    handle_event: fn(Event, state) -> #(EventAction, state),
    subscriptions: fn(props, state) -> List(Subscription),
    cache_key: Option(fn(props, state) -> Dynamic),
  )
}
```

`init` produces the initial state for a fresh instance. `view` returns the
widget's subtree using the widget's scoped ID. `handle_event` intercepts
events bubbling out of the widget before the app sees them.
`subscriptions` returns per-instance subscriptions (typically timers).
`cache_key` is reserved for a future view memoisation pass and currently
has no runtime effect.

Three shapes cover every case:

- **Stateless, pass-through events**: use `widget.simple`.
- **Stateless, intercept events**: use `widget.with_handler`.
- **Stateful**: construct `WidgetDef` directly.

## Stateless widgets

The simplest custom widget takes props, returns a UI tree, and has no
internal state. Events from child widgets pass through to the parent app's
`update`.

```gleam
import plushie/node.{type Node}
import plushie/ui
import plushie/widget
import plushie/widget/column

pub type InputProps {
  InputProps(label: String, value: String)
}

pub fn def() -> widget.WidgetDef(Nil, InputProps) {
  widget.simple(fn(id, props: InputProps) {
    ui.column(id, [column.Spacing(4.0)], [
      ui.text_(id <> "/label", props.label),
      ui.text_input(id <> "/input", props.value, []),
    ])
  })
}

pub fn labeled_input(id: String, props: InputProps) -> Node {
  widget.build(def(), id, props)
}
```

`widget.simple` wraps a view function into a stateless `WidgetDef`,
filling in an empty `init`, a pass-through `handle_event` that returns
`Ignored`, and an empty subscriptions function. `widget.build(def, id,
props)` returns a placeholder `Node` the runtime expands during
normalisation. Children use IDs scoped under the widget's own ID
(`id <> "/label"`) so event targets carry the full path.

### Applying it: extract FileList

The file list sidebar is a good candidate. It takes the file list and
the active file, renders the sidebar, and lets select and delete events
pass through to the pad's `update`.

Before, inline in the pad's `view`:

```gleam
ui.column("sidebar",
  [column.Width(Fixed(200.0)), column.Padding(padding.all(8.0)), column.Spacing(8.0)],
  [
    ui.text("sidebar/title", "Experiments", [text.Size(14.0)]),
    ui.scrollable("sidebar/scroll", [scrollable.Height(Fill)], [
      ui.keyed_column("sidebar/files", [keyed_column.Spacing(2.0)],
        list.map(model.files, fn(file) {
          ui.row("sidebar/" <> file, [row.Spacing(4.0)], [
            ui.button(
              "sidebar/" <> file <> "/select",
              file,
              select_button_opts(file, model.active_file),
            ),
            ui.button_("sidebar/" <> file <> "/delete", "x"),
          ])
        }),
      ),
    ]),
  ],
)
```

After, as a widget module `plushie_pad/widgets/file_list.gleam`:

```gleam
import gleam/list
import plushie/node.{type Node}
import plushie/prop/length.{Fill, Fixed}
import plushie/prop/padding
import plushie/ui
import plushie/widget
import plushie/widget/column
import plushie/widget/keyed_column
import plushie/widget/row
import plushie/widget/scrollable
import plushie/widget/text

pub type FileListProps {
  FileListProps(files: List(String), active: String)
}

pub fn def() -> widget.WidgetDef(Nil, FileListProps) {
  widget.simple(fn(id, props: FileListProps) {
    ui.column(
      id,
      [
        column.Width(Fixed(200.0)),
        column.Padding(padding.all(8.0)),
        column.Spacing(8.0),
      ],
      [
        ui.text(id <> "/title", "Experiments", [text.Size(14.0)]),
        ui.scrollable(id <> "/scroll", [scrollable.Height(Fill)], [
          ui.keyed_column(
            id <> "/files",
            [keyed_column.Spacing(2.0)],
            list.map(props.files, fn(f) { row_for(id, f, props.active) }),
          ),
        ]),
      ],
    )
  })
}

pub fn file_list(id: String, props: FileListProps) -> Node {
  widget.build(def(), id, props)
}
```

`row_for` is a private helper that builds one sidebar row with the
select and delete buttons scoped under the widget's ID.

Use it in the pad:

```gleam
file_list.file_list(
  "sidebar",
  file_list.FileListProps(files: model.files, active: model.active_file),
)
```

The pad's `update` still handles the select and delete events through
scoped IDs. Because `widget.simple` uses `Ignored` as its handler, every
event bubbles up untouched.

## Stateful widgets with handlers

When a widget needs to intercept events, transform them, or carry its own
state, construct `WidgetDef` directly. The handler returns an `EventAction`
alongside the next state:

```gleam
pub type EventAction {
  Ignored
  Consumed
  Emit(kind: String, data: Dynamic)
  UpdateState
}
```

| Variant | Effect |
|---|---|
| `Ignored` | Let the event continue up the scope chain to the parent handler or the app |
| `Consumed` | Suppress the event entirely |
| `Emit(kind, data)` | Suppress and replace with `Widget(CustomWidget(kind, target, value, data))` |
| `UpdateState` | Suppress the event and trigger a re-render; the handler already returned the new state |

Events walk the widget scope from innermost to outermost. If every
handler returns `Ignored`, the event reaches the app's `update`. The
first `Consumed`, `Emit`, or `UpdateState` stops the walk.

For `Emit`, typed helpers avoid building the `Dynamic` payload by hand:
`widget.emit_string`, `widget.emit_int`, `widget.emit_float`,
`widget.emit_bool`, `widget.emit_none`.

### Applying it: extract EventLog

The event log can own its expanded or collapsed state. The parent app
only needs to pass in the list of entries; the widget handles the
toggle button internally and rebuilds its own subtree.

As a stateful widget:

```gleam
import gleam/int
import gleam/list
import gleam/option
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/node.{type Node}
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget.{
  type EventAction, type WidgetDef, Ignored, UpdateState, WidgetDef,
}
import plushie/widget/column
import plushie/widget/row
import plushie/widget/scrollable
import plushie/widget/text

pub type EventLogProps {
  EventLogProps(entries: List(String))
}

pub type EventLogState {
  EventLogState(expanded: Bool)
}

pub fn def() -> WidgetDef(EventLogState, EventLogProps) {
  WidgetDef(
    init: fn() { EventLogState(expanded: True) },
    view: view,
    handle_event: handle_event,
    subscriptions: fn(_, _) { [] },
    cache_key: option.None,
  )
}

pub fn event_log(id: String, props: EventLogProps) -> Node {
  widget.build(def(), id, props)
}

fn view(id: String, props: EventLogProps, state: EventLogState) -> Node {
  let header =
    ui.row(id <> "/toolbar", [row.Spacing(8.0)], [
      ui.button_(id <> "/toggle", case state.expanded {
        True -> "Hide Log"
        False -> "Show Log"
      }),
      ui.text(
        id <> "/count",
        int.to_string(list.length(props.entries)) <> " events",
        [text.Size(12.0)],
      ),
    ])

  let body = case state.expanded {
    False -> []
    True -> [
      ui.scrollable(id <> "/scroll", [scrollable.Height(Fixed(120.0))], [
        ui.column(
          id <> "/entries",
          [column.Spacing(2.0)],
          list.index_map(props.entries, fn(entry, i) {
            ui.text(id <> "/entry-" <> int.to_string(i), entry, [text.Size(12.0)])
          }),
        ),
      ]),
    ]
  }

  ui.column(id, [column.Spacing(4.0)], [header, ..body])
}

fn handle_event(
  ev: Event,
  state: EventLogState,
) -> #(EventAction, EventLogState) {
  case ev {
    Widget(Click(target: EventTarget(id: "toggle", ..))) -> #(
      UpdateState,
      EventLogState(expanded: !state.expanded),
    )
    _ -> #(Ignored, state)
  }
}
```

The toggle button updates internal state. Every other event falls
through with `Ignored` so any future interactive log entry bubbles up to
the app.

Note that the event target ID in the handler is the local `"toggle"`,
not the full scoped path. Inside a widget handler you match on local
IDs; the scope chain is already stripped to the widget's own frame.

## Emitting semantic events

When a widget should report a high-level event to the parent rather than
leaking low-level widget events, use `Emit`. The runtime wraps the kind
and data into `Widget(CustomWidget(...))` and continues the walk so
outer widgets and the app can react:

```gleam
import gleam/int
import gleam/string
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/widget.{type EventAction, Ignored}

fn handle_event(
  ev: Event,
  state: RatingState,
) -> #(EventAction, RatingState) {
  case ev {
    Widget(Click(target: EventTarget(id: local, ..))) ->
      case parse_star(local) {
        Ok(n) -> #(widget.emit_int("select", n), state)
        Error(_) -> #(Ignored, state)
      }
    _ -> #(Ignored, state)
  }
}

fn parse_star(local_id: String) -> Result(Int, Nil) {
  case string.starts_with(local_id, "star-") {
    True -> int.parse(string.drop_start(local_id, 5))
    False -> Error(Nil)
  }
}
```

The parent app pattern-matches on `Widget(CustomWidget(...))`:

```gleam
import gleam/dynamic/decode
import plushie/event.{CustomWidget, EventTarget, Widget}

case ev {
  Widget(CustomWidget(kind: "select", target: EventTarget(id: id, ..), data: d, ..)) -> {
    case decode.run(d, decode.int) {
      Ok(n) -> #(Model(..model, rating: n), command.none())
      Error(_) -> #(model, command.none())
    }
  }
  _ -> #(model, command.none())
}
```

`kind` names the event family. `target.id` identifies the widget
instance. `data` is the `Dynamic` payload passed to `Emit`, which you
decode with the standard `gleam/dynamic/decode` helpers. See the
[Events reference](../reference/events.md) for the full `CustomWidget`
pattern-matching cookbook.

Custom event kinds accepted from the renderer must start with a
lowercase ASCII letter and may contain lowercase ASCII letters,
digits, `_`, or `:`. Examples: `change`, `canvas_scroll`,
`star_rating:select`.

## Widget-scoped subscriptions

A widget can declare its own subscriptions through `WidgetDef.subscriptions`.
The runtime namespaces each timer's tag per instance, so multiple
instances of the same widget do not collide, and routes fired timer
events through the widget's `handle_event` rather than the app's
`update`.

```gleam
import plushie/event.{type Event, Timer, TimerEvent}
import plushie/subscription
import plushie/widget.{type EventAction, Ignored, UpdateState}

fn subscriptions(_props: Nil, state: ToggleState) -> List(Subscription) {
  case state.progress != state.target {
    True -> [subscription.every(16, "animate")]
    False -> []
  }
}

fn handle_event(
  ev: Event,
  state: ToggleState,
) -> #(EventAction, ToggleState) {
  case ev {
    Timer(TimerEvent(tag: "animate", ..)) -> #(
      UpdateState,
      ToggleState(..state, progress: step_toward(state.progress, state.target)),
    )
    _ -> #(Ignored, state)
  }
}
```

The subscription list is recomputed after every `update` and diffed
against the previous list, so animation timers stop automatically when
`progress == target`. See the [Subscriptions
reference](../reference/subscriptions.md) for the diffing lifecycle.

## Canvas-based widgets

A custom widget's `view` can return any `Node`, including a canvas.
Canvas gives you drawing primitives (paths, shapes, text, transforms)
and per-shape interactivity, which is everything you need for gauges,
sparklines, colour pickers, and small data visualisations.

```gleam
import plushie/canvas/shape
import plushie/prop/length.{Fixed}
import plushie/widget/canvas

fn view(id: String, props: GaugeProps, _state: Nil) -> Node {
  let pct = float.min(props.value /. props.max, 1.0)
  let track = shape.path(arc(60.0, 60.0, 50.0, 180.0, 0.0), [
    shape.Stroke(shape.stroke("#ddd", 8.0, [])),
  ])
  let fill = shape.path(arc(60.0, 60.0, 50.0, 180.0, 180.0 +. pct *. 180.0), [
    shape.Stroke(shape.stroke("#3b82f6", 8.0, [])),
  ])

  canvas.new(id, Fixed(120.0), Fixed(70.0))
  |> canvas.layers(dict.from_list([#("gauge", [track, fill])]))
  |> canvas.build()
}
```

Shape-level interactivity (`OnClick`, `OnHover`) delivers
`Widget(Click)`, `Widget(Press)`, and friends scoped to the shape's
local ID, which `handle_event` matches the same way as any other
child widget. The star rating, colour picker, and animated theme
toggle in `examples/widgets/` are full working implementations. See
the [Canvas reference](../reference/canvas.md) for the drawing
primitives.

## Widget lifecycle

There are no explicit mount or unmount callbacks. **Tree presence is
the lifecycle.** When a widget's placeholder appears in the tree, the
runtime calls `init` and stores the state keyed by the widget's scoped
ID. When the placeholder disappears, the state is discarded.

This is why widget IDs must be stable. A changing ID looks like a
removal followed by a new instance: state resets and timers restart.

Behind the scenes: `widget.build` returns a placeholder `Node` tagged
with the definition and props. During normalisation the runtime
detects the placeholder, looks up stored state (or calls `init`), and
calls `view`. The rendered subtree replaces the placeholder, and
`widget.derive_registry` walks the normalised tree to rebuild the
widget registry used for event dispatch and subscription collection.

## Native widgets

When pure Gleam composition and canvas are not enough (custom GPU
drawing, platform-specific input like IME composition or tablet
pressure, heavy per-frame computation) you can build a **native
widget** backed by Rust. The Gleam side declares the interface; the
Rust crate implements rendering and event emission inside the
renderer.

```gleam
import plushie/native_widget

pub const gauge_def = native_widget.NativeDef(
  kind: "gauge",
  rust_crate: "native/gauge",
  rust_constructor: "gauge::GaugeExtension::new()",
  props: [
    native_widget.NumberProp("value"),
    native_widget.NumberProp("min"),
    native_widget.NumberProp("max"),
    native_widget.ColorProp("color"),
    native_widget.LengthProp("width"),
  ],
  commands: [
    native_widget.CommandDef("set_value", [
      native_widget.NumberParam("value"),
    ]),
  ],
)
```

`NativeDef` names the widget kind (which must match the Rust crate's
registered type), points at the Rust crate, lists props for validation,
and lists any commands the renderer-side widget accepts. Use
`native_widget.build(def, id, props)` to create a node and
`native_widget.command(def, node_id, op, payload)` to send a command
to a specific instance. Operations must be listed in `def.commands`;
unknown operations do not send anything, and a batch with any unknown
operation is dropped as a whole.

The Rust crate implements the `PlushieWidget` trait. The crate's own
`Cargo.toml` declares the widget under
`[package.metadata.plushie.widget]`:

```toml
[package.metadata.plushie.widget]
type_name = "gauge"
constructor = "gauge::GaugeExtension::new()"
```

Wire the crate into your app by adding it to `gleam.toml`:

```toml
[plushie]
native_widgets = ["native/gauge"]
```

`gleam run -m plushie/build` reads the list, generates a virtual
renderer crate with the widget crates as path dependencies, and
invokes `cargo-plushie` to produce the renderer binary. See the
[Custom Widgets reference](../reference/custom-widgets.md) for the
full Rust trait and command payload details, and the plushie-demos
repository's gauge-demo for a minimal end-to-end crate layout.

Native widgets are an escape hatch. Most apps never need them. When a
profiler points at canvas drawing or when the problem is fundamentally
not expressible as canvas shapes, reach for native. Otherwise, prefer
composite widgets; they hot-reload, run under the JavaScript target,
and ship without a Rust toolchain.

## Try it

Custom widgets to build next in the pad:

- Extract the preview pane into a widget that takes the compiled
  experiment module and renders it.
- Add a `CollapsiblePanel` widget using `widget.with_handler` and
  `Emit` to tell the parent when it expands or collapses.
- Wrap an animated widget (a sparkline of recent events) that uses
  `subscriptions` to drive a timer only while the log is expanded.
- Build a mini colour swatch widget that emits a hex string on click.

Next: [State Management](14-state-management.md)
