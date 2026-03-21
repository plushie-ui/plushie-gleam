//// Markdown display widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Markdown {
  Markdown(
    id: String,
    content: String,
    width: Option(Length),
    text_size: Option(Float),
    h1_size: Option(Float),
    h2_size: Option(Float),
    h3_size: Option(Float),
    code_size: Option(Float),
    spacing: Option(Float),
    link_color: Option(Color),
    code_theme: Option(String),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, content: String) -> Markdown {
  Markdown(
    id:,
    content:,
    width: None,
    text_size: None,
    h1_size: None,
    h2_size: None,
    h3_size: None,
    code_size: None,
    spacing: None,
    link_color: None,
    code_theme: None,
    style: None,
    a11y: None,
  )
}

pub fn width(md: Markdown, w: Length) -> Markdown {
  Markdown(..md, width: option.Some(w))
}

pub fn text_size(md: Markdown, s: Float) -> Markdown {
  Markdown(..md, text_size: option.Some(s))
}

pub fn h1_size(md: Markdown, s: Float) -> Markdown {
  Markdown(..md, h1_size: option.Some(s))
}

pub fn h2_size(md: Markdown, s: Float) -> Markdown {
  Markdown(..md, h2_size: option.Some(s))
}

pub fn h3_size(md: Markdown, s: Float) -> Markdown {
  Markdown(..md, h3_size: option.Some(s))
}

pub fn code_size(md: Markdown, s: Float) -> Markdown {
  Markdown(..md, code_size: option.Some(s))
}

pub fn spacing(md: Markdown, s: Float) -> Markdown {
  Markdown(..md, spacing: option.Some(s))
}

pub fn link_color(md: Markdown, c: Color) -> Markdown {
  Markdown(..md, link_color: option.Some(c))
}

pub fn code_theme(md: Markdown, t: String) -> Markdown {
  Markdown(..md, code_theme: option.Some(t))
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
    |> build.put_optional_float("text_size", md.text_size)
    |> build.put_optional_float("h1_size", md.h1_size)
    |> build.put_optional_float("h2_size", md.h2_size)
    |> build.put_optional_float("h3_size", md.h3_size)
    |> build.put_optional_float("code_size", md.code_size)
    |> build.put_optional_float("spacing", md.spacing)
    |> build.put_optional("link_color", md.link_color, color.to_prop_value)
    |> build.put_optional_string("code_theme", md.code_theme)
    |> build.put_optional_string("style", md.style)
    |> build.put_optional("a11y", md.a11y, a11y.to_prop_value)
  Node(id: md.id, kind: "markdown", props:, children: [])
}
