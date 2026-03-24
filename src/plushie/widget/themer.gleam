//// Themer widget builder (per-subtree theme override).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/theme.{type Theme}
import plushie/widget/build

pub opaque type Themer {
  Themer(id: String, children: List(Node), theme: Theme, a11y: Option(A11y))
}

/// Create a new themer builder.
pub fn new(id: String, t: Theme) -> Themer {
  Themer(id:, children: [], theme: t, a11y: None)
}

/// Add a child node.
pub fn push(th: Themer, child: Node) -> Themer {
  Themer(..th, children: list.append(th.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(th: Themer, children: List(Node)) -> Themer {
  Themer(..th, children: list.append(th.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(th: Themer, a: A11y) -> Themer {
  Themer(..th, a11y: option.Some(a))
}

/// Option type for themer properties.
pub type Opt {
  A11y(A11y)
}

/// Apply a list of options to a themer builder.
pub fn with_opts(th: Themer, opts: List(Opt)) -> Themer {
  list.fold(opts, th, fn(t, opt) {
    case opt {
      A11y(a) -> a11y(t, a)
    }
  })
}

/// Build the themer into a renderable Node.
pub fn build(th: Themer) -> Node {
  let props =
    dict.new()
    |> dict.insert("theme", theme.to_prop_value(th.theme))
    |> build.put_optional("a11y", th.a11y, a11y.to_prop_value)
  Node(id: th.id, kind: "themer", props:, children: th.children)
}
