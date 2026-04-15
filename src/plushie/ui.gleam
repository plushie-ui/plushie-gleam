//// Ergonomic UI builder functions.
////
//// Provides convenience functions for building UI trees without
//// importing individual widget modules. Each widget function accepts
//// a `List(widget.Opt)` of typed options specific to that widget,
//// giving compile-time validation of property names and types.

import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import plushie/node.{type Node}
import plushie/prop/length.{type Length}
import plushie/prop/theme.{type Theme}
import plushie/widget/button
import plushie/widget/canvas
import plushie/widget/checkbox
import plushie/widget/column
import plushie/widget/combo_box
import plushie/widget/container
import plushie/widget/floating
import plushie/widget/grid
import plushie/widget/image
import plushie/widget/keyed_column
import plushie/widget/markdown
import plushie/widget/overlay
import plushie/widget/pane_grid
import plushie/widget/pick_list
import plushie/widget/pin
import plushie/widget/pointer_area
import plushie/widget/progress_bar
import plushie/widget/qr_code
import plushie/widget/radio
import plushie/widget/responsive
import plushie/widget/rich_text
import plushie/widget/row
import plushie/widget/rule
import plushie/widget/scrollable
import plushie/widget/sensor
import plushie/widget/slider
import plushie/widget/space
import plushie/widget/stack
import plushie/widget/svg
import plushie/widget/table
import plushie/widget/text
import plushie/widget/text_input
import plushie/widget/themer
import plushie/widget/toggler
import plushie/widget/tooltip
import plushie/widget/vertical_slider
import plushie/widget/window

// --- Container widgets -------------------------------------------------------

/// Create a window node. Only detected at the root or as a direct child
/// of the root node.
pub fn window(id: String, opts: List(window.Opt), children: List(Node)) -> Node {
  window.new(id)
  |> window.with_opts(opts)
  |> window.extend(children)
  |> window.build()
}

/// Create a vertical column layout widget.
pub fn column(id: String, opts: List(column.Opt), children: List(Node)) -> Node {
  column.new(id)
  |> column.with_opts(opts)
  |> column.extend(children)
  |> column.build()
}

/// Create a horizontal row layout widget.
pub fn row(id: String, opts: List(row.Opt), children: List(Node)) -> Node {
  row.new(id)
  |> row.with_opts(opts)
  |> row.extend(children)
  |> row.build()
}

/// Create a container widget that wraps its children with optional
/// padding, alignment, and sizing.
pub fn container(
  id: String,
  opts: List(container.Opt),
  children: List(Node),
) -> Node {
  container.new(id)
  |> container.with_opts(opts)
  |> container.extend(children)
  |> container.build()
}

/// Create a scrollable container widget.
pub fn scrollable(
  id: String,
  opts: List(scrollable.Opt),
  children: List(Node),
) -> Node {
  scrollable.new(id)
  |> scrollable.with_opts(opts)
  |> scrollable.extend(children)
  |> scrollable.build()
}

/// Create a stack widget that layers children on top of each other.
pub fn stack(id: String, opts: List(stack.Opt), children: List(Node)) -> Node {
  stack.new(id)
  |> stack.with_opts(opts)
  |> stack.extend(children)
  |> stack.build()
}

/// Create an overlay widget for popover-style content.
pub fn overlay(
  id: String,
  opts: List(overlay.Opt),
  children: List(Node),
) -> Node {
  overlay.new(id)
  |> overlay.with_opts(opts)
  |> overlay.extend(children)
  |> overlay.build()
}

// --- Leaf widgets ------------------------------------------------------------

/// Create a text widget displaying the given content string.
pub fn text(id: String, content: String, opts: List(text.Opt)) -> Node {
  text.new(id, content)
  |> text.with_opts(opts)
  |> text.build()
}

/// Text with no opts.
pub fn text_(id: String, content: String) -> Node {
  text(id, content, [])
}

/// Create a button widget with the given label text.
pub fn button(id: String, label: String, opts: List(button.Opt)) -> Node {
  button.new(id, label)
  |> button.with_opts(opts)
  |> button.build()
}

/// Button with no opts.
pub fn button_(id: String, label: String) -> Node {
  button(id, label, [])
}

/// Create a single-line text input widget with the given value.
pub fn text_input(id: String, val: String, opts: List(text_input.Opt)) -> Node {
  text_input.new(id, val)
  |> text_input.with_opts(opts)
  |> text_input.build()
}

/// Create a checkbox widget with the given label and checked state.
pub fn checkbox(
  id: String,
  label: String,
  checked: Bool,
  opts: List(checkbox.Opt),
) -> Node {
  checkbox.new(id, label, checked)
  |> checkbox.with_opts(opts)
  |> checkbox.build()
}

/// Create a slider widget with the given min/max range and current value.
pub fn slider(
  id: String,
  range: #(Float, Float),
  val: Float,
  opts: List(slider.Opt),
) -> Node {
  slider.new(id, range, val)
  |> slider.with_opts(opts)
  |> slider.build()
}

/// Create an image widget from a source path or handle.
pub fn image(id: String, source: String, opts: List(image.Opt)) -> Node {
  image.new(id, source)
  |> image.with_opts(opts)
  |> image.build()
}

/// Create a progress bar with the given min/max range and current value.
pub fn progress_bar(
  id: String,
  range: #(Float, Float),
  val: Float,
  opts: List(progress_bar.Opt),
) -> Node {
  progress_bar.new(id, range, val)
  |> progress_bar.with_opts(opts)
  |> progress_bar.build()
}

/// Flexible space widget.
pub fn space(id: String, opts: List(space.Opt)) -> Node {
  space.new(id)
  |> space.with_opts(opts)
  |> space.build()
}

/// Horizontal or vertical rule (divider).
pub fn rule(id: String, opts: List(rule.Opt)) -> Node {
  rule.new(id)
  |> rule.with_opts(opts)
  |> rule.build()
}

// --- Grid / keyed layout widgets ---------------------------------------------

/// Create a grid layout widget.
pub fn grid(id: String, opts: List(grid.Opt), children: List(Node)) -> Node {
  grid.new(id)
  |> grid.with_opts(opts)
  |> grid.extend(children)
  |> grid.build()
}

/// Create a keyed column layout for efficient child reconciliation.
pub fn keyed_column(
  id: String,
  opts: List(keyed_column.Opt),
  children: List(Node),
) -> Node {
  keyed_column.new(id)
  |> keyed_column.with_opts(opts)
  |> keyed_column.extend(children)
  |> keyed_column.build()
}

// --- Responsive / positional wrappers ----------------------------------------

/// Create a responsive layout widget that adapts to available space.
pub fn responsive(
  id: String,
  opts: List(responsive.Opt),
  children: List(Node),
) -> Node {
  responsive.new(id)
  |> responsive.with_opts(opts)
  |> responsive.extend(children)
  |> responsive.build()
}

/// Create a pin widget for positioning a child at an absolute offset.
pub fn pin(id: String, opts: List(pin.Opt), children: List(Node)) -> Node {
  pin.new(id)
  |> pin.with_opts(opts)
  |> pin.extend(children)
  |> pin.build()
}

/// Create a floating widget for content that hovers above other widgets.
pub fn floating(
  id: String,
  opts: List(floating.Opt),
  children: List(Node),
) -> Node {
  floating.new(id)
  |> floating.with_opts(opts)
  |> floating.extend(children)
  |> floating.build()
}

// --- Interaction wrappers ----------------------------------------------------

/// Create a pointer area widget that captures pointer events on its children.
pub fn pointer_area(
  id: String,
  opts: List(pointer_area.Opt),
  children: List(Node),
) -> Node {
  pointer_area.new(id)
  |> pointer_area.with_opts(opts)
  |> pointer_area.extend(children)
  |> pointer_area.build()
}

/// Create a sensor widget that reports its size and position changes.
pub fn sensor(id: String, opts: List(sensor.Opt), children: List(Node)) -> Node {
  sensor.new(id)
  |> sensor.with_opts(opts)
  |> sensor.extend(children)
  |> sensor.build()
}

// --- Theme / pane layout -----------------------------------------------------

/// Create a themer widget that applies a local theme to its children.
pub fn themer(
  id: String,
  t: Theme,
  opts: List(themer.Opt),
  children: List(Node),
) -> Node {
  themer.new(id, t)
  |> themer.with_opts(opts)
  |> themer.extend(children)
  |> themer.build()
}

/// Create a pane grid layout with resizable, splittable panes.
pub fn pane_grid(
  id: String,
  opts: List(pane_grid.Opt),
  children: List(Node),
) -> Node {
  pane_grid.new(id)
  |> pane_grid.with_opts(opts)
  |> pane_grid.extend(children)
  |> pane_grid.build()
}

// --- Tooltip -----------------------------------------------------------------

/// Create a tooltip widget that shows tip text when hovering its children.
pub fn tooltip(
  id: String,
  tip: String,
  opts: List(tooltip.Opt),
  children: List(Node),
) -> Node {
  tooltip.new(id, tip)
  |> tooltip.with_opts(opts)
  |> tooltip.extend(children)
  |> tooltip.build()
}

// --- Data / canvas / content widgets -----------------------------------------

/// Create a data table widget.
pub fn table(id: String, opts: List(table.Opt)) -> Node {
  table.new(id)
  |> table.with_opts(opts)
  |> table.build()
}

/// Create a canvas widget for custom drawing with shapes and paths.
pub fn canvas(id: String, w: Length, h: Length, opts: List(canvas.Opt)) -> Node {
  canvas.new(id, w, h)
  |> canvas.with_opts(opts)
  |> canvas.build()
}

/// Create a markdown widget that renders the given markdown content.
pub fn markdown(id: String, content: String, opts: List(markdown.Opt)) -> Node {
  markdown.new(id, content)
  |> markdown.with_opts(opts)
  |> markdown.build()
}

// --- Memo (subtree caching) --------------------------------------------------

// --- Additional input widgets ------------------------------------------------

/// Create a combo box (searchable dropdown).
pub fn combo_box(
  id: String,
  options: List(String),
  value: String,
  opts: List(combo_box.Opt),
) -> Node {
  combo_box.new(id, options, value)
  |> combo_box.with_opts(opts)
  |> combo_box.build()
}

/// Create a pick list (simple dropdown select).
pub fn pick_list(
  id: String,
  options: List(String),
  selected: Option(String),
  opts: List(pick_list.Opt),
) -> Node {
  pick_list.new(id, options, selected)
  |> pick_list.with_opts(opts)
  |> pick_list.build()
}

/// Create a radio button.
pub fn radio(
  id: String,
  value: String,
  selected: Option(String),
  label: String,
  opts: List(radio.Opt),
) -> Node {
  radio.new(id, value, selected, label)
  |> radio.with_opts(opts)
  |> radio.build()
}

/// Create a toggler (on/off switch).
pub fn toggler(
  id: String,
  label: String,
  is_toggled: Bool,
  opts: List(toggler.Opt),
) -> Node {
  toggler.new(id, label, is_toggled)
  |> toggler.with_opts(opts)
  |> toggler.build()
}

/// Create a vertical slider.
pub fn vertical_slider(
  id: String,
  range: #(Float, Float),
  value: Float,
  opts: List(vertical_slider.Opt),
) -> Node {
  vertical_slider.new(id, range, value)
  |> vertical_slider.with_opts(opts)
  |> vertical_slider.build()
}

// --- Media widgets -----------------------------------------------------------

/// Create an SVG image.
pub fn svg(id: String, source: String, opts: List(svg.Opt)) -> Node {
  svg.new(id, source) |> svg.with_opts(opts) |> svg.build()
}

/// Create a QR code.
pub fn qr_code(id: String, data: String, opts: List(qr_code.Opt)) -> Node {
  qr_code.new(id, data) |> qr_code.with_opts(opts) |> qr_code.build()
}

// --- Rich content widgets ----------------------------------------------------

/// Create a rich text widget for styled text spans.
pub fn rich_text(id: String, opts: List(rich_text.Opt)) -> Node {
  rich_text.new(id) |> rich_text.with_opts(opts) |> rich_text.build()
}

// --- Caching -----------------------------------------------------------------

/// Mark a subtree for caching across render cycles. The content function
/// is evaluated eagerly. The dependency is stored with the result so the
/// runtime can skip re-normalization when the dependency hasn't changed.
///
/// ```gleam
/// ui.memo("sidebar", model.sidebar_version, fn() {
///   sidebar_view(model.sidebar_data)
/// })
/// ```
///
/// The key must be unique within siblings. The dependency can be any
/// value; it's compared with `==` each render cycle.
pub fn memo(key: String, dependency: a, content: fn() -> Node) -> Node {
  let child = content()
  node.Node(
    id: "memo:" <> key,
    kind: "__memo__",
    props: dict.new(),
    children: [child],
    meta: dict.from_list([
      #("__memo_dep__", node.OpaqueVal(coerce(dependency))),
    ]),
  )
}

@external(erlang, "plushie_ffi", "identity")
@external(javascript, "../plushie_platform_ffi.mjs", "identity")
fn coerce(value: a) -> Dynamic
