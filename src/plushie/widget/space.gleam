//// Space widget builder (flexible space for layout).

import gleam/dict
import gleam/list
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

/// Option type for space properties.
pub type Opt {
  Width(Length)
  Height(Length)
  A11y(A11y)
}

/// Apply a list of options to a space builder.
pub fn with_opts(s: Space, opts: List(Opt)) -> Space {
  list.fold(opts, s, fn(sp, opt) {
    case opt {
      Width(w) -> width(sp, w)
      Height(h) -> height(sp, h)
      A11y(a) -> a11y(sp, a)
    }
  })
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
