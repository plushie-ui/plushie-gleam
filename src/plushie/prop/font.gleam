//// Font types for text rendering.
////
//// Covers font family selection, weight, style, and stretch. DefaultFont
//// and Monospace are simple variants; Family picks a named font; CustomFont
//// allows full control over weight, style, and stretch.

import gleam/dict.{type Dict}
import plushie/node.{type PropValue, DictVal, StringVal}

pub type Font {
  DefaultFont
  Monospace
  Family(String)
  CustomFont(
    family: String,
    weight: FontWeight,
    style: FontStyle,
    stretch: FontStretch,
  )
}

pub type FontWeight {
  Thin
  ExtraLight
  Light
  Normal
  Medium
  SemiBold
  Bold
  ExtraBold
  Black
}

pub type FontStyle {
  NormalStyle
  Italic
  Oblique
}

pub type FontStretch {
  UltraCondensed
  ExtraCondensed
  Condensed
  SemiCondensed
  NormalStretch
  SemiExpanded
  Expanded
  ExtraExpanded
  UltraExpanded
}

/// Encode a Font to its wire-format PropValue.
pub fn to_prop_value(font: Font) -> PropValue {
  case font {
    DefaultFont -> StringVal("default")
    Monospace -> StringVal("monospace")
    Family(name) -> DictVal(dict.from_list([#("family", StringVal(name))]))
    CustomFont(family:, weight:, style:, stretch:) ->
      DictVal(custom_font_fields(family, weight, style, stretch))
  }
}

pub fn weight_to_string(w: FontWeight) -> String {
  case w {
    Thin -> "Thin"
    ExtraLight -> "ExtraLight"
    Light -> "Light"
    Normal -> "Normal"
    Medium -> "Medium"
    SemiBold -> "SemiBold"
    Bold -> "Bold"
    ExtraBold -> "ExtraBold"
    Black -> "Black"
  }
}

pub fn style_to_string(s: FontStyle) -> String {
  case s {
    NormalStyle -> "Normal"
    Italic -> "Italic"
    Oblique -> "Oblique"
  }
}

pub fn stretch_to_string(s: FontStretch) -> String {
  case s {
    UltraCondensed -> "UltraCondensed"
    ExtraCondensed -> "ExtraCondensed"
    Condensed -> "Condensed"
    SemiCondensed -> "SemiCondensed"
    NormalStretch -> "Normal"
    SemiExpanded -> "SemiExpanded"
    Expanded -> "Expanded"
    ExtraExpanded -> "ExtraExpanded"
    UltraExpanded -> "UltraExpanded"
  }
}

/// Build the dict for a CustomFont, omitting fields that match defaults
/// (NormalStyle for style, NormalStretch for stretch). Weight is always
/// included since there is no "default" weight -- the Elixir SDK treats
/// nil weight as omitted, not as "Normal".
fn custom_font_fields(
  family: String,
  weight: FontWeight,
  style: FontStyle,
  stretch: FontStretch,
) -> Dict(String, PropValue) {
  let fields = dict.from_list([#("family", StringVal(family))])
  let fields =
    dict.insert(fields, "weight", StringVal(weight_to_string(weight)))
  let fields = case style {
    NormalStyle -> fields
    _ -> dict.insert(fields, "style", StringVal(style_to_string(style)))
  }
  case stretch {
    NormalStretch -> fields
    _ -> dict.insert(fields, "stretch", StringVal(stretch_to_string(stretch)))
  }
}
