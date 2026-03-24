//// Sensor widget builder (layout change detection).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/widget/build

pub opaque type Sensor {
  Sensor(
    id: String,
    children: List(Node),
    delay: Option(Int),
    anticipate: Option(Float),
    on_resize: Option(String),
    event_rate: Option(Int),
    a11y: Option(A11y),
  )
}

/// Create a new sensor builder.
pub fn new(id: String) -> Sensor {
  Sensor(
    id:,
    children: [],
    delay: None,
    anticipate: None,
    on_resize: None,
    event_rate: None,
    a11y: None,
  )
}

/// Set the delay in milliseconds.
pub fn delay(s: Sensor, d: Int) -> Sensor {
  Sensor(..s, delay: option.Some(d))
}

/// Set the anticipation factor for resize detection.
pub fn anticipate(s: Sensor, a: Float) -> Sensor {
  Sensor(..s, anticipate: option.Some(a))
}

/// Set the resize event tag.
pub fn on_resize(s: Sensor, tag: String) -> Sensor {
  Sensor(..s, on_resize: option.Some(tag))
}

/// Set the event throttle rate in milliseconds.
pub fn event_rate(s: Sensor, rate: Int) -> Sensor {
  Sensor(..s, event_rate: option.Some(rate))
}

/// Add a child node.
pub fn push(s: Sensor, child: Node) -> Sensor {
  Sensor(..s, children: list.append(s.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(s: Sensor, children: List(Node)) -> Sensor {
  Sensor(..s, children: list.append(s.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(s: Sensor, a: A11y) -> Sensor {
  Sensor(..s, a11y: option.Some(a))
}

/// Option type for sensor properties.
pub type Opt {
  Delay(Int)
  Anticipate(Float)
  OnResize(String)
  EventRate(Int)
  A11y(A11y)
}

/// Apply a list of options to a sensor builder.
pub fn with_opts(s: Sensor, opts: List(Opt)) -> Sensor {
  list.fold(opts, s, fn(sn, opt) {
    case opt {
      Delay(d) -> delay(sn, d)
      Anticipate(a) -> anticipate(sn, a)
      OnResize(tag) -> on_resize(sn, tag)
      EventRate(r) -> event_rate(sn, r)
      A11y(a) -> a11y(sn, a)
    }
  })
}

/// Build the sensor into a renderable Node.
pub fn build(s: Sensor) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("delay", s.delay)
    |> build.put_optional_float("anticipate", s.anticipate)
    |> build.put_optional_string("on_resize", s.on_resize)
    |> build.put_optional_int("event_rate", s.event_rate)
    |> build.put_optional("a11y", s.a11y, a11y.to_prop_value)
  Node(id: s.id, kind: "sensor", props:, children: s.children)
}
