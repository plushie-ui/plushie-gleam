//// Overlay container widget builder (children stacked on z-axis).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub type OverlayPosition {
  Below
  Above
  OverlayLeft
  OverlayRight
}

pub type OverlayAlign {
  AlignStart
  AlignCenter
  AlignEnd
}

pub opaque type Overlay {
  Overlay(
    id: String,
    children: List(Node),
    position: Option(OverlayPosition),
    gap: Option(Float),
    offset_x: Option(Float),
    offset_y: Option(Float),
    flip: Option(Bool),
    align: Option(OverlayAlign),
    width: Option(Length),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Overlay {
  Overlay(
    id:,
    children: [],
    position: None,
    gap: None,
    offset_x: None,
    offset_y: None,
    flip: None,
    align: None,
    width: None,
    a11y: None,
  )
}

pub fn position(o: Overlay, p: OverlayPosition) -> Overlay {
  Overlay(..o, position: option.Some(p))
}

pub fn gap(o: Overlay, g: Float) -> Overlay {
  Overlay(..o, gap: option.Some(g))
}

pub fn offset_x(o: Overlay, x: Float) -> Overlay {
  Overlay(..o, offset_x: option.Some(x))
}

pub fn offset_y(o: Overlay, y: Float) -> Overlay {
  Overlay(..o, offset_y: option.Some(y))
}

pub fn flip(o: Overlay, f: Bool) -> Overlay {
  Overlay(..o, flip: option.Some(f))
}

pub fn align(o: Overlay, a: OverlayAlign) -> Overlay {
  Overlay(..o, align: option.Some(a))
}

pub fn width(o: Overlay, w: Length) -> Overlay {
  Overlay(..o, width: option.Some(w))
}

/// Add a child node.
pub fn push(o: Overlay, child: Node) -> Overlay {
  Overlay(..o, children: list.append(o.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(o: Overlay, children: List(Node)) -> Overlay {
  Overlay(..o, children: list.append(o.children, children))
}

pub fn a11y(o: Overlay, a: A11y) -> Overlay {
  Overlay(..o, a11y: option.Some(a))
}

fn position_to_string(p: OverlayPosition) -> String {
  case p {
    Below -> "below"
    Above -> "above"
    OverlayLeft -> "left"
    OverlayRight -> "right"
  }
}

fn align_to_string(a: OverlayAlign) -> String {
  case a {
    AlignStart -> "start"
    AlignCenter -> "center"
    AlignEnd -> "end"
  }
}

pub fn build(o: Overlay) -> Node {
  let props =
    dict.new()
    |> build.put_optional("position", o.position, fn(p) {
      StringVal(position_to_string(p))
    })
    |> build.put_optional_float("gap", o.gap)
    |> build.put_optional_float("offset_x", o.offset_x)
    |> build.put_optional_float("offset_y", o.offset_y)
    |> build.put_optional_bool("flip", o.flip)
    |> build.put_optional("align", o.align, fn(a) {
      StringVal(align_to_string(a))
    })
    |> build.put_optional("width", o.width, length.to_prop_value)
    |> build.put_optional("a11y", o.a11y, a11y.to_prop_value)
  Node(id: o.id, kind: "overlay", props:, children: o.children)
}
