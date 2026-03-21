//// Direction type for scrollable and overflow axes.

import plushie/node.{type PropValue, StringVal}

pub type Direction {
  Horizontal
  Vertical
  Both
}

/// Encode a Direction to its wire-format PropValue.
pub fn to_prop_value(d: Direction) -> PropValue {
  StringVal(to_string(d))
}

pub fn to_string(d: Direction) -> String {
  case d {
    Horizontal -> "horizontal"
    Vertical -> "vertical"
    Both -> "both"
  }
}
