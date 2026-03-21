//// StyleMap type for widget style overrides.
////
//// Wraps a string-keyed dictionary of PropValues. Builder functions
//// provide a typed API for common style properties while keeping the
//// internal representation wire-ready.

import gleam/dict.{type Dict}
import toddy/node.{type PropValue, DictVal, StringVal}
import toddy/prop/gradient.{type Gradient}

pub type StyleMap {
  StyleMap(props: Dict(String, PropValue))
}

/// Create an empty style map.
pub fn new() -> StyleMap {
  StyleMap(props: dict.new())
}

/// Set the background color (hex string).
pub fn background(sm: StyleMap, hex: String) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "background", StringVal(hex)))
}

/// Set the background to a gradient.
pub fn gradient_background(sm: StyleMap, g: Gradient) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "background", gradient.to_prop_value(g)))
}

/// Set the text color (hex string).
pub fn text_color(sm: StyleMap, hex: String) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "text_color", StringVal(hex)))
}

/// Set the base style (hex string).
pub fn base(sm: StyleMap, hex: String) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "base", StringVal(hex)))
}

/// Set a border PropValue (use border.to_prop_value to produce it).
pub fn border(sm: StyleMap, val: PropValue) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "border", val))
}

/// Set a shadow PropValue (use shadow.to_prop_value to produce it).
pub fn shadow(sm: StyleMap, val: PropValue) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "shadow", val))
}

/// Set the hovered state override as a nested StyleMap.
pub fn hovered(sm: StyleMap, override: StyleMap) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "hovered", to_prop_value(override)))
}

/// Set the pressed state override as a nested StyleMap.
pub fn pressed(sm: StyleMap, override: StyleMap) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "pressed", to_prop_value(override)))
}

/// Set the disabled state override as a nested StyleMap.
pub fn disabled(sm: StyleMap, override: StyleMap) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "disabled", to_prop_value(override)))
}

/// Set the focused state override as a nested StyleMap.
pub fn focused(sm: StyleMap, override: StyleMap) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, "focused", to_prop_value(override)))
}

/// Set an arbitrary property on the style map.
pub fn set(sm: StyleMap, key: String, val: PropValue) -> StyleMap {
  StyleMap(props: dict.insert(sm.props, key, val))
}

/// Encode a StyleMap to its wire-format PropValue.
pub fn to_prop_value(sm: StyleMap) -> PropValue {
  DictVal(sm.props)
}
