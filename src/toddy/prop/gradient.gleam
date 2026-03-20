//// Gradient type for background fills.
////
//// Currently supports linear gradients with an angle and a list of
//// color stops. Each stop has an offset (0.0 to 1.0) and a color
//// hex string.

import gleam/dict
import gleam/list
import toddy/node.{type PropValue, DictVal, FloatVal, ListVal, StringVal}

pub type Gradient {
  Gradient(angle: Float, stops: List(GradientStop))
}

pub type GradientStop {
  GradientStop(offset: Float, color: String)
}

/// Create a linear gradient with the given angle and stops.
pub fn linear(angle: Float, stops: List(GradientStop)) -> Gradient {
  Gradient(angle:, stops:)
}

/// Create a gradient stop.
pub fn stop(offset: Float, color: String) -> GradientStop {
  GradientStop(offset:, color:)
}

/// Encode a Gradient to its wire-format PropValue.
pub fn to_prop_value(g: Gradient) -> PropValue {
  DictVal(
    dict.from_list([
      #("type", StringVal("linear")),
      #("angle", FloatVal(g.angle)),
      #("stops", ListVal(list.map(g.stops, stop_to_prop_value))),
    ]),
  )
}

fn stop_to_prop_value(s: GradientStop) -> PropValue {
  DictVal(
    dict.from_list([
      #("offset", FloatVal(s.offset)),
      #("color", StringVal(s.color)),
    ]),
  )
}
