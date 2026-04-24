# Custom Widgets

Plushie supports two ways to define custom widgets: **composite
widgets** (pure Gleam, built from existing widgets) and **native
widgets** (Rust-backed, for custom GPU rendering or specialised
input handling).

Composite widgets are the default. They need no Rust toolchain
and ship as plain Gleam code. Reach for a native widget only
when you need drawing, layout, or input behaviour that the
built-in widgets and canvas can't express.

## Composite widgets

`plushie/widget`

A composite widget is a `WidgetDef(state, props)` record
describing initial state, a view function, an event handler, and
a subscriptions function. The runtime instantiates the widget
per node ID, threads state through renders, and routes events
through the widget handler before delivering them to the app's
`update`.

### The WidgetDef record

```gleam
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

- `init` produces the initial state when the widget first
  appears in the tree.
- `view` builds the widget's node subtree. The first argument
  is the widget's own ID; children should be scoped under it
  (e.g. `id <> "/label"`).
- `handle_event` receives every event that bubbles from the
  widget's subtree before it reaches the app. Return an
  `EventAction` (below) plus the next state.
- `subscriptions` returns subscription specs tied to the
  widget's lifecycle. These are namespaced automatically so
  multiple instances don't collide.
- `cache_key` is reserved for future view memoisation; declaring
  it today has no runtime effect.

### Shorthand constructors

Two helpers cover the common cases:

```gleam
// Stateless, events pass through:
widget.simple(fn(id, props: InputProps) {
  ui.column(id, [], [
    ui.text_(id <> "/label", props.label),
    ui.text_input(id <> "/input", props.value, []),
  ])
})
```

```gleam
// Stateless with an event handler:
widget.with_handler(
  fn(id, props: CardProps) {
    ui.column(id, [], [
      ui.text_(id <> "/title", props.title),
      ui.button_(id <> "/open", "Open"),
    ])
  },
  fn(event) {
    case event {
      Widget(Click(target: EventTarget(id: "open", ..))) ->
        widget.Emit("open", dynamic.nil())
      _ -> widget.Ignored
    }
  },
)
```

For stateful widgets, construct `WidgetDef` directly.

### EventAction

The widget handler returns one of four actions:

| Variant | Meaning |
|---|---|
| `Ignored` | Let the event bubble to the next handler in the scope chain, then to the app |
| `Consumed` | Suppress the event entirely |
| `Emit(kind, data)` | Suppress and replace with `Widget(CustomWidget(kind, target, value, data))`, with `target.id` and `target.scope` filled in from this widget |
| `UpdateState` | Suppress the event but trigger a re-render (the handler already returned a new state) |

Helpers on typed payloads: `widget.emit_string(kind, value)`,
`widget.emit_float`, `widget.emit_int`, `widget.emit_bool`,
`widget.emit_none(kind)`. Each wraps `Emit` with a correctly
encoded `Dynamic`.

### Rendering a composite widget

Build a node from a `WidgetDef` with `widget.build(def, id, props)`.
The runtime recognises the node as a widget placeholder, calls
`def.view` with the current state during normalisation, and
registers the handler in the widget registry so it can intercept
events.

```gleam
fn rate_plushie(id: String, rating: Int) -> Node {
  widget.build(star_rating_def, id, RatingProps(rating: rating))
}

fn view(model) -> List(Node) {
  [
    ui.window("main", [], [
      rate_plushie("stars", model.rating),
    ]),
  ]
}
```

Under the hood each placeholder carries its widget type and a
registry entry that includes the handler and subscription
builders. `widget.derive_registry(tree)` walks a normalised tree
and collects every widget instance's entry; the runtime uses this
to route events and maintain per-widget subscriptions.

### Widget-scoped subscriptions

`WidgetDef.subscriptions(props, state)` returns normal
subscription specs, but the runtime wraps any `Every` timer's
tag so it cannot collide with app-level tags. When a widget
timer fires, the resulting `TimerEvent` is decoded back to the
widget's inner tag and delivered through `handle_event`, not the
app's `update`.

Multiple instances of the same widget definition get independent
subscriptions keyed by widget ID. See the
[Subscriptions reference](subscriptions.md) for the diffing
lifecycle that keeps them in sync.

### CustomWidget events

When a widget emits via `Emit(kind, data)`, the runtime
dispatches `Widget(CustomWidget(kind, target, value, data))` into
the app's `update`. The kind string lets callers pattern-match
per widget instance or per event family:

```gleam
import gleam/dynamic/decode

case event {
  Widget(CustomWidget(kind: "change", target: EventTarget(id: id, ..), data: d, ..)) -> {
    case decode.run(d, decode.field("value", "value", decode.int)) {
      Ok(v) -> Model(..model, values: dict.insert(model.values, id, v))
      Error(_) -> model
    }
  }
  _ -> model
}
```

Custom event kinds accepted from the renderer must start with a
lowercase ASCII letter and may contain lowercase ASCII letters,
digits, `_`, or `:`. Examples: `change`, `canvas_scroll`,
`star_rating:select`.

Cross-link: see the [Events reference](events.md) for the full
`CustomWidget` variant and pattern-matching cookbook.

### State discipline

`state` is arbitrary and opaque to the runtime. Keep it small
and pure; it participates in view memoisation (once enabled) and
gets copied across `handle_event` calls. Any side effects a
custom widget needs should come back through the app via
`Emit(kind, data)`, not via direct mutation.

## Native widgets

`plushie/native_widget`

A native widget is a Rust crate that implements drawing, layout,
and event handling inside the renderer. The Gleam side declares
the widget's interface - kind, props, commands - and delegates
rendering to the Rust crate. Build tooling wires the crate into
the renderer binary so the widget is available at runtime.

Use native widgets when you need:

- Custom GPU rendering beyond what `canvas` can express.
- Platform-specific input (IME composition windows, tablet
  stylus pressure, MIDI).
- Heavy per-frame computation that would be slow in Gleam.

### NativeDef record

```gleam
pub type NativeDef {
  NativeDef(
    kind: String,
    rust_crate: String,
    rust_constructor: String,
    props: List(PropDef),
    commands: List(CommandDef),
  )
}
```

- `kind` is the wire type name. It must match the name the Rust
  crate registers and must not shadow a built-in widget type.
- `rust_crate` is the path to the crate relative to the project
  root (e.g. `"native/my_gauge"`).
- `rust_constructor` is a Rust expression used by the build
  tooling when wiring the crate into the generated renderer
  workspace (e.g. `"my_gauge::GaugeExtension::new()"`). This
  field exists for migration compatibility; modern crates
  declare their metadata in their own `Cargo.toml` under
  `[package.metadata.plushie.widget]`.
- `props` declares the widget's properties for validation and
  documentation.
- `commands` declares the commands the renderer-side widget
  accepts.

### PropDef variants

| Variant | Wire type |
|---|---|
| `NumberProp(name)` | Number |
| `StringProp(name)` | String |
| `BooleanProp(name)` | Bool |
| `ColorProp(name)` | Colour |
| `LengthProp(name)` | Length |
| `PaddingProp(name)` | Padding |
| `AlignmentProp(name)` | Alignment |
| `FontProp(name)` | Font |
| `StyleProp(name)` | Style preset or StyleMap |
| `MapProp(name)` | Generic map |
| `AnyProp(name)` | Any value |
| `ListProp(name, inner)` | List of `inner` |

Reserved prop names (`"id"`, `"type"`, `"children"`, `"a11y"`)
panic at validation.

### CommandDef and ParamDef

```gleam
CommandDef(name: String, params: List(ParamDef))

ParamDef:
  NumberParam(name)
  StringParam(name)
  BooleanParam(name)
```

### Creating nodes

`native_widget.build(def, id, props)` and
`native_widget.build_container(def, id, props, children)`
produce `Node` values. Pass props as a list of `#(key,
PropValue)` pairs already encoded through the relevant prop
module (`length.to_prop_value`, `color.to_prop_value`, etc.).

### Sending commands

`native_widget.command(def, node_id, op, payload)` creates a
single command. `native_widget.commands(def, cmds)` builds a
batch. Both route through the wire protocol's unified
`NativeCommand` / `NativeCommands` path and reach the Rust widget
keyed by node ID. Operations must be declared in `def.commands`.
If a single operation is not declared, no command is sent. If any
operation in a batch is not declared, the whole batch is dropped.

### Validation

`native_widget.validate(def)` returns `Ok(Nil)` or
`Error(errors)` listing:

- Empty `kind`
- Command names that are not safe operation names
- `kind` shadowing a built-in widget type
- Duplicate prop names
- Prop names using reserved keys

Run it in a `main_test` or a module-level `const` assertion to
catch mistakes before the widget reaches the tree.

### Configuring the build

`[plushie]` in `gleam.toml` lists native widget crates under
`native_widgets`. `gleam run -m plushie/build` reads this list,
generates a virtual app crate, and invokes `cargo-plushie` to
build the renderer with the native crates wired in.

Each widget crate must declare
`[package.metadata.plushie.widget]` in its own `Cargo.toml` with
`type_name` and `constructor` keys; the build tooling treats the
crate as the source of truth for widget metadata. See the
[Configuration reference](configuration.md) for the full
gleam.toml layout and the
[CLI Commands reference](cli-commands.md) for the build command.

### Reference implementations

The plushie-demos repo ships small native widgets (gauges,
sparklines, drag panels) that cover the full wiring: crate
layout, `[package.metadata.plushie.widget]` block, Gleam
`NativeDef`, and command payload shapes.

## Composite vs native

| Concern | Composite | Native |
|---|---|---|
| Language | Gleam only | Rust (widget) + Gleam (binding) |
| Build tooling | None | `gleam run -m plushie/build` + Rust toolchain |
| Works under WASM target | Yes | No (WASM builds use built-in widgets only) |
| Event handling | `handle_event` in Gleam | In the Rust crate |
| Drawing primitives | Built-in widgets + canvas | Arbitrary Rust rendering |
| Performance for heavy rendering | Limited by Gleam + canvas | Native GPU throughput |
| Iteration speed | Hot reload friendly | Requires a full renderer rebuild |

Start composite. Only reach for native when a profiler or a
genuinely uncoverable use case forces the move.

## See also

- [Events reference](events.md) - the `Widget(CustomWidget)`
  event shape emitted by composite widgets
- [Subscriptions reference](subscriptions.md) - widget-scoped
  subscription diffing
- [Canvas reference](canvas.md) - the primary escape hatch for
  custom drawing without a native widget
- [CLI Commands reference](cli-commands.md) - `plushie/build`
  and how it discovers native crates
- [Configuration reference](configuration.md) - `[plushie]`
  `native_widgets` in gleam.toml
