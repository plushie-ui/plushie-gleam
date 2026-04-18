# Custom Widgets

Plushie has two kinds of custom widgets: pure Gleam (compose existing
widgets or draw custom visuals with canvas and SVG) and native
(Rust-backed, for custom GPU rendering).

## Stateless widgets

The simplest custom widget takes props and returns a UI tree:

```gleam
import plushie/widget
import plushie/ui

pub fn labeled_input(id: String, label: String, value: String) {
  ui.column_(id, [
    ui.text(id <> "-label", label),
    ui.text_input("input", value, []),
  ])
}
```

Events from widgets inside pass through transparently to the parent
app's `update` function.

## The widget system

For reusable widgets with state and event handling, use `plushie/widget`:

```gleam
import plushie/widget.{type WidgetDef}

pub fn collapsible_panel(
  id: String,
  title: String,
  children: List(node.Node),
) -> node.Node {
  widget.define(id, widget.WidgetDef(
    view: fn(props, state) {
      // Return a UI tree
    },
    handle_event: fn(event, state) {
      // Return widget.Ignored, widget.Consumed,
      // widget.UpdateState(new_state), or
      // widget.Emit(family, data)
    },
  ))
}
```

## Event handling

The `handle_event` callback intercepts events before they reach the
parent app. Return values:

| Return | Effect |
|---|---|
| `widget.Emit(family, data)` | Emit a new event to the parent |
| `widget.UpdateState(new_state)` | Update internal state silently |
| `widget.Consumed` | Suppress the event entirely |
| `widget.Ignored` | Pass through unchanged |

## Canvas-based widgets

A widget's view function can return a canvas instead of layout widgets.
This is how you build custom controls like colour pickers, gauges, and
data visualizations.

## Native widgets

When you need rendering capabilities beyond what built-in widgets offer,
build a native widget backed by Rust using `plushie/native_widget`.
On the Rust side, implement the `PlushieWidget` trait from
`plushie-widget-sdk`. Use `cargo plushie new-widget <name>` to
scaffold a widget crate with the correct layout.

`gleam run -m plushie/build` hands the project's widget crates to
`cargo-plushie`, which discovers them via `cargo metadata`, wires
them into the renderer, and builds the binary.

See the [Custom Widgets reference](../reference/custom-widgets.md) for
full details.

---

Next: [State Management](14-state-management.md)
