//// Markdown display widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Markdown {
  Markdown(
    id: String,
    content: String,
    width: Option(Length),
    style: Option(String),
  )
}

pub fn new(id: String, content: String) -> Markdown {
  Markdown(id:, content:, width: None, style: None)
}

pub fn width(md: Markdown, w: Length) -> Markdown {
  Markdown(..md, width: option.Some(w))
}

pub fn style(md: Markdown, s: String) -> Markdown {
  Markdown(..md, style: option.Some(s))
}

pub fn build(md: Markdown) -> Node {
  let props =
    dict.new()
    |> build.put_string("content", md.content)
    |> build.put_optional("width", md.width, length.to_prop_value)
    |> build.put_optional_string("style", md.style)
  Node(id: md.id, kind: "markdown", props:, children: [])
}
