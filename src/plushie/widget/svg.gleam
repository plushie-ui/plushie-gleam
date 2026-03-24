//// SVG display widget builder.

import gleam/dict
import gleam/list
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

/// Create a new svg builder.
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

/// Set the width.
pub fn width(s: Svg, w: Length) -> Svg {
  Svg(..s, width: option.Some(w))
}

/// Set the height.
pub fn height(s: Svg, h: Length) -> Svg {
  Svg(..s, height: option.Some(h))
}

/// Set how content is fitted within the widget bounds.
pub fn content_fit(s: Svg, cf: ContentFit) -> Svg {
  Svg(..s, content_fit: option.Some(cf))
}

/// Set the rotation angle in radians.
pub fn rotation(s: Svg, r: Float) -> Svg {
  Svg(..s, rotation: option.Some(r))
}

/// Set the opacity (0.0 to 1.0).
pub fn opacity(s: Svg, o: Float) -> Svg {
  Svg(..s, opacity: option.Some(o))
}

/// Set the color.
pub fn color(s: Svg, c: Color) -> Svg {
  Svg(..s, color: option.Some(c))
}

/// Set the alt text for accessibility.
pub fn alt(s: Svg, a: String) -> Svg {
  Svg(..s, alt: option.Some(a))
}

/// Set the description text for accessibility.
pub fn description(s: Svg, d: String) -> Svg {
  Svg(..s, description: option.Some(d))
}

/// Mark as decorative (ignored by screen readers).
pub fn decorative(s: Svg, d: Bool) -> Svg {
  Svg(..s, decorative: option.Some(d))
}

/// Set accessibility properties for this widget.
pub fn a11y(s: Svg, a: A11y) -> Svg {
  Svg(..s, a11y: option.Some(a))
}

/// Option type for svg properties.
pub type Opt {
  Width(Length)
  Height(Length)
  ContentFit(ContentFit)
  Rotation(Float)
  Opacity(Float)
  Color(Color)
  Alt(String)
  Description(String)
  Decorative(Bool)
  A11y(A11y)
}

/// Apply a list of options to an svg builder.
pub fn with_opts(s: Svg, opts: List(Opt)) -> Svg {
  list.fold(opts, s, fn(sv, opt) {
    case opt {
      Width(w) -> width(sv, w)
      Height(h) -> height(sv, h)
      ContentFit(cf) -> content_fit(sv, cf)
      Rotation(r) -> rotation(sv, r)
      Opacity(o) -> opacity(sv, o)
      Color(c) -> color(sv, c)
      Alt(a) -> alt(sv, a)
      Description(d) -> description(sv, d)
      Decorative(d) -> decorative(sv, d)
      A11y(a) -> a11y(sv, a)
    }
  })
}

/// Build the svg into a renderable Node.
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
