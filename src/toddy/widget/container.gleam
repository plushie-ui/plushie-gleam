//// Container widget builder (generic layout and styling).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/border.{type Border}
import toddy/prop/color.{type Color}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/prop/shadow.{type Shadow}
import toddy/widget/build

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
    background: Option(Color),
    color: Option(Color),
    border: Option(Border),
    shadow: Option(Shadow),
    style: Option(String),
  )
}

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
  )
}

pub fn padding(c: Container, p: Padding) -> Container {
  Container(..c, padding: option.Some(p))
}

pub fn width(c: Container, w: Length) -> Container {
  Container(..c, width: option.Some(w))
}

pub fn height(c: Container, h: Length) -> Container {
  Container(..c, height: option.Some(h))
}

pub fn max_width(c: Container, m: Float) -> Container {
  Container(..c, max_width: option.Some(m))
}

pub fn max_height(c: Container, m: Float) -> Container {
  Container(..c, max_height: option.Some(m))
}

pub fn center(c: Container, enabled: Bool) -> Container {
  Container(..c, center: option.Some(enabled))
}

pub fn clip(c: Container, enabled: Bool) -> Container {
  Container(..c, clip: option.Some(enabled))
}

pub fn align_x(c: Container, a: Alignment) -> Container {
  Container(..c, align_x: option.Some(a))
}

pub fn align_y(c: Container, a: Alignment) -> Container {
  Container(..c, align_y: option.Some(a))
}

pub fn background(c: Container, col: Color) -> Container {
  Container(..c, background: option.Some(col))
}

pub fn color(c: Container, col: Color) -> Container {
  Container(..c, color: option.Some(col))
}

pub fn border(c: Container, b: Border) -> Container {
  Container(..c, border: option.Some(b))
}

pub fn shadow(c: Container, s: Shadow) -> Container {
  Container(..c, shadow: option.Some(s))
}

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
    |> build.put_optional("background", c.background, color.to_prop_value)
    |> build.put_optional("color", c.color, color.to_prop_value)
    |> build.put_optional("border", c.border, border.to_prop_value)
    |> build.put_optional("shadow", c.shadow, shadow.to_prop_value)
    |> build.put_optional_string("style", c.style)
  Node(id: c.id, kind: "container", props:, children: c.children)
}
