//// Canvas widget builder. Layers are managed via widget commands.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, type PropValue, DictVal, ListVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Canvas {
  Canvas(
    id: String,
    width: Length,
    height: Length,
    layers: Option(Dict(String, List(PropValue))),
    shapes: Option(List(PropValue)),
    background: Option(Color),
    interactive: Option(Bool),
    on_press: Option(Bool),
    on_release: Option(Bool),
    on_move: Option(Bool),
    on_scroll: Option(Bool),
    alt: Option(String),
    description: Option(String),
    role: Option(String),
    arrow_mode: Option(String),
    event_rate: Option(Int),
    a11y: Option(A11y),
  )
}

/// Create a new canvas builder.
pub fn new(id: String, width: Length, height: Length) -> Canvas {
  Canvas(
    id:,
    width:,
    height:,
    layers: None,
    shapes: None,
    background: None,
    interactive: None,
    on_press: None,
    on_release: None,
    on_move: None,
    on_scroll: None,
    alt: None,
    description: None,
    role: None,
    arrow_mode: None,
    event_rate: None,
    a11y: None,
  )
}

/// Set all canvas layers as a dict of named shape lists.
pub fn layers(c: Canvas, l: Dict(String, List(PropValue))) -> Canvas {
  Canvas(..c, layers: option.Some(l))
}

/// Set the shape list for the default layer.
pub fn shapes(c: Canvas, s: List(PropValue)) -> Canvas {
  Canvas(..c, shapes: option.Some(s))
}

/// Add a single named layer to the canvas. Merges with existing layers.
pub fn layer(c: Canvas, name: String, s: List(PropValue)) -> Canvas {
  let current = case c.layers {
    option.Some(l) -> l
    None -> dict.new()
  }
  Canvas(..c, layers: option.Some(dict.insert(current, name, s)))
}

/// Set the background color.
pub fn background(c: Canvas, col: Color) -> Canvas {
  Canvas(..c, background: option.Some(col))
}

/// Set whether the canvas accepts mouse events.
pub fn interactive(c: Canvas, enabled: Bool) -> Canvas {
  Canvas(..c, interactive: option.Some(enabled))
}

/// Enable the press event.
pub fn on_press(c: Canvas, enabled: Bool) -> Canvas {
  Canvas(..c, on_press: option.Some(enabled))
}

/// Enable the release event.
pub fn on_release(c: Canvas, enabled: Bool) -> Canvas {
  Canvas(..c, on_release: option.Some(enabled))
}

/// Enable the move event.
pub fn on_move(c: Canvas, enabled: Bool) -> Canvas {
  Canvas(..c, on_move: option.Some(enabled))
}

/// Enable the scroll event.
pub fn on_scroll(c: Canvas, enabled: Bool) -> Canvas {
  Canvas(..c, on_scroll: option.Some(enabled))
}

/// Set the alt text for accessibility.
pub fn alt(c: Canvas, a: String) -> Canvas {
  Canvas(..c, alt: option.Some(a))
}

/// Set the description text for accessibility.
pub fn description(c: Canvas, d: String) -> Canvas {
  Canvas(..c, description: option.Some(d))
}

/// Set the accessible role (e.g. "radiogroup", "toolbar").
pub fn role(c: Canvas, r: String) -> Canvas {
  Canvas(..c, role: option.Some(r))
}

/// Set the arrow key navigation mode ("wrap", "clamp", "linear", "none").
pub fn arrow_mode(c: Canvas, mode: String) -> Canvas {
  Canvas(..c, arrow_mode: option.Some(mode))
}

/// Set the event throttle rate in milliseconds.
pub fn event_rate(c: Canvas, rate: Int) -> Canvas {
  Canvas(..c, event_rate: option.Some(rate))
}

/// Set accessibility properties for this widget.
pub fn a11y(c: Canvas, a: A11y) -> Canvas {
  Canvas(..c, a11y: option.Some(a))
}

/// Option type for canvas properties.
pub type Opt {
  Layers(Dict(String, List(PropValue)))
  Shapes(List(PropValue))
  Layer(String, List(PropValue))
  Background(Color)
  Interactive(Bool)
  OnPress(Bool)
  OnRelease(Bool)
  OnMove(Bool)
  OnScroll(Bool)
  Alt(String)
  Description(String)
  Role(String)
  ArrowMode(String)
  EventRate(Int)
  A11y(A11y)
}

/// Apply a list of options to a canvas builder.
pub fn with_opts(c: Canvas, opts: List(Opt)) -> Canvas {
  list.fold(opts, c, fn(cv, opt) {
    case opt {
      Layers(l) -> layers(cv, l)
      Shapes(s) -> shapes(cv, s)
      Layer(name, s) -> layer(cv, name, s)
      Background(col) -> background(cv, col)
      Interactive(v) -> interactive(cv, v)
      OnPress(v) -> on_press(cv, v)
      OnRelease(v) -> on_release(cv, v)
      OnMove(v) -> on_move(cv, v)
      OnScroll(v) -> on_scroll(cv, v)
      Alt(a) -> alt(cv, a)
      Description(d) -> description(cv, d)
      Role(r) -> role(cv, r)
      ArrowMode(m) -> arrow_mode(cv, m)
      EventRate(r) -> event_rate(cv, r)
      A11y(a) -> a11y(cv, a)
    }
  })
}

/// Build the canvas into a renderable Node.
///
/// Shapes are promoted to tree children (not props) matching the
/// renderer's expected format. The renderer reads shapes from
/// canvas children, not from a "shapes" or "layers" prop.
///
/// - With layers: each layer becomes a `__layer__` child node
///   containing shape children.
/// - Without layers (flat shapes): shapes become direct children,
///   treated by the renderer as a "default" layer.
pub fn build(c: Canvas) -> Node {
  let props =
    dict.new()
    |> dict.insert("width", length.to_prop_value(c.width))
    |> dict.insert("height", length.to_prop_value(c.height))
    |> build.put_optional("background", c.background, color.to_prop_value)
    |> build.put_optional_bool("interactive", c.interactive)
    |> build.put_optional_bool("on_press", c.on_press)
    |> build.put_optional_bool("on_release", c.on_release)
    |> build.put_optional_bool("on_move", c.on_move)
    |> build.put_optional_bool("on_scroll", c.on_scroll)
    |> build.put_optional_string("alt", c.alt)
    |> build.put_optional_string("description", c.description)
    |> build.put_optional_string("role", c.role)
    |> build.put_optional_string("arrow_mode", c.arrow_mode)
    |> build.put_optional_int("event_rate", c.event_rate)
    |> build.apply_default_a11y(c.a11y, "canvas", option.None)

  // Promote shapes to tree children
  let children = case c.layers {
    option.Some(layer_map) -> layers_to_children(layer_map)
    None ->
      case c.shapes {
        option.Some(shape_list) -> shapes_to_children(shape_list)
        None -> []
      }
  }

  Node(id: c.id, kind: "canvas", props:, children:, meta: dict.new())
}

/// Convert named layers to __layer__ container children.
fn layers_to_children(layer_map: Dict(String, List(PropValue))) -> List(Node) {
  dict.to_list(layer_map)
  |> list.map(fn(pair) {
    let #(name, shapes) = pair
    let layer_props = dict.from_list([#("name", node.StringVal(name))])
    Node(
      id: name,
      kind: "__layer__",
      props: layer_props,
      children: shapes_to_children(shapes),
      meta: dict.new(),
    )
  })
}

/// Convert a flat list of shape PropValues (DictVal) to child Nodes.
/// Each shape's "type" field becomes the node kind, and the remaining
/// fields become the node's props.
fn shapes_to_children(shapes: List(PropValue)) -> List(Node) {
  list.index_map(shapes, fn(shape, idx) {
    case shape {
      DictVal(shape_props) -> {
        let kind = case dict.get(shape_props, "type") {
          Ok(node.StringVal(t)) -> t
          _ -> "unknown"
        }
        let id = case dict.get(shape_props, "id") {
          Ok(node.StringVal(s)) -> s
          _ -> "auto:shape_" <> int.to_string(idx)
        }
        // Extract children before cleaning props
        let children = shape_children(shape_props)
        // Remove fields promoted to the Node structure
        let props =
          shape_props
          |> dict.delete("type")
          |> dict.delete("id")
          |> dict.delete("children")
        Node(id:, kind:, props:, children:, meta: dict.new())
      }
      _ ->
        Node(
          id: "auto:shape_" <> int.to_string(idx),
          kind: "unknown",
          props: dict.new(),
          children: [],
          meta: dict.new(),
        )
    }
  })
}

/// Extract children from a group shape (recursive).
fn shape_children(shape_props: Dict(String, PropValue)) -> List(Node) {
  case dict.get(shape_props, "children") {
    Ok(ListVal(kids)) -> shapes_to_children(kids)
    _ -> []
  }
}
