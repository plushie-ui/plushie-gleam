//// Shadow type for widget drop shadows.
////
//// Builder pattern: start with `new()` and pipe through `color`,
//// `offset`, `offset_x`, `offset_y`, or `blur_radius` to configure.

import gleam/dict
import plushie/node.{type PropValue, DictVal, FloatVal, ListVal}
import plushie/prop/color.{type Color}

/// A drop shadow with color, offset, and blur.
pub type Shadow {
  Shadow(color: Color, offset_x: Float, offset_y: Float, blur_radius: Float)
}

/// Create a shadow with default values (black, no offset, no blur).
pub fn new() -> Shadow {
  Shadow(color: color.black, offset_x: 0.0, offset_y: 0.0, blur_radius: 0.0)
}

/// Set the shadow color.
pub fn color(s: Shadow, c: Color) -> Shadow {
  Shadow(..s, color: c)
}

/// Set both offset components at once.
pub fn offset(s: Shadow, x: Float, y: Float) -> Shadow {
  Shadow(..s, offset_x: x, offset_y: y)
}

/// Set only the horizontal offset.
pub fn offset_x(s: Shadow, x: Float) -> Shadow {
  Shadow(..s, offset_x: x)
}

/// Set only the vertical offset.
pub fn offset_y(s: Shadow, y: Float) -> Shadow {
  Shadow(..s, offset_y: y)
}

/// Set the blur radius.
pub fn blur_radius(s: Shadow, r: Float) -> Shadow {
  Shadow(..s, blur_radius: r)
}

/// Encode a Shadow to its wire-format PropValue.
///
/// Offset is encoded as a two-element array `[x, y]` to match
/// the Elixir SDK's wire format.
pub fn to_prop_value(s: Shadow) -> PropValue {
  DictVal(
    dict.from_list([
      #("color", color.to_prop_value(s.color)),
      #("offset", ListVal([FloatVal(s.offset_x), FloatVal(s.offset_y)])),
      #("blur_radius", FloatVal(s.blur_radius)),
    ]),
  )
}
