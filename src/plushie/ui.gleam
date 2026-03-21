//// Ergonomic UI builder functions.
////
//// Provides convenience functions for building UI trees without
//// importing individual widget modules. Uses an opaque Attr type
//// for widget properties.

import gleam/dict
import gleam/list
import gleam/option.{type Option}
import plushie/node.{
  type Node, type PropValue, BoolVal, DictVal, FloatVal, IntVal, Node, StringVal,
}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/border.{type Border}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/prop/shadow.{type Shadow}
import plushie/tree

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

pub fn a11y(a: A11y) -> Attr {
  Attr("a11y", a11y.to_prop_value(a))
}

pub fn alt(t: String) -> Attr {
  Attr("alt", StringVal(t))
}

pub fn decorative(d: Bool) -> Attr {
  Attr("decorative", BoolVal(d))
}

pub fn label(l: String) -> Attr {
  Attr("label", StringVal(l))
}

pub fn description(d: String) -> Attr {
  Attr("description", StringVal(d))
}

pub fn event_rate(r: Int) -> Attr {
  Attr("event_rate", IntVal(r))
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

// --- Grid / keyed layout widgets ---------------------------------------------

pub fn grid(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "grid", attrs, children)
}

pub fn keyed_column(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "keyed_column", attrs, children)
}

// --- Responsive / positional wrappers ----------------------------------------

pub fn responsive(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "responsive", attrs, children)
}

pub fn pin(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "pin", attrs, children)
}

pub fn floating(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "floating", attrs, children)
}

// --- Interaction wrappers ----------------------------------------------------

pub fn mouse_area(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "mouse_area", attrs, children)
}

pub fn sensor(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "sensor", attrs, children)
}

// --- Theme / pane layout -----------------------------------------------------

pub fn themer(
  id: String,
  theme: String,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  make_node(id, "themer", [Attr("theme", StringVal(theme)), ..attrs], children)
}

pub fn pane_grid(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "pane_grid", attrs, children)
}

// --- Tooltip -----------------------------------------------------------------

pub fn tooltip(
  id: String,
  tip: String,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  make_node(id, "tooltip", [Attr("tip", StringVal(tip)), ..attrs], children)
}

// --- Data / canvas / content widgets -----------------------------------------

pub fn table(id: String, attrs: List(Attr)) -> Node {
  make_node(id, "table", attrs, [])
}

pub fn canvas(id: String, attrs: List(Attr)) -> Node {
  make_node(id, "canvas", attrs, [])
}

pub fn markdown(id: String, content: String, attrs: List(Attr)) -> Node {
  make_node(id, "markdown", [Attr("content", StringVal(content)), ..attrs], [])
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
