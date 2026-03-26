//// Container widget builder (generic layout and styling).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, type PropValue, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/border.{type Border}
import plushie/prop/color.{type Color}
import plushie/prop/gradient.{type Gradient}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/prop/shadow.{type Shadow}
import plushie/widget/build

/// Background can be a solid color or a gradient.
pub type Background {
  ColorBackground(Color)
  GradientBackground(Gradient)
}

pub opaque type Container {
  Container(
    id: String,
    children: List(Node),
    padding: Option(Padding),
    width: Option(Length),
    height: Option(Length),
    max_width: Option(Float),
    max_height: Option(Float),
    center: Option(Bool),
    clip: Option(Bool),
    align_x: Option(Alignment),
    align_y: Option(Alignment),
    background: Option(Background),
    color: Option(Color),
    border: Option(Border),
    shadow: Option(Shadow),
    style: Option(String),
    a11y: Option(A11y),
  )
}

/// Create a new container builder.
pub fn new(id: String) -> Container {
  Container(
    id:,
    children: [],
    padding: None,
    width: None,
    height: None,
    max_width: None,
    max_height: None,
    center: None,
    clip: None,
    align_x: None,
    align_y: None,
    background: None,
    color: None,
    border: None,
    shadow: None,
    style: None,
    a11y: None,
  )
}

/// Set the padding.
pub fn padding(c: Container, p: Padding) -> Container {
  Container(..c, padding: option.Some(p))
}

/// Set the width.
pub fn width(c: Container, w: Length) -> Container {
  Container(..c, width: option.Some(w))
}

/// Set the height.
pub fn height(c: Container, h: Length) -> Container {
  Container(..c, height: option.Some(h))
}

/// Set the maximum width.
pub fn max_width(c: Container, m: Float) -> Container {
  Container(..c, max_width: option.Some(m))
}

/// Set the maximum height in pixels.
pub fn max_height(c: Container, m: Float) -> Container {
  Container(..c, max_height: option.Some(m))
}

/// Set whether content is centered.
pub fn center(c: Container, enabled: Bool) -> Container {
  Container(..c, center: option.Some(enabled))
}

/// Set whether overflowing content is clipped.
pub fn clip(c: Container, enabled: Bool) -> Container {
  Container(..c, clip: option.Some(enabled))
}

/// Set the horizontal alignment.
pub fn align_x(c: Container, a: Alignment) -> Container {
  Container(..c, align_x: option.Some(a))
}

/// Set the vertical alignment.
pub fn align_y(c: Container, a: Alignment) -> Container {
  Container(..c, align_y: option.Some(a))
}

/// Set a solid color background.
pub fn background(c: Container, col: Color) -> Container {
  Container(..c, background: option.Some(ColorBackground(col)))
}

/// Set a gradient background.
pub fn gradient_background(c: Container, g: Gradient) -> Container {
  Container(..c, background: option.Some(GradientBackground(g)))
}

/// Set the color.
pub fn color(c: Container, col: Color) -> Container {
  Container(..c, color: option.Some(col))
}

/// Set the border.
pub fn border(c: Container, b: Border) -> Container {
  Container(..c, border: option.Some(b))
}

/// Set the shadow.
pub fn shadow(c: Container, s: Shadow) -> Container {
  Container(..c, shadow: option.Some(s))
}

/// Set the style.
pub fn style(c: Container, s: String) -> Container {
  Container(..c, style: option.Some(s))
}

/// Add a child node.
pub fn push(c: Container, child: Node) -> Container {
  Container(..c, children: list.append(c.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(c: Container, children: List(Node)) -> Container {
  Container(..c, children: list.append(c.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(c: Container, a: A11y) -> Container {
  Container(..c, a11y: option.Some(a))
}

/// Option type for container properties.
pub type Opt {
  Padding(Padding)
  Width(Length)
  Height(Length)
  MaxWidth(Float)
  MaxHeight(Float)
  Center(Bool)
  Clip(Bool)
  AlignX(Alignment)
  AlignY(Alignment)
  BgColor(Color)
  BgGradient(Gradient)
  TextColor(Color)
  Border(Border)
  Shadow(Shadow)
  Style(String)
  A11y(A11y)
}

/// Apply a list of options to a container builder.
pub fn with_opts(c: Container, opts: List(Opt)) -> Container {
  list.fold(opts, c, fn(ct, opt) {
    case opt {
      Padding(p) -> padding(ct, p)
      Width(w) -> width(ct, w)
      Height(h) -> height(ct, h)
      MaxWidth(m) -> max_width(ct, m)
      MaxHeight(m) -> max_height(ct, m)
      Center(v) -> center(ct, v)
      Clip(v) -> clip(ct, v)
      AlignX(a) -> align_x(ct, a)
      AlignY(a) -> align_y(ct, a)
      BgColor(col) -> background(ct, col)
      BgGradient(g) -> gradient_background(ct, g)
      TextColor(col) -> color(ct, col)
      Border(b) -> border(ct, b)
      Shadow(s) -> shadow(ct, s)
      Style(s) -> style(ct, s)
      A11y(a) -> a11y(ct, a)
    }
  })
}

fn background_to_prop_value(bg: Background) -> PropValue {
  case bg {
    ColorBackground(col) -> color.to_prop_value(col)
    GradientBackground(g) -> gradient.to_prop_value(g)
  }
}

/// Build the container into a renderable Node.
pub fn build(c: Container) -> Node {
  let props =
    dict.new()
    |> build.put_optional("padding", c.padding, padding.to_prop_value)
    |> build.put_optional("width", c.width, length.to_prop_value)
    |> build.put_optional("height", c.height, length.to_prop_value)
    |> build.put_optional_float("max_width", c.max_width)
    |> build.put_optional_float("max_height", c.max_height)
    |> build.put_optional_bool("center", c.center)
    |> build.put_optional_bool("clip", c.clip)
    |> build.put_optional("align_x", c.align_x, alignment.to_prop_value)
    |> build.put_optional("align_y", c.align_y, alignment.to_prop_value)
    |> build.put_optional("background", c.background, background_to_prop_value)
    |> build.put_optional("color", c.color, color.to_prop_value)
    |> build.put_optional("border", c.border, border.to_prop_value)
    |> build.put_optional("shadow", c.shadow, shadow.to_prop_value)
    |> build.put_optional_string("style", c.style)
    |> build.put_optional("a11y", c.a11y, a11y.to_prop_value)
  Node(
    id: c.id,
    kind: "container",
    props:,
    children: c.children,
    meta: dict.new(),
  )
}
