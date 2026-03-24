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
import plushie/prop/theme.{type Theme}
import plushie/tree
import plushie/widget/button as button_mod
import plushie/widget/canvas as canvas_mod
import plushie/widget/checkbox as checkbox_mod
import plushie/widget/column as column_mod
import plushie/widget/container as container_mod
import plushie/widget/floating as floating_mod
import plushie/widget/grid as grid_mod
import plushie/widget/image as image_mod
import plushie/widget/keyed_column as keyed_column_mod
import plushie/widget/markdown as markdown_mod
import plushie/widget/mouse_area as mouse_area_mod
import plushie/widget/overlay as overlay_mod
import plushie/widget/pane_grid as pane_grid_mod
import plushie/widget/pin as pin_mod
import plushie/widget/progress_bar as progress_bar_mod
import plushie/widget/responsive as responsive_mod
import plushie/widget/row as row_mod
import plushie/widget/rule as rule_mod
import plushie/widget/scrollable as scrollable_mod
import plushie/widget/sensor as sensor_mod
import plushie/widget/slider as slider_mod
import plushie/widget/space as space_mod
import plushie/widget/stack as stack_mod
import plushie/widget/table as table_mod
import plushie/widget/text as text_mod
import plushie/widget/text_input as text_input_mod
import plushie/widget/themer as themer_mod
import plushie/widget/tooltip as tooltip_mod
import plushie/widget/window as window_mod

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
  window_mod.new(id)
  |> window_mod.extend(children)
  |> window_mod.build()
  |> merge_attrs(attrs)
}

/// Create a vertical column layout widget.
pub fn column(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  column_mod.new(id)
  |> column_mod.extend(children)
  |> column_mod.build()
  |> merge_attrs(attrs)
}

/// Create a horizontal row layout widget.
pub fn row(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  row_mod.new(id)
  |> row_mod.extend(children)
  |> row_mod.build()
  |> merge_attrs(attrs)
}

/// Create a container widget that wraps its children with optional
/// padding, alignment, and sizing.
pub fn container(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  container_mod.new(id)
  |> container_mod.extend(children)
  |> container_mod.build()
  |> merge_attrs(attrs)
}

/// Create a scrollable container widget.
pub fn scrollable(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  scrollable_mod.new(id)
  |> scrollable_mod.extend(children)
  |> scrollable_mod.build()
  |> merge_attrs(attrs)
}

/// Create a stack widget that layers children on top of each other.
pub fn stack(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  stack_mod.new(id)
  |> stack_mod.extend(children)
  |> stack_mod.build()
  |> merge_attrs(attrs)
}

/// Create an overlay widget for popover-style content.
pub fn overlay(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  overlay_mod.new(id)
  |> overlay_mod.extend(children)
  |> overlay_mod.build()
  |> merge_attrs(attrs)
}

// --- Leaf widgets ------------------------------------------------------------

/// Create a text widget displaying the given content string.
pub fn text(id: String, content: String, attrs: List(Attr)) -> Node {
  text_mod.new(id, content) |> text_mod.build() |> merge_attrs(attrs)
}

/// Text with no attrs.
pub fn text_(id: String, content: String) -> Node {
  text(id, content, [])
}

/// Create a button widget with the given label text.
pub fn button(id: String, label: String, attrs: List(Attr)) -> Node {
  button_mod.new(id, label) |> button_mod.build() |> merge_attrs(attrs)
}

/// Button with no attrs.
pub fn button_(id: String, label: String) -> Node {
  button(id, label, [])
}

/// Create a single-line text input widget with the given value.
pub fn text_input(id: String, val: String, attrs: List(Attr)) -> Node {
  text_input_mod.new(id, val) |> text_input_mod.build() |> merge_attrs(attrs)
}

/// Create a checkbox widget with the given label and checked state.
pub fn checkbox(
  id: String,
  label: String,
  checked: Bool,
  attrs: List(Attr),
) -> Node {
  checkbox_mod.new(id, label, checked)
  |> checkbox_mod.build()
  |> merge_attrs(attrs)
}

/// Create a slider widget with the given min/max range and current value.
pub fn slider(
  id: String,
  range: #(Float, Float),
  val: Float,
  attrs: List(Attr),
) -> Node {
  slider_mod.new(id, range, val) |> slider_mod.build() |> merge_attrs(attrs)
}

/// Create an image widget from a source path or handle.
pub fn image(id: String, source: String, attrs: List(Attr)) -> Node {
  image_mod.new(id, source) |> image_mod.build() |> merge_attrs(attrs)
}

/// Create a progress bar with the given min/max range and current value.
pub fn progress_bar(
  id: String,
  range: #(Float, Float),
  val: Float,
  attrs: List(Attr),
) -> Node {
  progress_bar_mod.new(id, range, val)
  |> progress_bar_mod.build()
  |> merge_attrs(attrs)
}

/// Flexible space widget.
pub fn space(id: String, attrs: List(Attr)) -> Node {
  space_mod.new(id) |> space_mod.build() |> merge_attrs(attrs)
}

/// Horizontal or vertical rule (divider).
pub fn rule(id: String, attrs: List(Attr)) -> Node {
  rule_mod.new(id) |> rule_mod.build() |> merge_attrs(attrs)
}

// --- Grid / keyed layout widgets ---------------------------------------------

/// Create a grid layout widget.
pub fn grid(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  grid_mod.new(id)
  |> grid_mod.extend(children)
  |> grid_mod.build()
  |> merge_attrs(attrs)
}

/// Create a keyed column layout for efficient child reconciliation.
pub fn keyed_column(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  keyed_column_mod.new(id)
  |> keyed_column_mod.extend(children)
  |> keyed_column_mod.build()
  |> merge_attrs(attrs)
}

// --- Responsive / positional wrappers ----------------------------------------

/// Create a responsive layout widget that adapts to available space.
pub fn responsive(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  responsive_mod.new(id)
  |> responsive_mod.extend(children)
  |> responsive_mod.build()
  |> merge_attrs(attrs)
}

/// Create a pin widget for positioning a child at an absolute offset.
pub fn pin(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  pin_mod.new(id)
  |> pin_mod.extend(children)
  |> pin_mod.build()
  |> merge_attrs(attrs)
}

/// Create a floating widget for content that hovers above other widgets.
pub fn floating(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  floating_mod.new(id)
  |> floating_mod.extend(children)
  |> floating_mod.build()
  |> merge_attrs(attrs)
}

// --- Interaction wrappers ----------------------------------------------------

/// Create a mouse area widget that captures mouse events on its children.
pub fn mouse_area(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  mouse_area_mod.new(id)
  |> mouse_area_mod.extend(children)
  |> mouse_area_mod.build()
  |> merge_attrs(attrs)
}

/// Create a sensor widget that reports its size and position changes.
pub fn sensor(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  sensor_mod.new(id)
  |> sensor_mod.extend(children)
  |> sensor_mod.build()
  |> merge_attrs(attrs)
}

// --- Theme / pane layout -----------------------------------------------------

/// Create a themer widget that applies a local theme to its children.
pub fn themer(
  id: String,
  t: Theme,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  themer_mod.new(id, t)
  |> themer_mod.extend(children)
  |> themer_mod.build()
  |> merge_attrs(attrs)
}

/// Create a pane grid layout with resizable, splittable panes.
pub fn pane_grid(id: String, attrs: List(Attr), children: List(Node)) -> Node {
  pane_grid_mod.new(id)
  |> pane_grid_mod.extend(children)
  |> pane_grid_mod.build()
  |> merge_attrs(attrs)
}

// --- Tooltip -----------------------------------------------------------------

/// Create a tooltip widget that shows tip text when hovering its children.
pub fn tooltip(
  id: String,
  tip: String,
  attrs: List(Attr),
  children: List(Node),
) -> Node {
  tooltip_mod.new(id, tip)
  |> tooltip_mod.extend(children)
  |> tooltip_mod.build()
  |> merge_attrs(attrs)
}

// --- Data / canvas / content widgets -----------------------------------------

/// Create a data table widget.
pub fn table(id: String, attrs: List(Attr)) -> Node {
  table_mod.new(id) |> table_mod.build() |> merge_attrs(attrs)
}

/// Create a canvas widget for custom drawing with shapes and paths.
pub fn canvas(id: String, attrs: List(Attr)) -> Node {
  canvas_mod.new(id, length.Shrink, length.Shrink)
  |> canvas_mod.build()
  |> merge_attrs(attrs)
}

/// Create a markdown widget that renders the given markdown content.
pub fn markdown(id: String, content: String, attrs: List(Attr)) -> Node {
  markdown_mod.new(id, content)
  |> markdown_mod.build()
  |> merge_attrs(attrs)
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

/// Merge additional attrs onto a node built by a typed builder.
/// Used when a convenience function delegates to a builder for
/// structural props and then applies user-provided optional attrs.
fn merge_attrs(base: Node, attrs: List(Attr)) -> Node {
  case attrs {
    [] -> base
    _ -> {
      let extra =
        list.fold(attrs, dict.new(), fn(acc, attr) {
          dict.insert(acc, attr.key, attr.value)
        })
      Node(..base, props: dict.merge(base.props, extra))
    }
  }
}
