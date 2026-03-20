//// Text shaping strategy type.
////
//// Basic uses simple shaping; Advanced enables OpenType features
//// like ligatures and contextual alternates.

import toddy/node.{type PropValue, StringVal}

pub type Shaping {
  Basic
  Advanced
}

/// Encode a Shaping to its wire-format PropValue.
pub fn to_prop_value(s: Shaping) -> PropValue {
  StringVal(to_string(s))
}

pub fn to_string(s: Shaping) -> String {
  case s {
    Basic -> "basic"
    Advanced -> "advanced"
  }
}
