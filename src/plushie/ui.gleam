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

/// Set the window title.
pub fn title(t: String) -> Attr {
  Attr("title", StringVal(t))
}

/// Set padding around the widget content.
pub fn padding(p: Padding) -> Attr {
  Attr("padding", padding.to_prop_value(p))
}

/// Set spacing between child widgets in pixels.
pub fn spacing(s: Int) -> Attr {
  Attr("spacing", IntVal(s))
}

/// Set the widget width.
pub fn width(w: Length) -> Attr {
  Attr("width", length.to_prop_value(w))
}

/// Set the widget height.
pub fn height(h: Length) -> Attr {
  Attr("height", length.to_prop_value(h))
}

/// Set the maximum width in logical pixels.
pub fn max_width(w: Float) -> Attr {
  Attr("max_width", FloatVal(w))
}

/// Set the maximum height in logical pixels.
pub fn max_height(h: Float) -> Attr {
  Attr("max_height", FloatVal(h))
}

/// Set horizontal alignment of the widget or its content.
pub fn align_x(a: Alignment) -> Attr {
  Attr("align_x", alignment.to_prop_value(a))
}

/// Set vertical alignment of the widget or its content.
pub fn align_y(a: Alignment) -> Attr {
  Attr("align_y", alignment.to_prop_value(a))
}

/// Set the widget background color.
pub fn background(c: Color) -> Attr {
  Attr("background", color.to_prop_value(c))
}

/// Set the text color.
pub fn text_color(c: Color) -> Attr {
  Attr("color", color.to_prop_value(c))
}

/// Set the widget border.
pub fn border(b: Border) -> Attr {
  Attr("border", border.to_prop_value(b))
}

/// Set the widget drop shadow.
pub fn shadow(s: Shadow) -> Attr {
  Attr("shadow", shadow.to_prop_value(s))
}

/// Enable or disable content clipping at the widget boundary.
pub fn clip(enabled: Bool) -> Attr {
  Attr("clip", BoolVal(enabled))
}

/// Disable or enable the widget for user interaction.
pub fn disabled(d: Bool) -> Attr {
  Attr("disabled", BoolVal(d))
}

/// Set the widget style class name.
pub fn style(s: String) -> Attr {
  Attr("style", StringVal(s))
}

/// Set the text font size in logical pixels.
pub fn font_size(s: Float) -> Attr {
  Attr("size", FloatVal(s))
}

/// Set whether the application exits when this window is closed.
pub fn exit_on_close(e: Bool) -> Attr {
  Attr("exit_on_close_request", BoolVal(e))
}

/// Set the current value of an input widget.
pub fn value(v: String) -> Attr {
  Attr("value", StringVal(v))
}

/// Set the placeholder text shown when the input is empty.
pub fn placeholder(p: String) -> Attr {
  Attr("placeholder", StringVal(p))
}

/// Enable or disable the on_submit event for text input widgets.
pub fn on_submit(enabled: Bool) -> Attr {
  Attr("on_submit", BoolVal(enabled))
}

/// Enable secure (password) mode for text input, hiding characters.
pub fn secure(s: Bool) -> Attr {
  Attr("secure", BoolVal(s))
}

/// Set accessibility properties on the widget.
pub fn a11y(a: A11y) -> Attr {
  Attr("a11y", a11y.to_prop_value(a))
}

/// Set alt text for an image widget (used by screen readers).
pub fn alt(t: String) -> Attr {
  Attr("alt", StringVal(t))
}

/// Mark an image as decorative (hidden from screen readers).
pub fn decorative(d: Bool) -> Attr {
  Attr("decorative", BoolVal(d))
}

/// Set the label text for a widget.
pub fn label(l: String) -> Attr {
  Attr("label", StringVal(l))
}

/// Set a description for accessibility purposes.
pub fn description(d: String) -> Attr {
  Attr("description", StringVal(d))
}

/// Set the per-widget event rate limit (events per second).
pub fn event_rate(r: Int) -> Attr {
  Attr("event_rate", IntVal(r))
}

/// Set the initial window size in logical pixels.
pub fn window_size(w: Float, h: Float) -> Attr {
  Attr(
    "size",
    DictVal(dict.from_list([#("width", FloatVal(w)), #("height", FloatVal(h))])),
  )
}

// --- Container widgets -------------------------------------------------------

/// Create a window node. Only detected at the root or as a direct child
/// of the root node.
pub fn window(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "window", attrs, children)
}

/// Create a vertical column layout widget.
pub fn column(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "column", attrs, children)
}

/// Create a horizontal row layout widget.
pub fn row(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "row", attrs, children)
}

/// Create a container widget that wraps its children with optional
/// padding, alignment, and sizing.
pub fn container(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "container", attrs, children)
}

/// Create a scrollable container widget.
pub fn scrollable(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "scrollable", attrs, children)
}

/// Create a stack widget that layers children on top of each other.
pub fn stack(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "stack", attrs, children)
}

/// Create an overlay widget for popover-style content.
pub fn overlay(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "overlay", attrs, children)
}

// --- Leaf widgets ------------------------------------------------------------

/// Create a text widget displaying the given content string.
pub fn text(id: String, content: String, attrs: List(Attr)) -> Node {
  make_node(id, "text", [Attr("content", StringVal(content)), ..attrs], [])
}

/// Text with no attrs.
pub fn text_(id: String, content: String) -> Node {
  text(id, content, [])
}

/// Create a button widget with the given label text.
pub fn button(id: String, label: String, attrs: List(Attr)) -> Node {
  make_node(id, "button", [Attr("label", StringVal(label)), ..attrs], [])
}

/// Button with no attrs.
pub fn button_(id: String, label: String) -> Node {
  button(id, label, [])
}

/// Create a single-line text input widget with the given value.
pub fn text_input(id: String, val: String, attrs: List(Attr)) -> Node {
  make_node(id, "text_input", [Attr("value", StringVal(val)), ..attrs], [])
}

/// Create a checkbox widget with the given label and checked state.
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

/// Create a slider widget with the given min/max range and current value.
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

/// Create an image widget from a source path or handle.
pub fn image(id: String, source: String, attrs: List(Attr)) -> Node {
  make_node(id, "image", [Attr("source", StringVal(source)), ..attrs], [])
}

/// Create a progress bar with the given min/max range and current value.
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

/// Create a grid layout widget.
pub fn grid(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "grid", attrs, children)
}

/// Create a keyed column layout for efficient child reconciliation.
pub fn keyed_column(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "keyed_column", attrs, children)
}

// --- Responsive / positional wrappers ----------------------------------------

/// Create a responsive layout widget that adapts to available space.
pub fn responsive(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "responsive", attrs, children)
}

/// Create a pin widget for positioning a child at an absolute offset.
pub fn pin(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "pin", attrs, children)
}

/// Create a floating widget for content that hovers above other widgets.
pub fn floating(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "floating", attrs, children)
}

// --- Interaction wrappers ----------------------------------------------------

/// Create a mouse area widget that captures mouse events on its children.
pub fn mouse_area(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "mouse_area", attrs, children)
}

/// Create a sensor widget that reports its size and position changes.
pub fn sensor(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "sensor", attrs, children)
}

// --- Theme / pane layout -----------------------------------------------------

/// Create a themer widget that applies a local theme to its children.
pub fn themer(
  id: String,
  theme: String,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  make_node(id, "themer", [Attr("theme", StringVal(theme)), ..attrs], children)
}

/// Create a pane grid layout with resizable, splittable panes.
pub fn pane_grid(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  make_node(id, "pane_grid", attrs, children)
}

// --- Tooltip -----------------------------------------------------------------

/// Create a tooltip widget that shows tip text when hovering its children.
pub fn tooltip(
  id: String,
  tip: String,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  make_node(id, "tooltip", [Attr("tip", StringVal(tip)), ..attrs], children)
}

// --- Data / canvas / content widgets -----------------------------------------

/// Create a data table widget.
pub fn table(id: String, attrs: List(Attr)) -> Node {
  make_node(id, "table", attrs, [])
}

/// Create a canvas widget for custom drawing with shapes and paths.
pub fn canvas(id: String, attrs: List(Attr)) -> Node {
  make_node(id, "canvas", attrs, [])
}

/// Create a markdown widget that renders the given markdown content.
pub fn markdown(id: String, content: String, attrs: List(Attr)) -> Node {
  make_node(id, "markdown", [Attr("content", StringVal(content)), ..attrs], [])
}

// --- Tree query delegates ----------------------------------------------------

/// Search the tree for a node with the given ID. Returns None if not found.
pub fn find(tree_node: Node, id: String) -> Option(Node) {
  tree.find(tree_node, id)
}

/// Check whether a node with the given ID exists in the tree.
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
