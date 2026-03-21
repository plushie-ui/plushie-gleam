//// Anchor type for scrollable snap points.

import plushie/node.{type PropValue, StringVal}

pub type Anchor {
  AnchorStart
  AnchorEnd
}

/// Encode an Anchor to its wire-format PropValue.
pub fn to_prop_value(a: Anchor) -> PropValue {
  StringVal(to_string(a))
}

pub fn to_string(a: Anchor) -> String {
  case a {
    AnchorStart -> "start"
    AnchorEnd -> "end"
  }
}
