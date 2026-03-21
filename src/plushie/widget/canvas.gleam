//// Canvas widget builder. Layers are managed via extension commands.

import gleam/dict.{type Dict}
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

/// Set the event throttle rate in milliseconds.
pub fn event_rate(c: Canvas, rate: Int) -> Canvas {
  Canvas(..c, event_rate: option.Some(rate))
}

/// Set accessibility properties for this widget.
pub fn a11y(c: Canvas, a: A11y) -> Canvas {
  Canvas(..c, a11y: option.Some(a))
}

fn layers_to_prop_value(l: Dict(String, List(PropValue))) -> PropValue {
  DictVal(
    dict.fold(l, dict.new(), fn(acc, key, shapes) {
      dict.insert(acc, key, ListVal(shapes))
    }),
  )
}

/// Build the canvas into a renderable Node.
pub fn build(c: Canvas) -> Node {
  let props =
    dict.new()
    |> dict.insert("width", length.to_prop_value(c.width))
    |> dict.insert("height", length.to_prop_value(c.height))
    |> build.put_optional("layers", c.layers, layers_to_prop_value)
    |> build.put_optional("shapes", c.shapes, fn(s) { ListVal(s) })
    |> build.put_optional("background", c.background, color.to_prop_value)
    |> build.put_optional_bool("interactive", c.interactive)
    |> build.put_optional_bool("on_press", c.on_press)
    |> build.put_optional_bool("on_release", c.on_release)
    |> build.put_optional_bool("on_move", c.on_move)
    |> build.put_optional_bool("on_scroll", c.on_scroll)
    |> build.put_optional_string("alt", c.alt)
    |> build.put_optional_string("description", c.description)
    |> build.put_optional_int("event_rate", c.event_rate)
    |> build.put_optional("a11y", c.a11y, a11y.to_prop_value)
  Node(id: c.id, kind: "canvas", props:, children: [])
}
