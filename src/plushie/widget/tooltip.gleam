//// Tooltip widget builder. First child is the target, second is tooltip content.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/padding.{type Padding}
import plushie/prop/position.{type Position}
import plushie/widget/build

pub opaque type Tooltip {
  Tooltip(
    id: String,
    children: List(Node),
    tip: String,
    position: Option(Position),
    gap: Option(Float),
    padding: Option(Padding),
    snap_within_viewport: Option(Bool),
    delay: Option(Int),
    style: Option(String),
    a11y: Option(A11y),
  )
}

/// Create a new tooltip builder.
pub fn new(id: String, tip: String) -> Tooltip {
  Tooltip(
    id:,
    children: [],
    tip:,
    position: None,
    gap: None,
    padding: None,
    snap_within_viewport: None,
    delay: None,
    style: None,
    a11y: None,
  )
}

/// Set the position.
pub fn position(tt: Tooltip, p: Position) -> Tooltip {
  Tooltip(..tt, position: option.Some(p))
}

/// Set the gap between elements.
pub fn gap(tt: Tooltip, g: Float) -> Tooltip {
  Tooltip(..tt, gap: option.Some(g))
}

/// Set the padding.
pub fn padding(tt: Tooltip, p: Padding) -> Tooltip {
  Tooltip(..tt, padding: option.Some(p))
}

/// Set whether the tooltip snaps to the viewport.
pub fn snap_within_viewport(tt: Tooltip, enabled: Bool) -> Tooltip {
  Tooltip(..tt, snap_within_viewport: option.Some(enabled))
}

/// Set the delay in milliseconds.
pub fn delay(tt: Tooltip, d: Int) -> Tooltip {
  Tooltip(..tt, delay: option.Some(d))
}

/// Set the style.
pub fn style(tt: Tooltip, s: String) -> Tooltip {
  Tooltip(..tt, style: option.Some(s))
}

/// Add a child node.
pub fn push(tt: Tooltip, child: Node) -> Tooltip {
  Tooltip(..tt, children: list.append(tt.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(tt: Tooltip, children: List(Node)) -> Tooltip {
  Tooltip(..tt, children: list.append(tt.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(tt: Tooltip, a: A11y) -> Tooltip {
  Tooltip(..tt, a11y: option.Some(a))
}

/// Build the tooltip into a renderable Node.
pub fn build(tt: Tooltip) -> Node {
  let props =
    dict.new()
    |> build.put_string("tip", tt.tip)
    |> build.put_optional("position", tt.position, position.to_prop_value)
    |> build.put_optional_float("gap", tt.gap)
    |> build.put_optional("padding", tt.padding, padding.to_prop_value)
    |> build.put_optional_bool("snap_within_viewport", tt.snap_within_viewport)
    |> build.put_optional_int("delay", tt.delay)
    |> build.put_optional_string("style", tt.style)
    |> build.put_optional("a11y", tt.a11y, a11y.to_prop_value)
  Node(id: tt.id, kind: "tooltip", props:, children: tt.children)
}
