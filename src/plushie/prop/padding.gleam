//// Padding type for widget internal spacing.
////
//// Always normalizes to four explicit sides for the wire format.

import gleam/dict
import plushie/node.{type PropValue, DictVal, FloatVal}

pub type Padding {
  Padding(top: Float, right: Float, bottom: Float, left: Float)
}

/// Uniform padding on all sides.
pub fn all(n: Float) -> Padding {
  Padding(top: n, right: n, bottom: n, left: n)
}

/// Vertical and horizontal padding.
pub fn xy(vertical: Float, horizontal: Float) -> Padding {
  Padding(top: vertical, right: horizontal, bottom: vertical, left: horizontal)
}

/// No padding.
pub fn none() -> Padding {
  Padding(top: 0.0, right: 0.0, bottom: 0.0, left: 0.0)
}

/// Encode to wire-format PropValue (always full 4-key map).
///
/// Panics when any side is negative. Negatives are rejected at the
/// SDK boundary rather than silently reaching the renderer.
pub fn to_prop_value(p: Padding) -> PropValue {
  case p.top <. 0.0 || p.right <. 0.0 || p.bottom <. 0.0 || p.left <. 0.0 {
    True -> panic as "padding must be non-negative"
    False ->
      DictVal(
        dict.from_list([
          #("top", FloatVal(p.top)),
          #("right", FloatVal(p.right)),
          #("bottom", FloatVal(p.bottom)),
          #("left", FloatVal(p.left)),
        ]),
      )
  }
}
