//// Content fit type for image and media scaling.

import toddy/node.{type PropValue, StringVal}

pub type ContentFit {
  Contain
  Cover
  FitFill
  ScaleDown
  NoFit
}

/// Encode a ContentFit to its wire-format PropValue.
pub fn to_prop_value(c: ContentFit) -> PropValue {
  StringVal(to_string(c))
}

pub fn to_string(c: ContentFit) -> String {
  case c {
    Contain -> "contain"
    Cover -> "cover"
    FitFill -> "fill"
    ScaleDown -> "scale_down"
    NoFit -> "none"
  }
}
