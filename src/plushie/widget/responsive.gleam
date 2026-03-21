//// Responsive layout widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Responsive {
  Responsive(
    id: String,
    children: List(Node),
    width: Option(Length),
    height: Option(Length),
    a11y: Option(A11y),
  )
}

/// Create a new responsive builder.
pub fn new(id: String) -> Responsive {
  Responsive(id:, children: [], width: None, height: None, a11y: None)
}

/// Set the width.
pub fn width(r: Responsive, w: Length) -> Responsive {
  Responsive(..r, width: option.Some(w))
}

/// Set the height.
pub fn height(r: Responsive, h: Length) -> Responsive {
  Responsive(..r, height: option.Some(h))
}

/// Add a child node.
pub fn push(r: Responsive, child: Node) -> Responsive {
  Responsive(..r, children: list.append(r.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(r: Responsive, children: List(Node)) -> Responsive {
  Responsive(..r, children: list.append(r.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(r: Responsive, a: A11y) -> Responsive {
  Responsive(..r, a11y: option.Some(a))
}

/// Build the responsive into a renderable Node.
pub fn build(r: Responsive) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", r.width, length.to_prop_value)
    |> build.put_optional("height", r.height, length.to_prop_value)
    |> build.put_optional("a11y", r.a11y, a11y.to_prop_value)
  Node(id: r.id, kind: "responsive", props:, children: r.children)
}
