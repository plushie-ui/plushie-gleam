# Custom Widgets

Plushie has two kinds of custom widgets: **pure Gleam** (compose existing
widgets or draw with canvas) and **native** (Rust-backed).

For a narrative introduction, see the
[Custom Widgets guide](../guides/13-custom-widgets.md).

## Widget system

The `plushie/widget` module provides the widget definition system.
Unlike the Elixir SDK's macro-based approach, Gleam uses data types:

```gleam
import plushie/widget.{type WidgetDef}
import plushie/node

pub fn my_widget(id: String, props: MyProps) -> node.Node {
  widget.define(id, widget.WidgetDef(
    view: fn(id, props, state) { ... },
    handle_event: fn(event, state) { ... },
    initial_state: fn() { ... },
  ))
}
```

## Event handling

The `handle_event` callback intercepts events before they reach the
parent app:

| Return | Effect |
|---|---|
| `widget.Emit(family, data)` | Emit new event to parent |
| `widget.EmitWithState(family, data, state)` | Emit and update state |
| `widget.UpdateState(state)` | Update state silently |
| `widget.Consumed` | Suppress the event |
| `widget.Ignored` | Pass through unchanged |

Events walk the scope chain from innermost to outermost. Each handler
gets a chance. `Ignored` passes to the next handler. If no handler
captures, the event reaches `update`.

## Widget lifecycle

Tree presence is the lifecycle. When a widget appears in the tree, it is
mounted with initial state. When it disappears, its state is cleaned up.
Widget IDs must be stable. A changing ID looks like a removal and
re-creation.

## Widget subscriptions

Widgets can declare their own subscriptions. These are automatically
namespaced per instance.

## Custom widgets are scope-transparent

Custom widget IDs do not create scope boundaries. Children rendered by
a widget inherit the parent container's scope. See
[Scoped IDs](scoped-ids.md).

## Native widgets

For Rust-backed widgets, use `plushie/native_widget`:

```gleam
import plushie/native_widget

pub fn gauge(id: String, value: Float) -> node.Node {
  native_widget.new(id, "gauge", [
    native_widget.Prop("value", node.FloatVal(value)),
  ])
}
```

On the Rust side, implement the `PlushieWidget` trait from
`plushie_widget_sdk::prelude::*`. Scaffold a new widget crate with:

```
cargo plushie new-widget my-gauge
```

This produces the crate layout `cargo-plushie` expects, including
`[package.metadata.plushie.widget]` in the crate's `Cargo.toml`
(with `type_name` and `constructor` keys). List the widget crate
under `[plushie].native_widgets` in `gleam.toml`, then run
`gleam run -m plushie/build`. The SDK generates a virtual app
manifest and hands it to `cargo-plushie`, which discovers the
widget, registers it, and builds the renderer.

## See also

- `plushie/widget` - widget system
- `plushie/native_widget` - native widget definitions
- [Custom Widgets guide](../guides/13-custom-widgets.md)
- [Scoped IDs](scoped-ids.md)
