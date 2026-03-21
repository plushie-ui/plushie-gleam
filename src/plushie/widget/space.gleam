//// Space widget builder (flexible space for layout).

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Space {
  Space(
    id: String,
    width: Option(Length),
    height: Option(Length),
    a11y: Option(A11y),
  )
}

/// Create a new space builder.
pub fn new(id: String) -> Space {
  Space(id:, width: None, height: None, a11y: None)
}

/// Set the width.
pub fn width(s: Space, w: Length) -> Space {
  Space(..s, width: option.Some(w))
}

/// Set the height.
pub fn height(s: Space, h: Length) -> Space {
  Space(..s, height: option.Some(h))
}

/// Set accessibility properties for this widget.
pub fn a11y(s: Space, a: A11y) -> Space {
  Space(..s, a11y: option.Some(a))
}

/// Build the space into a renderable Node.
pub fn build(s: Space) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", s.width, length.to_prop_value)
    |> build.put_optional("height", s.height, length.to_prop_value)
    |> build.put_optional("a11y", s.a11y, a11y.to_prop_value)
  Node(id: s.id, kind: "space", props:, children: [])
}
