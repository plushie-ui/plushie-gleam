//// Text shaping strategy type.
////
//// Basic uses simple shaping; Advanced enables OpenType features
//// like ligatures and contextual alternates.

import plushie/node.{type PropValue, StringVal}

pub type Shaping {
  Auto
  Basic
  Advanced
}

/// Encode a Shaping to its wire-format PropValue.
pub fn to_prop_value(s: Shaping) -> PropValue {
  StringVal(to_string(s))
}

/// Convert a Shaping to its wire-format string representation.
pub fn to_string(s: Shaping) -> String {
  case s {
    Auto -> "auto"
    Basic -> "basic"
    Advanced -> "advanced"
  }
}
