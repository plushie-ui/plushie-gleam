//// Ergonomic UI builder functions.
////
//// Provides convenience functions for building UI trees without
//// importing individual widget modules. Uses an opaque Attr type
//// for widget properties.

import gleam/dict
import gleam/list
import gleam/option.{type Option}
import toddy/node.{
  type Node, type PropValue, BoolVal, DictVal, FloatVal, IntVal, Node, StringVal,
}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/border.{type Border}
import toddy/prop/color.{type Color}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/prop/shadow.{type Shadow}
import toddy/tree

// --- Attr type ---------------------------------------------------------------

/// An opaque attribute for widget properties.
pub opaque type Attr {
  Attr(key: String, value: PropValue)
}

// --- Attribute constructors --------------------------------------------------

pub fn title(t: String) -> Attr {
  Attr("title", StringVal(t))
}

pub fn padding(p: Padding) -> Attr {
  Attr("padding", padding.to_prop_value(p))
}

pub fn spacing(s: Int) -> Attr {
  Attr("spacing", IntVal(s))
}

pub fn width(w: Length) -> Attr {
  Attr("width", length.to_prop_value(w))
}

pub fn height(h: Length) -> Attr {
  Attr("height", length.to_prop_value(h))
}

pub fn max_width(w: Float) -> Attr {
  Attr("max_width", FloatVal(w))
}

pub fn max_height(h: Float) -> Attr {
  Attr("max_height", FloatVal(h))
}

pub fn align_x(a: Alignment) -> Attr {
  Attr("align_x", alignment.to_prop_value(a))
}

pub fn align_y(a: Alignment) -> Attr {
  Attr("align_y", alignment.to_prop_value(a))
}

pub fn background(c: Color) -> Attr {
  Attr("background", color.to_prop_value(c))
}

pub fn text_color(c: Color) -> Attr {
  Attr("color", color.to_prop_value(c))
}

pub fn border(b: Border) -> Attr {
  Attr("border", border.to_prop_value(b))
}

pub fn shadow(s: Shadow) -> Attr {
  Attr("shadow", shadow.to_prop_value(s))
}

pub fn clip(enabled: Bool) -> Attr {
  Attr("clip", BoolVal(enabled))
}

pub fn disabled(d: Bool) -> Attr {
  Attr("disabled", BoolVal(d))
}

pub fn style(s: String) -> Attr {
  Attr("style", StringVal(s))
}

pub fn font_size(s: Float) -> Attr {
  Attr("size", FloatVal(s))
}

pub fn exit_on_close(e: Bool) -> Attr {
  Attr("exit_on_close_request", BoolVal(e))
}

pub fn value(v: String) -> Attr {
  Attr("value", StringVal(v))
}

pub fn placeholder(p: String) -> Attr {
  Attr("placeholder", StringVal(p))
}

pub fn on_submit(enabled: Bool) -> Attr {
  Attr("on_submit", BoolVal(enabled))
}

pub fn secure(s: Bool) -> Attr {
  Attr("secure", BoolVal(s))
}

pub fn window_size(w: Float, h: Float) -> Attr {
  Attr(
    "size",
    DictVal(dict.from_list([#("width", FloatVal(w)), #("height", FloatVal(h))])),
  )
}

// --- Container widgets -------------------------------------------------------

pub fn window(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "window", attrs, children)
}

pub fn column(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "column", attrs, children)
}

pub fn row(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "row", attrs, children)
}

pub fn container(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "container", attrs, children)
}

pub fn scrollable(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "scrollable", attrs, children)
}

pub fn stack(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "stack", attrs, children)
}

pub fn overlay(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "overlay", attrs, children)
}

// --- Leaf widgets ------------------------------------------------------------

pub fn text(id: String, content: String, attrs: List(Attr)) -> Node {
  make_node(id, "text", [Attr("content", StringVal(content)), ..attrs], [])
}

/// Text with no attrs.
pub fn text_(id: String, content: String) -> Node {
  text(id, content, [])
}

pub fn button(id: String, label: String, attrs: List(Attr)) -> Node {
  make_node(id, "button", [Attr("label", StringVal(label)), ..attrs], [])
}

/// Button with no attrs.
pub fn button_(id: String, label: String) -> Node {
  button(id, label, [])
}

pub fn text_input(id: String, val: String, attrs: List(Attr)) -> Node {
  make_node(id, "text_input", [Attr("value", StringVal(val)), ..attrs], [])
}

pub fn checkbox(
  id: String,
  label: String,
  checked: Bool,
  attrs: List(Attr),
) -> Node {
  make_node(
    id,
    "checkbox",
    [
      Attr("label", StringVal(label)),
      Attr("is_toggled", BoolVal(checked)),
      ..attrs
    ],
    [],
  )
}

pub fn slider(
  id: String,
  range: #(Float, Float),
  val: Float,
  attrs: List(Attr),
) -> Node {
  let range_val =
    DictVal(
      dict.from_list([#("min", FloatVal(range.0)), #("max", FloatVal(range.1))]),
    )
  make_node(
    id,
    "slider",
    [Attr("range", range_val), Attr("value", FloatVal(val)), ..attrs],
    [],
  )
}

pub fn image(id: String, source: String, attrs: List(Attr)) -> Node {
  make_node(id, "image", [Attr("source", StringVal(source)), ..attrs], [])
}

pub fn progress_bar(
  id: String,
  range: #(Float, Float),
  val: Float,
  attrs: List(Attr),
) -> Node {
  let range_val =
    DictVal(
      dict.from_list([#("min", FloatVal(range.0)), #("max", FloatVal(range.1))]),
    )
  make_node(
    id,
    "progress_bar",
    [Attr("range", range_val), Attr("value", FloatVal(val)), ..attrs],
    [],
  )
}

/// Flexible space widget.
pub fn space(id: String, attrs: List(Attr)) -> Node {
  make_node(id, "space", attrs, [])
}

/// Horizontal or vertical rule (divider).
pub fn rule(id: String, attrs: List(Attr)) -> Node {
  make_node(id, "rule", attrs, [])
}

// --- Tree query delegates ----------------------------------------------------

pub fn find(tree_node: Node, id: String) -> Option(Node) {
  tree.find(tree_node, id)
}

pub fn exists(tree_node: Node, id: String) -> Bool {
  tree.exists(tree_node, id)
}

// --- Internal ----------------------------------------------------------------

fn make_node(
  id: String,
  kind: String,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  let props =
    list.fold(attrs, dict.new(), fn(acc, attr) {
      dict.insert(acc, attr.key, attr.value)
    })
  Node(id:, kind:, props:, children:)
}
