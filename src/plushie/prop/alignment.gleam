//// Alignment type for widget positioning.
////
//// Horizontal: Left, Center, Right.
//// Vertical: Top, Center, Bottom.

import plushie/node.{type PropValue, StringVal}

pub type Alignment {
  Left
  Center
  Right
  Top
  Bottom
}

/// Encode to wire-format PropValue.
pub fn to_prop_value(a: Alignment) -> PropValue {
  StringVal(to_string(a))
}

/// Convert an Alignment to its wire-format string representation.
pub fn to_string(a: Alignment) -> String {
  case a {
    Left -> "left"
    Center -> "center"
    Right -> "right"
    Top -> "top"
    Bottom -> "bottom"
  }
}
