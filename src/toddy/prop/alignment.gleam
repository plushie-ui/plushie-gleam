//// Alignment type for widget positioning.

import toddy/node.{type PropValue, StringVal}

pub type Alignment {
  Left
  Center
  Right
  Top
  Bottom
  Start
  End
}

/// Encode to wire-format PropValue.
pub fn to_prop_value(a: Alignment) -> PropValue {
  StringVal(to_string(a))
}

pub fn to_string(a: Alignment) -> String {
  case a {
    Left -> "left"
    Center -> "center"
    Right -> "right"
    Top -> "top"
    Bottom -> "bottom"
    Start -> "start"
    End -> "end"
  }
}
