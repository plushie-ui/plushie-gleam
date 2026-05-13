//// Text truncation ellipsis position.

import plushie/node.{type PropValue, StringVal}

pub type Ellipsis {
  None
  Start
  Middle
  End
}

/// Encode an Ellipsis to its wire-format PropValue.
pub fn to_prop_value(e: Ellipsis) -> PropValue {
  StringVal(to_string(e))
}

/// Convert an Ellipsis to its wire-format string representation.
pub fn to_string(e: Ellipsis) -> String {
  case e {
    None -> "none"
    Start -> "start"
    Middle -> "middle"
    End -> "end"
  }
}
