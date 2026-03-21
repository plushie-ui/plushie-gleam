//// Filter method type for image interpolation.

import plushie/node.{type PropValue, StringVal}

pub type FilterMethod {
  Nearest
  Linear
}

/// Encode a FilterMethod to its wire-format PropValue.
pub fn to_prop_value(f: FilterMethod) -> PropValue {
  StringVal(to_string(f))
}

pub fn to_string(f: FilterMethod) -> String {
  case f {
    Nearest -> "nearest"
    Linear -> "linear"
  }
}
