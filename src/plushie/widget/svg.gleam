//// SVG display widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/content_fit.{type ContentFit}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Svg {
  Svg(
    id: String,
    source: String,
    width: Option(Length),
    height: Option(Length),
    content_fit: Option(ContentFit),
    rotation: Option(Float),
    opacity: Option(Float),
    color: Option(Color),
    alt: Option(String),
    description: Option(String),
    decorative: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, source: String) -> Svg {
  Svg(
    id:,
    source:,
    width: None,
    height: None,
    content_fit: None,
    rotation: None,
    opacity: None,
    color: None,
    alt: None,
    description: None,
    decorative: None,
    a11y: None,
  )
}

pub fn width(s: Svg, w: Length) -> Svg {
  Svg(..s, width: option.Some(w))
}

pub fn height(s: Svg, h: Length) -> Svg {
  Svg(..s, height: option.Some(h))
}

pub fn content_fit(s: Svg, cf: ContentFit) -> Svg {
  Svg(..s, content_fit: option.Some(cf))
}

pub fn rotation(s: Svg, r: Float) -> Svg {
  Svg(..s, rotation: option.Some(r))
}

pub fn opacity(s: Svg, o: Float) -> Svg {
  Svg(..s, opacity: option.Some(o))
}

pub fn color(s: Svg, c: Color) -> Svg {
  Svg(..s, color: option.Some(c))
}

pub fn alt(s: Svg, a: String) -> Svg {
  Svg(..s, alt: option.Some(a))
}

pub fn description(s: Svg, d: String) -> Svg {
  Svg(..s, description: option.Some(d))
}

pub fn decorative(s: Svg, d: Bool) -> Svg {
  Svg(..s, decorative: option.Some(d))
}

pub fn a11y(s: Svg, a: A11y) -> Svg {
  Svg(..s, a11y: option.Some(a))
}

pub fn build(s: Svg) -> Node {
  let props =
    dict.new()
    |> build.put_string("source", s.source)
    |> build.put_optional("width", s.width, length.to_prop_value)
    |> build.put_optional("height", s.height, length.to_prop_value)
    |> build.put_optional(
      "content_fit",
      s.content_fit,
      content_fit.to_prop_value,
    )
    |> build.put_optional_float("rotation", s.rotation)
    |> build.put_optional_float("opacity", s.opacity)
    |> build.put_optional("color", s.color, color.to_prop_value)
    |> build.put_optional_string("alt", s.alt)
    |> build.put_optional_string("description", s.description)
    |> build.put_optional_bool("decorative", s.decorative)
    |> build.put_optional("a11y", s.a11y, a11y.to_prop_value)
  Node(id: s.id, kind: "svg", props:, children: [])
}
