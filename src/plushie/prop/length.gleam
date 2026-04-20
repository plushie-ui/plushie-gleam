//// Length type for widget dimensions.
////
//// Lengths control how widgets size themselves within their parent.
//// Fill expands to available space, Shrink wraps content, FillPortion
//// distributes space proportionally, and Fixed sets an exact pixel size.

import gleam/dict
import plushie/node.{type PropValue, DictVal, FloatVal, IntVal, StringVal}

pub type Length {
  Fill
  Shrink
  FillPortion(portion: Int)
  Fixed(pixels: Float)
}

/// Encode a Length to its wire-format PropValue.
///
/// Panics when a numeric length is negative or when `FillPortion`
/// is less than 1. Negative lengths are rejected at the SDK boundary
/// rather than silently reaching the renderer.
pub fn to_prop_value(length: Length) -> PropValue {
  case length {
    Fill -> StringVal("fill")
    Shrink -> StringVal("shrink")
    FillPortion(n) ->
      case n < 1 {
        True -> panic as "length fill_portion must be >= 1"
        False -> DictVal(dict.from_list([#("fill_portion", IntVal(n))]))
      }
    Fixed(px) ->
      case px <. 0.0 {
        True -> panic as "length must be non-negative"
        False -> FloatVal(px)
      }
  }
}
