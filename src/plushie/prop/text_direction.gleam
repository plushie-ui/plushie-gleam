//// Text layout direction type.

import plushie/node.{type PropValue, StringVal}

pub type TextDirection {
  Auto
  Ltr
  Rtl
}

/// Encode a TextDirection to its wire-format PropValue.
pub fn to_prop_value(direction: TextDirection) -> PropValue {
  StringVal(to_string(direction))
}

/// Convert a TextDirection to its wire-format string representation.
pub fn to_string(direction: TextDirection) -> String {
  case direction {
    Auto -> "auto"
    Ltr -> "ltr"
    Rtl -> "rtl"
  }
}
