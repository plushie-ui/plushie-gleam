//// Line height for text widgets.
////
//// Accepts three forms:
//// - A relative multiplier (e.g. `1.5` via `relative(1.5)`)
//// - An explicit absolute pixel height (e.g. `absolute(20.0)`)
////
//// Numbers are passed through as-is on the wire (the renderer
//// interprets plain numbers as relative multipliers). Map forms
//// are sent as `{relative: n}` or `{absolute: n}`.

import gleam/dict
import plushie/node.{type PropValue, DictVal, FloatVal}

/// Line height specification for text widgets.
pub type LineHeight {
  /// Relative line height multiplier (e.g. 1.5 means 150% of font size).
  Relative(Float)
  /// Absolute line height in pixels.
  Absolute(Float)
}

/// Create a relative line height (multiplier of font size).
pub fn relative(n: Float) -> LineHeight {
  Relative(n)
}

/// Create an absolute line height in pixels.
pub fn absolute(n: Float) -> LineHeight {
  Absolute(n)
}

/// Encode a LineHeight to its wire-format PropValue.
///
/// Relative values are sent as bare numbers (the renderer default).
/// Absolute values are sent as `{absolute: n}` maps.
pub fn to_prop_value(lh: LineHeight) -> PropValue {
  case lh {
    Relative(n) -> FloatVal(n)
    Absolute(n) -> DictVal(dict.from_list([#("absolute", FloatVal(n))]))
  }
}
