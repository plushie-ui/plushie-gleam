//// Length type for widget dimensions.
////
//// Lengths control how widgets size themselves within their parent.
//// Fill expands to available space, Shrink wraps content, FillPortion
//// distributes space proportionally, and Fixed sets an exact pixel size.

import gleam/dict
import toddy/node.{type PropValue, DictVal, FloatVal, IntVal, StringVal}

pub type Length {
  Fill
  Shrink
  FillPortion(portion: Int)
  Fixed(pixels: Float)
}

/// Encode a Length to its wire-format PropValue.
pub fn to_prop_value(length: Length) -> PropValue {
  case length {
    Fill -> StringVal("fill")
    Shrink -> StringVal("shrink")
    FillPortion(n) -> DictVal(dict.from_list([#("fill_portion", IntVal(n))]))
    Fixed(px) -> FloatVal(px)
  }
}
