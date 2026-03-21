//// Markdown display widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Markdown {
  Markdown(
    id: String,
    content: String,
    width: Option(Length),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, content: String) -> Markdown {
  Markdown(id:, content:, width: None, style: None, a11y: None)
}

pub fn width(md: Markdown, w: Length) -> Markdown {
  Markdown(..md, width: option.Some(w))
}

pub fn style(md: Markdown, s: String) -> Markdown {
  Markdown(..md, style: option.Some(s))
}

pub fn a11y(md: Markdown, a: A11y) -> Markdown {
  Markdown(..md, a11y: option.Some(a))
}

pub fn build(md: Markdown) -> Node {
  let props =
    dict.new()
    |> build.put_string("content", md.content)
    |> build.put_optional("width", md.width, length.to_prop_value)
    |> build.put_optional_string("style", md.style)
    |> build.put_optional("a11y", md.a11y, a11y.to_prop_value)
  Node(id: md.id, kind: "markdown", props:, children: [])
}
