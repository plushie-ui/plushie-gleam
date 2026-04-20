//// Border type for widget outlines.
////
//// Builder pattern: start with `new()` and pipe through `color`, `width`,
//// `radius`, or `radius_corners` to configure.

import gleam/dict
import gleam/option.{type Option, None, Some}
import plushie/node.{type PropValue, DictVal, FloatVal}
import plushie/prop/color.{type Color}

/// A border with color, width, and corner radius.
pub type Border {
  Border(color: Option(Color), width: Float, radius: Radius)
}

pub type Radius {
  Uniform(Float)
  PerCorner(
    top_left: Float,
    top_right: Float,
    bottom_right: Float,
    bottom_left: Float,
  )
}

/// Create a border with default values (no color, zero width, zero radius).
pub fn new() -> Border {
  Border(color: None, width: 0.0, radius: Uniform(0.0))
}

/// Set the border color.
pub fn color(b: Border, c: Color) -> Border {
  Border(..b, color: Some(c))
}

/// Set the border width.
pub fn width(b: Border, w: Float) -> Border {
  Border(..b, width: w)
}

/// Set a uniform border radius.
pub fn radius(b: Border, r: Float) -> Border {
  Border(..b, radius: Uniform(r))
}

/// Set per-corner border radii.
pub fn radius_corners(
  b: Border,
  tl: Float,
  tr: Float,
  br: Float,
  bl: Float,
) -> Border {
  Border(..b, radius: PerCorner(tl, tr, br, bl))
}

/// Encode a Border to its wire-format PropValue.
///
/// Panics when the width or any radius value is negative. Negatives
/// are rejected at the SDK boundary rather than silently reaching the
/// renderer.
pub fn to_prop_value(b: Border) -> PropValue {
  case b.width <. 0.0 {
    True -> panic as "border width must be non-negative"
    False -> Nil
  }

  let radius_val = case b.radius {
    Uniform(r) ->
      case r <. 0.0 {
        True -> panic as "border radius must be non-negative"
        False -> FloatVal(r)
      }
    PerCorner(tl, tr, br, bl) ->
      case tl <. 0.0 || tr <. 0.0 || br <. 0.0 || bl <. 0.0 {
        True -> panic as "border radius must be non-negative"
        False ->
          DictVal(
            dict.from_list([
              #("top_left", FloatVal(tl)),
              #("top_right", FloatVal(tr)),
              #("bottom_right", FloatVal(br)),
              #("bottom_left", FloatVal(bl)),
            ]),
          )
      }
  }

  let base = [#("width", FloatVal(b.width)), #("radius", radius_val)]

  let props = case b.color {
    None -> base
    Some(c) -> [#("color", color.to_prop_value(c)), ..base]
  }

  DictVal(dict.from_list(props))
}
