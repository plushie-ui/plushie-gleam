//// Gradient type for background fills.
////
//// Supports linear gradients defined by start/end coordinates and a
//// list of color stops. Each stop has an offset (0.0 to 1.0) and a
//// Color value (from prop/color).
////
//// ## Wire format
////
//// Uses coordinate-based format matching the canvas gradient API:
//// ```json
//// {
////   "type": "linear",
////   "start": [0, 0],
////   "end": [100, 100],
////   "stops": [[0.0, "#ff0000"], [1.0, "#0000ff"]]
//// }
//// ```

import gleam/dict
import gleam/float
import gleam/list
import plushie/node.{type PropValue, DictVal, FloatVal, ListVal, StringVal}
import plushie/platform
import plushie/prop/color.{type Color}

const pi = 3.14159265358979323846

pub type Gradient {
  Gradient(
    from: #(Float, Float),
    to: #(Float, Float),
    stops: List(GradientStop),
  )
}

pub type GradientStop {
  GradientStop(offset: Float, color: Color)
}

/// Create a linear gradient between two coordinate points.
pub fn linear(
  from: #(Float, Float),
  to: #(Float, Float),
  stops: List(GradientStop),
) -> Gradient {
  Gradient(from:, to:, stops:)
}

/// Create a linear gradient from an angle (degrees) and stops.
///
/// The angle is converted to start/end coordinates on a unit square
/// (0,0 to 1,1). Use this when you want angle-based gradients without
/// computing coordinates manually.
pub fn linear_from_angle(
  angle_degrees: Float,
  stops: List(GradientStop),
) -> Gradient {
  let radians = angle_degrees *. pi /. 180.0

  // Project angle onto unit square edges
  let dx = platform.math_cos(radians)
  let dy = platform.math_sin(radians)

  let half_len =
    float.absolute_value(dx) /. 2.0 +. float.absolute_value(dy) /. 2.0
  let cx = 0.5
  let cy = 0.5

  let from = #(cx -. dx *. half_len, cy -. dy *. half_len)
  let to = #(cx +. dx *. half_len, cy +. dy *. half_len)

  Gradient(from:, to:, stops:)
}

/// Create a gradient stop.
pub fn stop(offset: Float, c: Color) -> GradientStop {
  GradientStop(offset:, color: c)
}

/// Encode a Gradient to its wire-format PropValue.
pub fn to_prop_value(g: Gradient) -> PropValue {
  let #(fx, fy) = g.from
  let #(tx, ty) = g.to
  let stop_values =
    list.map(g.stops, fn(s) {
      ListVal([FloatVal(s.offset), color.to_prop_value(s.color)])
    })
  DictVal(
    dict.from_list([
      #("type", StringVal("linear")),
      #("start", ListVal([FloatVal(fx), FloatVal(fy)])),
      #("end", ListVal([FloatVal(tx), FloatVal(ty)])),
      #("stops", ListVal(stop_values)),
    ]),
  )
}
