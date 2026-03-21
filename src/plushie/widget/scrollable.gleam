//// Scrollable widget builder (scrollable viewport container).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/anchor.{type Anchor}
import plushie/prop/color.{type Color}
import plushie/prop/direction.{type Direction}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Scrollable {
  Scrollable(
    id: String,
    children: List(Node),
    width: Option(Length),
    height: Option(Length),
    direction: Option(Direction),
    spacing: Option(Int),
    scrollbar_width: Option(Float),
    scrollbar_margin: Option(Float),
    scroller_width: Option(Float),
    anchor: Option(Anchor),
    on_scroll: Option(Bool),
    auto_scroll: Option(Bool),
    scrollbar_color: Option(Color),
    scroller_color: Option(Color),
    a11y: Option(A11y),
  )
}

/// Create a new scrollable builder.
pub fn new(id: String) -> Scrollable {
  Scrollable(
    id:,
    children: [],
    width: None,
    height: None,
    direction: None,
    spacing: None,
    scrollbar_width: None,
    scrollbar_margin: None,
    scroller_width: None,
    anchor: None,
    on_scroll: None,
    auto_scroll: None,
    scrollbar_color: None,
    scroller_color: None,
    a11y: None,
  )
}

/// Set the width.
pub fn width(s: Scrollable, w: Length) -> Scrollable {
  Scrollable(..s, width: option.Some(w))
}

/// Set the height.
pub fn height(s: Scrollable, h: Length) -> Scrollable {
  Scrollable(..s, height: option.Some(h))
}

/// Set the direction.
pub fn direction(s: Scrollable, d: Direction) -> Scrollable {
  Scrollable(..s, direction: option.Some(d))
}

/// Set the spacing between children.
pub fn spacing(s: Scrollable, sp: Int) -> Scrollable {
  Scrollable(..s, spacing: option.Some(sp))
}

/// Set the scrollbar width.
pub fn scrollbar_width(s: Scrollable, w: Float) -> Scrollable {
  Scrollable(..s, scrollbar_width: option.Some(w))
}

/// Set the scrollbar margin.
pub fn scrollbar_margin(s: Scrollable, m: Float) -> Scrollable {
  Scrollable(..s, scrollbar_margin: option.Some(m))
}

/// Set the scroller (thumb) width.
pub fn scroller_width(s: Scrollable, w: Float) -> Scrollable {
  Scrollable(..s, scroller_width: option.Some(w))
}

/// Set the scroll anchor.
pub fn anchor(s: Scrollable, a: Anchor) -> Scrollable {
  Scrollable(..s, anchor: option.Some(a))
}

/// Enable the scroll event.
pub fn on_scroll(s: Scrollable, enabled: Bool) -> Scrollable {
  Scrollable(..s, on_scroll: option.Some(enabled))
}

/// Set whether auto-scroll is enabled.
pub fn auto_scroll(s: Scrollable, enabled: Bool) -> Scrollable {
  Scrollable(..s, auto_scroll: option.Some(enabled))
}

/// Set the scrollbar track color.
pub fn scrollbar_color(s: Scrollable, c: Color) -> Scrollable {
  Scrollable(..s, scrollbar_color: option.Some(c))
}

/// Set the scroller (thumb) color.
pub fn scroller_color(s: Scrollable, c: Color) -> Scrollable {
  Scrollable(..s, scroller_color: option.Some(c))
}

/// Add a child node.
pub fn push(s: Scrollable, child: Node) -> Scrollable {
  Scrollable(..s, children: list.append(s.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(s: Scrollable, children: List(Node)) -> Scrollable {
  Scrollable(..s, children: list.append(s.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(s: Scrollable, a: A11y) -> Scrollable {
  Scrollable(..s, a11y: option.Some(a))
}

/// Build the scrollable into a renderable Node.
pub fn build(s: Scrollable) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", s.width, length.to_prop_value)
    |> build.put_optional("height", s.height, length.to_prop_value)
    |> build.put_optional("direction", s.direction, direction.to_prop_value)
    |> build.put_optional_int("spacing", s.spacing)
    |> build.put_optional_float("scrollbar_width", s.scrollbar_width)
    |> build.put_optional_float("scrollbar_margin", s.scrollbar_margin)
    |> build.put_optional_float("scroller_width", s.scroller_width)
    |> build.put_optional("anchor", s.anchor, anchor.to_prop_value)
    |> build.put_optional_bool("on_scroll", s.on_scroll)
    |> build.put_optional_bool("auto_scroll", s.auto_scroll)
    |> build.put_optional(
      "scrollbar_color",
      s.scrollbar_color,
      color.to_prop_value,
    )
    |> build.put_optional(
      "scroller_color",
      s.scroller_color,
      color.to_prop_value,
    )
    |> build.put_optional("a11y", s.a11y, a11y.to_prop_value)
  Node(id: s.id, kind: "scrollable", props:, children: s.children)
}
