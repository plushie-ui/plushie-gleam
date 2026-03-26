# Writing Widget Extensions

Guide for building custom widget extensions for Plushie. Extensions let you
render arbitrary Rust-native widgets (iced widgets, custom `iced::advanced::Widget`
implementations, third-party crates) while keeping your app's state and logic
in Gleam.

## Quick start

An extension has two halves:

1. **Gleam side:** define an `ExtensionDef` from `plushie/extension`. This declares
   the widget's props, commands, and (for native widgets) the Rust crate and
   constructor.

2. **Rust side:** implement the `WidgetExtension` trait from `plushie-ext`. This
   receives tree nodes from Gleam and returns `iced::Element`s for rendering.

<!-- test: extensions_sparkline_def_validates_test, extensions_sparkline_build_creates_node_test -- keep this code block in sync with the test -->
```gleam
// src/my_sparkline.gleam
import plushie/extension.{
  type ExtensionDef, ColorProp, CommandDef, ExtensionDef, NumberProp,
  NumberParam,
}
import plushie/node

pub const sparkline_def = ExtensionDef(
  kind: "sparkline",
  rust_crate: "native/my_sparkline",
  rust_constructor: "my_sparkline::SparklineExtension::new()",
  props: [
    NumberProp("data"),
    ColorProp("color"),
    NumberProp("capacity"),
  ],
  commands: [
    CommandDef("push", [NumberParam("value")]),
  ],
)

pub fn sparkline(id: String, data: List(Float), color: String) -> node.Node {
  extension.build(sparkline_def, id, [
    #("data", node.ListVal(list.map(data, node.FloatVal))),
    #("color", node.StringVal(color)),
  ])
}

pub fn push(node_id: String, value: Float) {
  extension.command(sparkline_def, node_id, "push", [
    #("value", node.FloatVal(value)),
  ])
}
```

```rust
// native/my_sparkline/src/lib.rs
use plushie_ext::prelude::*;

pub struct SparklineExtension;

impl SparklineExtension {
    pub fn new() -> Self { Self }
}

impl WidgetExtension for SparklineExtension {
    fn type_names(&self) -> &[&str] { &["sparkline"] }
    fn config_key(&self) -> &str { "sparkline" }

    fn render<'a>(&self, node: &'a TreeNode, env: &WidgetEnv<'a>) -> Element<'a, Message> {
        let label = prop_str(node, "label").unwrap_or_default();
        text(label).into()
    }
}
```

Build with `gleam run -m plushie/build` (extensions are registered in your build
configuration) or run the renderer binary directly. The `PlushieAppBuilder`
chains `.extension()` calls in the generated `main.rs`:

```rust
plushie::run(
    PlushieAppBuilder::new()
        .extension(my_sparkline::SparklineExtension::new())
)
```

## Extension kinds

### Native widgets -- Rust-backed extensions

Use `ExtensionDef` with `rust_crate` and `rust_constructor` for widgets
rendered by a Rust crate.

<!-- test: extensions_hex_view_validates_test, extensions_hex_view_build_test -- keep this code block in sync with the test -->
```gleam
import plushie/extension.{ExtensionDef, NumberProp, StringProp}

pub const hex_view_def = ExtensionDef(
  kind: "hex_view",
  rust_crate: "native/hex_view",
  rust_constructor: "hex_view::HexViewExtension::new()",
  props: [
    StringProp("data"),
    NumberProp("columns"),
  ],
  commands: [],
)
```

### Composite widgets -- Pure Gleam

Composite widgets are simpler -- they're just functions that return
Node trees. No registration or Rust code needed.

<!-- test: extensions_composite_labeled_input_test -- keep this code block in sync with the test -->
```gleam
import plushie/node.{type Node}
import plushie/ui

// A labeled input composite widget
pub fn labeled_input(
  id: String,
  label: String,
  value: String,
) -> Node {
  ui.column(id, [ui.spacing(4)], [
    ui.text_(id <> "-label", label),
    ui.text_input(id <> "-input", value, []),
  ])
}
```

### Canvas widgets -- canvas-based widgets with internal state

Use `canvas_widget.CanvasWidgetDef` for widgets that render via canvas
shapes, manage their own internal state, and transform raw canvas events
into semantic events. No Rust code needed. This sits between composite
widgets (pure composition, no state) and native widgets (Rust-backed).

Canvas widgets have three capabilities that composite widgets do not:

- **Internal state** -- initialized by `init`, managed by the runtime.
  The widget tree is the source of truth; state is keyed by scoped
  widget ID.
- **Event transformation** -- `handle_event` intercepts events at the
  widget's scope boundary before they reach `app.update`. Raw canvas
  events become semantic events that are indistinguishable from built-in
  widget events.
- **Widget-scoped subscriptions** -- `subscriptions` returns subscriptions
  scoped to this widget instance. Timer events route to `handle_event`,
  not the app's `update`.

```gleam
import gleam/dynamic
import plushie/canvas_widget.{CanvasWidgetDef, Consumed, Emit, Ignored, UpdateState}
import plushie/event.{type Event, CanvasElementClick, CanvasElementEnter, CanvasElementLeave}

type StarState { StarState(hover: String) }
type StarProps { StarProps(rating: Int, max: Int) }

pub fn star_rating_def() -> CanvasWidgetDef(StarState, StarProps) {
  CanvasWidgetDef(
    init: fn() { StarState(hover: "") },
    render: render_stars,
    handle_event: handle_star_event,
    subscriptions: fn(_, _) { [] },
  )
}

fn handle_star_event(ev: Event, state: StarState) -> #(canvas_widget.EventAction, StarState) {
  case ev {
    CanvasElementEnter(element_id:, ..) ->
      #(UpdateState, StarState(..state, hover: element_id))
    CanvasElementLeave(..) ->
      #(UpdateState, StarState(..state, hover: ""))
    CanvasElementClick(element_id:, ..) ->
      // Emit a "select" event -- the runtime fills in id/scope
      // automatically from this widget's position in the tree.
      #(Emit(kind: "select", data: dynamic.from(element_id)), state)
    _ -> #(Ignored, state)
  }
}

// In your view function:
pub fn star_rating(id: String, props: StarProps) -> Node {
  canvas_widget.build(star_rating_def(), id, props)
}
```

#### `handle_event` return values

`handle_event` receives the raw event and the widget's current
internal state. It follows iced's captured/ignored model:

| Action | Effect |
|---|---|
| `Ignored` | Event passes through to the app's `update` unchanged |
| `Consumed` | Event is suppressed -- neither the app nor other widgets see it |
| `UpdateState` | Internal state updated, no output event -- triggers re-render |
| `Emit(kind, data)` | Emit a WidgetEvent with the given family and data; id/scope are filled in by the runtime |

#### Subscriptions

Optional. The `subscriptions` callback returns subscriptions scoped to
this widget instance. Timer events from these subscriptions route to
`handle_event`, not the app's `update`.

```gleam
subscriptions: fn(_props, state) {
  case state.animating {
    True -> [subscription.every(16, "tick")]
    False -> []
  }
}
```

#### Lifecycle

Internal state is initialized by `init` when the widget first appears
in the tree. When the widget is removed from the tree, its state is
cleaned up. Multiple instances of the same canvas widget each get
independent state, keyed by their scoped widget ID.

## DSL reference

| Field | Required | Description |
|---|---|---|
| `kind` | yes | Widget type name string (e.g., `"sparkline"`) |
| `rust_crate` | native only | Path to the Rust crate |
| `rust_constructor` | native only | Rust constructor expression |
| `props` | no | List of `PropDef` values declaring prop types |
| `commands` | no | List of `CommandDef` values (native widgets only) |

### Supported prop types

`NumberProp`, `StringProp`, `BooleanProp`, `ColorProp`, `LengthProp`,
`PaddingProp`, `AlignmentProp`, `FontProp`, `StyleProp`, `MapProp`,
`AnyProp`, `ListProp(name, inner)`

The `a11y` and `event_rate` options are available on all extension
widgets automatically. You do not need to declare them in `props`.

The `a11y` builder supports all standard fields including `disabled`,
`position_in_set`, `size_of_set`, and `has_popup` -- useful when
building accessible composite widgets from extension primitives.

## Extension tiers

Not every extension needs the full trait. The `WidgetExtension` trait has
sensible defaults for all methods except `type_names`, `config_key`, and
`render`. Choose the tier that fits your widget:

### Tier A: render-only (~200 lines)

Implement `type_names`, `config_key`, and `render`. Everything else uses
defaults. Good for widgets that compose existing iced widgets (e.g.
`column`, `row`, `text`, `scrollable`, `container`) with no Rust-side
interaction state.

```rust
impl WidgetExtension for HexViewExtension {
    fn type_names(&self) -> &[&str] { &["hex_view"] }
    fn config_key(&self) -> &str { "hex_view" }

    fn render<'a>(&self, node: &'a TreeNode, env: &WidgetEnv<'a>) -> Element<'a, Message> {
        // Compose standard iced widgets from node props
        let data = prop_str(node, "data").unwrap_or_default();
        // ... build column/row/text layout ...
        container(content).into()
    }
}
```

### Tier B: interactive (+handle_event)

Add `handle_event` to intercept events from your widgets before they reach
Gleam. Use this when the extension needs to process mouse/keyboard input
internally (pan, zoom, hover tracking) or transform events before forwarding.
For example, a canvas-based plotting widget might handle pan/zoom entirely
in Rust while forwarding click events to Gleam as semantic `plot_click`
events.

```rust
fn handle_event(
    &mut self,
    node_id: &str,
    family: &str,
    data: &Value,
    caches: &mut ExtensionCaches,
) -> EventResult {
    match family {
        "canvas_press" => {
            // Transform raw canvas coordinates into plot-space click
            let x = data.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let y = data.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let plot_event = OutgoingEvent::extension_event(
                "plot_click".to_string(),
                node_id.to_string(),
                Some(serde_json::json!({"plot_x": x, "plot_y": y})),
            );
            EventResult::Consumed(vec![plot_event])
        }
        "canvas_move" => {
            // Update hover state internally, don't forward
            EventResult::Consumed(vec![])
        }
        _ => EventResult::PassThrough,
    }
}
```

#### Throttling high-frequency extension events

If your extension emits events on every mouse move or at frame rate,
the host receives far more events than it needs, and over SSH or
slow connections the unthrottled traffic can stall the UI entirely.
The renderer can buffer these and deliver only the latest value (or
accumulated deltas) at a controlled rate. Mark events with a
`CoalesceHint` to opt in. Events without a hint are always delivered
immediately -- the right default for clicks, selections, and other
discrete actions.

```rust
// Latest value wins -- position tracking, state snapshots
let event = OutgoingEvent::extension_event("cursor_pos", node_id, data)
    .with_coalesce(CoalesceHint::Replace);

// Deltas sum -- scroll, velocity, counters
let event = OutgoingEvent::extension_event("pan_scroll", node_id, data)
    .with_coalesce(CoalesceHint::Accumulate(
        vec!["delta_x".into(), "delta_y".into()]
    ));

// No hint -- discrete actions are never coalesced
let event = OutgoingEvent::extension_event("node_selected", node_id, data);
```

The hint declares how to coalesce; `event_rate` on the widget node
controls frequency. Set `event_rate` from Gleam:

```gleam
extension.build(plot_def, "plot1", [
  #("data", chart_data),
  #("event_rate", node.IntVal(30)),
])
```

Both are in the prelude (`CoalesceHint`, `OutgoingEvent`).

### Tier C: full lifecycle (+prepare, handle_command, cleanup)

Add `prepare` for mutable state synchronization before each render pass,
`handle_command` for commands sent from Gleam to the extension, and
`cleanup` for resource teardown when nodes are removed. Typical uses
include ring buffers fed by extension commands with canvas rendering,
generation-tracked cache invalidation, and custom `iced::advanced::Widget`
implementations with viewport state, hit testing, and pan/zoom persisted
in `ExtensionCaches`.

```rust
fn prepare(&mut self, node: &TreeNode, caches: &mut ExtensionCaches, theme: &Theme) {
    // Initialize or sync per-node state.
    // First arg is the namespace (typically config_key()), second is the node ID.
    let state = caches.get_or_insert::<SparklineState>(self.config_key(), &node.id, || {
        SparklineState::new(prop_usize(node, "capacity").unwrap_or(100))
    });
    // Update from props if needed
    state.color = prop_color(node, "color");
}

fn handle_command(
    &mut self,
    node_id: &str,
    op: &str,
    payload: &Value,
    caches: &mut ExtensionCaches,
) -> Vec<OutgoingEvent> {
    match op {
        "push" => {
            if let Some(state) = caches.get_mut::<SparklineState>(self.config_key(), node_id) {
                if let Some(value) = payload.as_f64() {
                    state.push(value as f32);
                    state.generation.bump();
                }
            }
            vec![]
        }
        _ => vec![],
    }
}

fn cleanup(&mut self, node_id: &str, caches: &mut ExtensionCaches) {
    caches.remove(self.config_key(), node_id);
}
```

The full list of trait methods:

| Method | Required | Phase | Receives | Returns |
|---|---|---|---|---|
| `type_names` | yes | registration | -- | `&[&str]` |
| `config_key` | yes | registration | -- | `&str` |
| `init` | no | startup | `&InitCtx<'_>` (ctx.config, ctx.theme, ctx.default_text_size, ctx.default_font) | -- |
| `prepare` | no | mutable (pre-view) | `&TreeNode`, `&mut ExtensionCaches`, `&Theme` | -- |
| `render` | yes | immutable (view) | `&TreeNode`, `&WidgetEnv` | `Element<Message>` |
| `handle_event` | no | update | node_id, family, data, `&mut ExtensionCaches` | `EventResult` |
| `handle_command` | no | update | node_id, op, payload, `&mut ExtensionCaches` | `Vec<OutgoingEvent>` |
| `cleanup` | no | tree diff | node_id, `&mut ExtensionCaches` | -- |

### WidgetEnv / RenderCtx fields

`WidgetEnv` (and the underlying `RenderCtx`) provides access to:

- `env.theme` -- the current iced `Theme`
- `env.window_id` -- the window ID (`&str`) this render pass is for
- `env.scale_factor` -- DPI scale factor (`f32`) for the current window

Extensions doing DPI-aware rendering or per-window adaptation can use
`window_id` and `scale_factor` directly.

### Prelude additions

The `plushie_ext::prelude` now re-exports `alignment`, `Point`, and `Size`,
so you no longer need to reach into `plushie_ext::iced::alignment` for
alignment types.


## Message::Event construction

Extensions that implement custom `iced::advanced::Widget` types need to
publish events back through the extension system. Use the `Message::Event`
variant:

```rust
use plushie_ext::message::Message;
use serde_json::json;

// In your Widget::update() method:
shell.publish(Message::Event(
    self.node_id.clone(),           // node ID (String)
    json!({"key": "value"}),        // event data (serde_json::Value)
    "my_event_family".to_string(),  // family string (String)
));
```

The event flows through the system like this:

```
Widget::update()
  -> shell.publish(Message::Event(id, data, family))
  -> App::update() in renderer.rs
  -> ExtensionDispatcher::handle_event(id, family, data, caches)
  -> your extension's handle_event() method
  -> EventResult determines what reaches Gleam
```

If your extension does not implement `handle_event` (or returns
`EventResult::PassThrough`), the event is serialized as-is and sent to
Gleam over the wire as an `OutgoingEvent` with the family and data you
provided.

### Constructing OutgoingEvent from extensions

When your `handle_event` or `handle_command` needs to emit events to Gleam,
use `OutgoingEvent::extension_event`:

```rust
OutgoingEvent::extension_event(
    "my_custom_family".to_string(),  // family string
    node_id.to_string(),             // node ID
    Some(json!({"detail": 42})),     // optional data payload (None for bare events)
)
```

This is equivalent to `OutgoingEvent::generic(family, id, data)`. The
resulting JSON sent to Gleam looks like:

```json
{"type": "event", "family": "my_custom_family", "id": "node-1", "data": {"detail": 42}}
```


## Event family reference

Every event sent over the wire carries a `family` string that identifies
what kind of interaction produced it. Extension authors need to know these
strings when implementing `handle_event` -- the `family` parameter tells
you what happened.

### Widget events (node ID in `id` field)

These are emitted by built-in widgets. They use dedicated `Message` variants
internally but arrive at extensions via `Message::Event` when the widget is
inside an extension's node tree.

| Family | Source widget | Data fields |
|---|---|---|
| `click` | button | -- |
| `input` | text_input, text_editor | `value`: new text (in `value` field) |
| `submit` | text_input | `value`: current text (in `value` field) |
| `toggle` | checkbox, toggler | `value`: bool (in `value` field) |
| `slide` | slider, vertical_slider | `value`: f64 (in `value` field) |
| `slide_release` | slider, vertical_slider | `value`: f64 (in `value` field) |
| `select` | pick_list, combo_box, radio | `value`: selected string (in `value` field) |
| `open` | pick_list, combo_box | -- |
| `close` | pick_list, combo_box | -- |
| `paste` | text_input | `value`: pasted text (in `value` field) |
| `option_hovered` | combo_box | `value`: hovered option (in `value` field) |
| `sort` | table | `data.column`: column key |
| `key_binding` | text_editor | `data`: binding tag and key data |
| `scroll` | scrollable | `data`: absolute/relative offsets, bounds, content size |

### Canvas events (node ID in `id` field)

Emitted by canvas widgets via `Message::CanvasEvent` and `Message::CanvasScroll`.

| Family | Data fields |
|---|---|
| `canvas_press` | `data.x`, `data.y`, `data.button` |
| `canvas_release` | `data.x`, `data.y`, `data.button` |
| `canvas_move` | `data.x`, `data.y` |
| `canvas_scroll` | `data.x`, `data.y`, `data.delta_x`, `data.delta_y` |
| `canvas_shape_enter` | `data.shape_id`, `data.x`, `data.y` |
| `canvas_shape_leave` | `data.shape_id` |
| `canvas_shape_click` | `data.shape_id`, `data.x`, `data.y`, `data.button` |
| `canvas_shape_drag` | `data.shape_id`, `data.x`, `data.y`, `data.delta_x`, `data.delta_y` |
| `canvas_shape_drag_end` | `data.shape_id`, `data.x`, `data.y` |
| `canvas_shape_focused` | `data.shape_id` |

### MouseArea events (node ID in `id` field)

Emitted by mouse_area widgets.

| Family | Data fields |
|---|---|
| `mouse_right_press` | -- |
| `mouse_right_release` | -- |
| `mouse_middle_press` | -- |
| `mouse_middle_release` | -- |
| `mouse_double_click` | -- |
| `mouse_enter` | -- |
| `mouse_exit` | -- |
| `mouse_move` | `data.x`, `data.y` |
| `mouse_scroll` | `data.delta_x`, `data.delta_y` |

### Sensor events (node ID in `id` field)

| Family | Data fields |
|---|---|
| `sensor_resize` | `data.width`, `data.height` |

### PaneGrid events (grid ID in `id` field)

| Family | Data fields |
|---|---|
| `pane_resized` | `data.split`, `data.ratio` |
| `pane_dragged` | `data.pane`, `data.target` |
| `pane_clicked` | `data.pane` |

### Subscription events (subscription tag in `tag` field, empty `id`)

These are only routed through extensions if the extension widget's node ID
matches. In practice, extensions mostly see the widget-scoped events above.
Listed here for completeness.

| Family | Data fields |
|---|---|
| `key_press` | `modifiers`, `data.key`: key name, `data.modified_key`, `data.physical_key`, `data.location`, `data.text`, `data.repeat` |
| `key_release` | `modifiers`, `data.key`: key name, `data.modified_key`, `data.physical_key`, `data.location` |
| `modifiers_changed` | `data.shift`, `data.ctrl`, `data.alt`, `data.logo`, `data.command` |
| `cursor_moved` | `data.x`, `data.y` |
| `cursor_entered` | -- |
| `cursor_left` | -- |
| `button_pressed` | `data.button` |
| `button_released` | `data.button` |
| `wheel_scrolled` | `data.delta_x`, `data.delta_y`, `data.unit` |
| `finger_pressed` | `data.id`, `data.x`, `data.y` |
| `finger_moved` | `data.id`, `data.x`, `data.y` |
| `finger_lifted` | `data.id`, `data.x`, `data.y` |
| `finger_lost` | `data.id`, `data.x`, `data.y` |
| `ime_opened` | -- |
| `ime_preedit` | `data.text`, `data.cursor` |
| `ime_commit` | `data.text` |
| `ime_closed` | -- |
| `animation_frame` | `data.timestamp_millis` |
| `theme_changed` | `data.mode` |

### Window events (subscription tag in `tag` field)

| Family | Data fields |
|---|---|
| `window_opened` | `data.window_id`, `data.position` |
| `window_closed` | `data.window_id` |
| `window_close_requested` | `data.window_id` |
| `window_moved` | `data.window_id`, `data.x`, `data.y` |
| `window_resized` | `data.window_id`, `data.width`, `data.height` |
| `window_focused` | `data.window_id` |
| `window_unfocused` | `data.window_id` |
| `window_rescaled` | `data.window_id`, `data.scale_factor` |
| `file_hovered` | `data.window_id`, `data.path` |
| `file_dropped` | `data.window_id`, `data.path` |
| `files_hovered_left` | `data.window_id` |


## EventResult guide

`handle_event` returns one of three variants that control event flow:

### PassThrough

"I don't care about this event. Forward it to Gleam as-is."

This is the default. Use it for events your extension doesn't need to
intercept. The original event is serialized and sent over the wire.

```rust
fn handle_event(&mut self, _id: &str, family: &str, _data: &Value, _caches: &mut ExtensionCaches) -> EventResult {
    match family {
        "canvas_press" => { /* handle it */ },
        _ => EventResult::PassThrough,
    }
}
```

### Consumed(events)

"I handled this event. Do NOT forward the original to Gleam. Optionally
emit different events instead."

Use this when the extension fully owns the interaction:

```rust
// Pan/zoom: handle internally, emit nothing to Gleam
EventResult::Consumed(vec![])

// Transform: swallow the raw canvas event, emit a semantic one
EventResult::Consumed(vec![
    OutgoingEvent::extension_event(
        "plot_click".to_string(),
        node_id.to_string(),
        Some(json!({"series": "cpu", "index": 42})),
    )
])
```

**Gotcha: canvas cache invalidation.** If your `handle_event` modifies
visual state (e.g., updates hover position, changes zoom level) and returns
`Consumed(vec![])`, iced will still call `view()` after the update (the
daemon always re-renders after every `update()`). Standard iced widgets
re-render correctly. But if your extension uses `canvas::Cache`, the cache
won't know to clear itself -- you need to invalidate it explicitly via
`GenerationCounter` (see below) or by structuring your `Program::draw()` to
detect the state change.

### Observed(events)

"I handled this event AND forward the original to Gleam. Also emit
additional events."

Use this when both the extension and Gleam need to see the event:

```rust
// Forward the original click AND emit a computed event
EventResult::Observed(vec![
    OutgoingEvent::extension_event(
        "sparkline_sample_clicked".to_string(),
        node_id.to_string(),
        Some(json!({"sample_index": 7, "value": 42.5})),
    )
])
```

The original event is sent first, then the additional events in order.


## canvas::Cache and GenerationCounter

`iced::widget::canvas::Cache` is `!Send + !Sync`. This means it cannot be
stored in `ExtensionCaches` (which requires `Send + Sync + 'static`). This
is a fundamental constraint of iced's rendering architecture, not a bug.

### The pattern

Instead of storing `canvas::Cache` in `ExtensionCaches`, use iced's built-in
tree state mechanism. The cache lives in your `Program::State` (initialized
via `Widget::state()` or `canvas::Program`), and a `GenerationCounter` in
`ExtensionCaches` tracks when your data changes.

```rust
use plushie_ext::prelude::*;
use iced::widget::canvas;

/// Stored in ExtensionCaches (Send + Sync).
struct SparklineData {
    samples: Vec<f32>,
    generation: GenerationCounter,
}

/// Stored in canvas Program::State (not Send, not Sync -- iced manages it).
struct SparklineState {
    last_generation: u64,
    cache: canvas::Cache,
}
```

In `prepare` or `handle_command`, bump the generation when data changes:

```rust
fn handle_command(&mut self, node_id: &str, op: &str, payload: &Value, caches: &mut ExtensionCaches) -> Vec<OutgoingEvent> {
    if op == "push" {
        if let Some(data) = caches.get_mut::<SparklineData>(self.config_key(), node_id) {
            data.samples.push(payload.as_f64().unwrap_or(0.0) as f32);
            data.generation.bump();  // signal that a redraw is needed
        }
    }
    vec![]
}
```

In `draw`, compare generations to decide whether to clear the cache:

```rust
impl canvas::Program<Message> for SparklineProgram<'_> {
    type State = SparklineState;

    fn draw(
        &self,
        state: &Self::State,
        renderer: &iced::Renderer,
        _theme: &Theme,
        bounds: iced::Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<canvas::Geometry> {
        // Check if data has changed since last draw
        if state.last_generation != self.current_generation {
            state.cache.clear();
            // Note: state.last_generation is updated after draw via update()
        }

        let geometry = state.cache.draw(renderer, bounds.size(), |frame| {
            // Draw your content here
        });

        vec![geometry]
    }
}
```

### Why GenerationCounter instead of content hashing

`GenerationCounter` is a simple `u64` counter. Incrementing it is O(1) and
comparing two values is a single integer comparison. Content hashing is
more expensive and harder to get right (what do you hash? serialized JSON?
raw bytes?). The counter approach is the recommended pattern.

`GenerationCounter` implements `Send + Sync + Clone` and stores cleanly in
`ExtensionCaches`. Create it with `GenerationCounter::new()` (starts at 0),
call `.bump()` to increment, and `.get()` to read the current value.


## plushie-iced Widget trait guide

Extensions implementing `iced::advanced::Widget` directly (Tier C) need to
be aware of the plushie-iced API. Several methods changed names and signatures
from earlier versions.

### Key changes

**`on_event` is now `update`:**

```rust
// plushie-iced
fn update(
    &mut self,
    tree: &mut widget::Tree,
    event: iced::Event,
    layout: Layout<'_>,
    cursor: mouse::Cursor,
    renderer: &Renderer,
    clipboard: &mut dyn Clipboard,
    shell: &mut Shell<'_, Message>,
    viewport: &Rectangle,
) -> event::Status {
    // ...
}
```

**Capturing events:** Instead of returning `event::Status::Captured`, call
`shell.capture_event()` and return `event::Status::Captured`:

```rust
// In update():
shell.capture_event();
event::Status::Captured
```

**Alignment fields renamed:**

```rust
// 0.13:
// fn horizontal_alignment(&self) -> alignment::Horizontal
// fn vertical_alignment(&self) -> alignment::Vertical

// 0.14:
fn align_x(&self) -> alignment::Horizontal { ... }
fn align_y(&self) -> alignment::Vertical { ... }
```

Note: the types are different too. `align_x` returns
`alignment::Horizontal`, `align_y` returns `alignment::Vertical`.

**Widget::size() returns Size\<Length\>:**

```rust
fn size(&self) -> iced::Size<Length> {
    iced::Size::new(self.width, self.height)
}
```

**Widget::state() initializes tree state:**

```rust
fn state(&self) -> widget::tree::State {
    widget::tree::State::new(MyWidgetState::default())
}
```

Called once on first mount. The state persists in iced's widget tree and is
accessible in `update()` and `draw()` via `tree.state.downcast_ref::<MyWidgetState>()`.

**Widget::tag() for state type verification:**

```rust
fn tag(&self) -> widget::tree::Tag {
    widget::tree::Tag::of::<MyWidgetState>()
}
```

### Publishing events from custom widgets

Use `shell.publish(Message::Event(...))` as described in the Message::Event
construction section above. The `Message` type is re-exported from
`plushie_ext::prelude`.

### Full Widget skeleton

```rust
use iced::advanced::widget::{self, Widget};
use iced::advanced::{layout, mouse, renderer, Clipboard, Layout, Shell};
use iced::event;
use iced::{Element, Length, Rectangle, Size, Theme};
use plushie_ext::prelude::*;

struct MyWidget<'a> {
    node_id: String,
    node: &'a TreeNode,
}

struct MyWidgetState {
    // your per-instance state
}

impl Default for MyWidgetState {
    fn default() -> Self { Self { /* ... */ } }
}

impl<'a> Widget<Message, Theme, iced::Renderer> for MyWidget<'a> {
    fn tag(&self) -> widget::tree::Tag {
        widget::tree::Tag::of::<MyWidgetState>()
    }

    fn state(&self) -> widget::tree::State {
        widget::tree::State::new(MyWidgetState::default())
    }

    fn size(&self) -> Size<Length> {
        Size::new(Length::Fill, Length::Shrink)
    }

    fn layout(&self, _tree: &mut widget::Tree, _renderer: &iced::Renderer, limits: &layout::Limits) -> layout::Node {
        let size = limits.max();
        layout::Node::new(Size::new(size.width, 200.0))
    }

    fn draw(
        &self,
        tree: &widget::Tree,
        renderer: &mut iced::Renderer,
        theme: &Theme,
        style: &renderer::Style,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        viewport: &Rectangle,
    ) {
        // Draw your widget
    }

    fn update(
        &mut self,
        tree: &mut widget::Tree,
        event: iced::Event,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        renderer: &iced::Renderer,
        clipboard: &mut dyn Clipboard,
        shell: &mut Shell<'_, Message>,
        viewport: &Rectangle,
    ) -> event::Status {
        if let iced::Event::Mouse(mouse::Event::ButtonPressed(mouse::Button::Left)) = &event {
            if cursor.is_over(layout.bounds()) {
                shell.publish(Message::Event(
                    self.node_id.clone(),
                    serde_json::json!({"x": 0, "y": 0}),
                    "my_widget_click".to_string(),
                ));
                shell.capture_event();
                return event::Status::Captured;
            }
        }
        event::Status::Ignored
    }
}

impl<'a> From<MyWidget<'a>> for Element<'a, Message> {
    fn from(w: MyWidget<'a>) -> Self {
        Self::new(w)
    }
}
```


## Prop helpers reference

The `plushie_ext::prop_helpers` module (re-exported via `prelude::*`) provides
typed accessors for reading props from `TreeNode`. Use these instead of
manually traversing `serde_json::Value`:

| Helper | Return type | Notes |
|---|---|---|
| `prop_str(node, key)` | `Option<String>` | |
| `prop_f32(node, key)` | `Option<f32>` | Accepts numbers and numeric strings |
| `prop_f64(node, key)` | `Option<f64>` | Accepts numbers and numeric strings |
| `prop_u32(node, key)` | `Option<u32>` | Rejects negative values |
| `prop_u64(node, key)` | `Option<u64>` | Rejects negative values |
| `prop_usize(node, key)` | `Option<usize>` | Via `prop_u64` |
| `prop_i64(node, key)` | `Option<i64>` | Signed integers |
| `prop_bool(node, key)` | `Option<bool>` | |
| `prop_bool_default(node, key, default)` | `bool` | Returns default when absent |
| `prop_length(node, key, fallback)` | `Length` | Parses "fill", "shrink", numbers, `{fill_portion: n}` |
| `prop_range_f32(node)` | `RangeInclusive<f32>` | Reads `range` prop as `[min, max]`, defaults to `0.0..=100.0` |
| `prop_range_f64(node)` | `RangeInclusive<f64>` | Same as above, f64 |
| `prop_color(node, key)` | `Option<iced::Color>` | Parses `#RRGGBB` / `#RRGGBBAA` hex strings |
| `prop_f32_array(node, key)` | `Option<Vec<f32>>` | Array of numbers |
| `prop_horizontal_alignment(node, key)` | `alignment::Horizontal` | "left"/"center"/"right", defaults Left |
| `prop_vertical_alignment(node, key)` | `alignment::Vertical` | "top"/"center"/"bottom", defaults Top |
| `prop_content_fit(node)` | `Option<ContentFit>` | Reads `content_fit` prop |
| `node.prop_str(key)` | `Option<String>` | Method on `TreeNode` (same as `prop_str`) |
| `node.prop_f32(key)` | `Option<f32>` | Method on `TreeNode` (same as `prop_f32`) |
| `node.prop_bool(key)` | `Option<bool>` | Method on `TreeNode` (same as `prop_bool`) |
| `node.prop_color(key)` | `Option<Color>` | Method on `TreeNode` (same as `prop_color`) |
| `node.prop_padding(key)` | `Padding` | Method on `TreeNode` (same as `prop_padding`) |
| `node.props()` | `Option<&Map>` | Access the props object directly |
| `OutgoingEvent::with_value(value)` | `OutgoingEvent` | Set the `value` field on extension events |
| `PlushieAppBuilder::extension_boxed(ext)` | `PlushieAppBuilder` | Register pre-boxed extensions |
| `f64_to_f32(v)` | `f32` | Clamping f64-to-f32 conversion |
| `prop_padding(node, key)` | `Padding` | Public padding prop helper |


## Testing extensions

### Gleam-side tests

Test your extension's definition and builder functions:

```gleam
import gleeunit/should
import plushie/extension
import plushie/node

pub fn sparkline_def_validates_test() {
  extension.validate(sparkline_def)
  |> should.be_ok()
}

pub fn sparkline_builds_correct_node_test() {
  let node = sparkline("spark-1", [1.0, 2.0, 3.0], "#ff0000")
  should.equal(node.kind, "sparkline")
  should.equal(node.id, "spark-1")
}

pub fn extension_prop_names_test() {
  extension.prop_names(sparkline_def)
  |> should.equal(["data", "color", "capacity"])
}
```

### Rust-side tests

Test pure logic functions, `handle_command`, and `prepare`/`cleanup` using
the helpers from `plushie_ext::testing`:

```rust
#[cfg(test)]
mod tests {
    use plushie_ext::testing::*;
    use super::*;

    #[test]
    fn handle_command_push_adds_sample() {
        let mut ext = SparklineExtension::new();
        let mut caches = ext_caches();

        // Simulate prepare to initialize state
        let n = node_with_props("s-1", "sparkline", json!({"capacity": 10}));
        ext.prepare(&n, &mut caches, &iced::Theme::Dark);

        // Push a sample
        let events = ext.handle_command("s-1", "push", &json!(42.0), &mut caches);
        assert!(events.is_empty());

        let state = caches.get::<SparklineState>("sparkline", "s-1").unwrap();
        assert_eq!(state.samples.len(), 1);
    }

    #[test]
    fn cleanup_removes_state() {
        let mut ext = SparklineExtension::new();
        let mut caches = ext_caches();

        let n = node("s-1", "sparkline");
        ext.prepare(&n, &mut caches, &iced::Theme::Dark);
        assert!(caches.contains("sparkline", "s-1"));

        ext.cleanup("s-1", &mut caches);
        assert!(!caches.contains("sparkline", "s-1"));
    }
}
```

### Render smoke testing

Use `widget_env_with()` from `plushie_ext::testing` to construct a
`WidgetEnv` for smoke-testing your `render()` method. This verifies the
method doesn't panic and returns a valid `Element`:

```rust
#[test]
fn render_does_not_panic() {
    let ext = HexViewExtension::new();
    let wc = widget_caches();
    let ec = ext_caches();
    let images = image_registry();
    let theme = iced::Theme::Dark;
    let disp = dispatcher();

    let env = widget_env_with(&ec, &wc, &images, &theme, &disp);
    let n = node_with_props("hv-1", "hex_view", json!({"data": "AQID"}));

    // Should not panic
    let _element = ext.render(&n, &env);
}
```

### Testing with the test framework

The test framework uses a shared renderer process. Standard test helpers
like `click`, `type_text`, etc. work with extension widget types out of
the box -- the test backend infers events for known widget interaction
patterns.

For integration tests that exercise the full wire protocol round-trip
(including extension commands), build a custom renderer with
`gleam run -m plushie/build` and use the headless backend.


## ExtensionCaches

`ExtensionCaches` is type-erased storage keyed by `(namespace, key)` pairs.
The namespace is typically your extension's `config_key()`, and the key is
the node ID. This is the primary mechanism for persisting state between
`prepare`/`render`/`handle_event`/`handle_command` calls.

Key methods:

| Method | Signature | Notes |
|---|---|---|
| `get::<T>(ns, key)` | `-> Option<&T>` | Immutable access |
| `get_mut::<T>(ns, key)` | `-> Option<&mut T>` | Mutable access |
| `get_or_insert::<T>(ns, key, default_fn)` | `-> &mut T` | Initialize if absent. Replaces on type mismatch. |
| `insert::<T>(ns, key, value)` | `-> ()` | Overwrites existing |
| `remove(ns, key)` | `-> bool` | Returns whether key existed |
| `contains(ns, key)` | `-> bool` | |
| `remove_namespace(ns)` | `-> ()` | Remove all entries for a namespace |

Common keying patterns:

- **Per-node state:** `caches.get::<MyState>(self.config_key(), &node.id)`
- **Per-node sub-keys:** `caches.get::<GenerationCounter>(self.config_key(), &format!("{}:gen", node.id))`
- **Global extension state:** `caches.get::<GlobalConfig>(self.config_key(), "_global")`

The type parameter `T` must be `Send + Sync + 'static`. This is why
`canvas::Cache` (which is `!Send + !Sync`) cannot be stored here.


## Panic isolation

The `ExtensionDispatcher` wraps all mutable extension calls (`init`,
`prepare`, `handle_event`, `handle_command`, `cleanup`) in
`catch_unwind`. If your extension panics:

1. The panic is logged via `log::error!`.
2. The extension is marked as "poisoned".
3. All subsequent calls to the poisoned extension are skipped.
4. `render()` returns a red error placeholder text instead of calling your code.
5. Poisoned state is cleared on the next `Snapshot` message (full tree sync).

This means a bug in one extension cannot crash the renderer or affect other
extensions. But it also means panics are unrecoverable until the next
snapshot -- design your extension to avoid panics in production.

**Note:** `render()` panics ARE caught via `catch_unwind` in
`widgets::render()`. When a render panic is caught, the extension is
marked as "poisoned" and subsequent renders skip it, returning a red
error placeholder text until `clear_poisoned()` is called (typically on
the next `Snapshot` message).


## Publishing widget packages

Widget packages come in two tiers:

1. **Pure Gleam** -- compose existing primitives (canvas, column, container,
   etc.) into higher-level widgets. Works with prebuilt renderer binaries.
   No Rust toolchain needed.
2. **Gleam + Rust** -- custom native rendering via a `WidgetExtension`
   trait. Requires a Rust toolchain to compile a custom renderer binary.

The rest of this section covers Tier 1 (pure Gleam packages). For Tier 2,
see the extension quick start and trait reference above.

### When pure Gleam is enough

Canvas + Shape builders cover custom 2D rendering: charts, diagrams,
gauges, sparklines, colour pickers, drawing tools. The overlay widget
enables dropdowns, popovers, and context menus. Style maps provide
per-instance visual customization. Composition of layout primitives
(column, row, container, stack) covers cards, tab bars, sidebars, toolbars,
and other structural patterns.

See [composition-patterns.md](composition-patterns.md) for examples.

Pure Gleam falls short when you need: custom text layout engines, GPU
shaders, platform-native controls (e.g. a native file tree), or
performance-critical rendering that canvas can't handle efficiently.

### Package structure

A plushie widget package is a standard Gleam project:

```
my_widget/
  src/
    my_widget.gleam             # public API (convenience constructors)
    my_widget/
      donut_chart.gleam         # widget builder + node construction
  test/
    my_widget/
      donut_chart_test.gleam    # builder and node output tests
  gleam.toml
```

#### gleam.toml

```toml
name = "my_widget"
version = "0.1.0"

[dependencies]
plushie = ">= 0.1.0"
```

plushie is a compile-time dependency. Your package does not need the renderer
binary -- it only uses plushie's Gleam modules (`plushie/node`, `plushie/ui`,
`plushie/prop/*`, `plushie/canvas/shape`).

### Building a widget

Write a module that constructs Node trees from built-in node types. The
renderer handles them without modification.

#### Example: DonutChart

A ring chart rendered via canvas:

```gleam
//// A donut chart widget rendered via canvas.
////
//// ## Usage
////
//// ```gleam
//// donut_chart.new("revenue", [
////   Segment("Product A", 45.0, "#3498db"),
////   Segment("Product B", 30.0, "#e74c3c"),
////   Segment("Product C", 25.0, "#2ecc71"),
//// ])
//// |> donut_chart.size(200.0)
//// |> donut_chart.thickness(40.0)
//// |> donut_chart.build()
//// ```

import gleam/float
import gleam/list
import plushie/canvas/shape
import plushie/node.{type Node}
import plushie/prop/length
import plushie/widget/canvas

pub type Segment {
  Segment(label: String, value: Float, color: String)
}

pub opaque type DonutChart {
  DonutChart(
    id: String,
    segments: List(Segment),
    size: Float,
    thickness: Float,
  )
}

pub fn new(id: String, segments: List(Segment)) -> DonutChart {
  DonutChart(id:, segments:, size: 200.0, thickness: 40.0)
}

pub fn size(chart: DonutChart, s: Float) -> DonutChart {
  DonutChart(..chart, size: s)
}

pub fn thickness(chart: DonutChart, t: Float) -> DonutChart {
  DonutChart(..chart, thickness: t)
}

pub fn build(chart: DonutChart) -> Node {
  let arc_shapes = build_arc_shapes(chart)
  canvas.new(chart.id, length.Px(chart.size), length.Px(chart.size))
  |> canvas.layer("arcs", arc_shapes)
  |> canvas.build()
}

fn build_arc_shapes(chart: DonutChart) -> List(shape.Shape) {
  let total =
    list.fold(chart.segments, 0.0, fn(acc, seg) { acc +. seg.value })
  case total == 0.0 {
    True -> []
    False -> {
      let r = chart.size /. 2.0
      let inner_r = r -. chart.thickness
      let pi = 3.14159265358979323846
      let #(shapes, _) =
        list.fold(chart.segments, #([], float.negate(pi) /. 2.0), fn(acc, seg) {
          let #(shapes, start) = acc
          let sweep = seg.value /. total *. 2.0 *. pi
          let stop = start +. sweep
          let arc_shape =
            shape.path([
              shape.arc(r, r, r, start, stop),
              shape.line_to(
                r +. inner_r *. float.cos(stop),
                r +. inner_r *. float.sin(stop),
              ),
              shape.arc(r, r, inner_r, stop, start),
              shape.close(),
            ])
            |> shape.fill(seg.color)
          #([arc_shape, ..shapes], stop)
        })
      list.reverse(shapes)
    }
  }
}
```

Key points:

- The builder follows plushie's pipeline pattern.
- `build` emits a `"canvas"` node with `"layers"` -- a type the stock
  renderer already handles.
- No Rust code. No custom node types. The renderer sees a canvas widget.

#### Convenience constructors

For consumer ergonomics, add a top-level module with functions that mirror
the `plushie/ui` calling conventions:

```gleam
import my_widget/donut_chart.{type Segment}
import plushie/node.{type Node}

/// Creates a donut chart node with default options.
pub fn donut_chart(id: String, segments: List(Segment)) -> Node {
  donut_chart.new(id, segments) |> donut_chart.build()
}
```

Consumers use it like any other widget:

```gleam
import plushie/ui
import my_widget

ui.column("layout", [], [
  ui.text_("heading", "Revenue breakdown"),
  my_widget.donut_chart("revenue", model.segments),
])
```

The result of `donut_chart` is a plain `Node`. It composes naturally
with `ui.column`, `ui.row`, or any other tree builder.

### Testing widget packages

#### Unit tests (no renderer needed)

Test the builder and node output directly:

```gleam
import gleeunit/should
import my_widget/donut_chart.{Segment}

pub fn new_creates_with_defaults_test() {
  let chart = donut_chart.new("c1", [Segment("A", 50.0, "#ff0000")])
  let node = donut_chart.build(chart)
  should.equal(node.kind, "canvas")
  should.equal(node.id, "c1")
}

pub fn size_is_customizable_test() {
  let node =
    donut_chart.new("c1", [Segment("A", 50.0, "#ff0000")])
    |> donut_chart.size(300.0)
    |> donut_chart.build()
  should.equal(node.kind, "canvas")
}
```

#### Integration tests with the test framework

For testing widget behaviour in a running app:

```gleam
import plushie/test
import plushie/ui
import my_widget

fn chart_app() {
  // ... app definition using my_widget.donut_chart ...
}

pub fn chart_renders_in_tree_test() {
  let session = test.start(chart_app())
  let element = test.find(session, "#chart")
  should.equal(element.kind, "canvas")
}
```

### What consumers need to know

Document these in your package README:

1. **Minimum plushie version.** Your package depends on plushie; specify the
   compatible range.
2. **No renderer changes needed.** Pure Gleam packages work with the stock
   plushie binary. Consumers do not need to rebuild anything.
3. **Which built-in features are required.** If your widget uses canvas,
   consumers need the feature enabled (it is by default). Document this if
   it matters.

### Limitations of pure Gleam packages

- **No custom node types.** Your build function must emit node types the stock
  renderer understands (`canvas`, `column`, `container`, etc.).
- **Canvas performance ceiling.** Complex canvas scenes (thousands of shapes,
  60fps animation) may hit limits.
- **No access to iced internals.** You cannot customize widget state
  continuity, keyboard focus, accessibility, or rendering internals.
- **Overlay requires the overlay node type.** If your widget needs popover
  behaviour, it depends on the `overlay` node type being available.

## Demo projects

Complete working examples of native widget extensions:

- [gauge-demo](https://github.com/plushie-ui/plushie-demos/tree/main/gleam/gauge-demo) -- extension with commands (`set_value`, `animate_to`), optimistic updates, typed builder API, and comprehensive test suite
- [sparkline-dashboard](https://github.com/plushie-ui/plushie-demos/tree/main/gleam/sparkline-dashboard) -- render-only canvas extension with timer subscriptions and simulated live data

The same demos exist in [TypeScript](https://github.com/plushie-ui/plushie-demos/tree/main/typescript), [Ruby](https://github.com/plushie-ui/plushie-demos/tree/main/ruby), and [Python](https://github.com/plushie-ui/plushie-demos/tree/main/python). The Rust extension code is identical across languages.
