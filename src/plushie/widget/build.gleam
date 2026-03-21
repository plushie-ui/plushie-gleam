//// Shared helpers for widget builder modules.

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import plushie/node.{type PropValue, BoolVal, FloatVal, IntVal, StringVal}

/// Insert a string prop.
pub fn put_string(
  props: Dict(String, PropValue),
  key: String,
  value: String,
) -> Dict(String, PropValue) {
  dict.insert(props, key, StringVal(value))
}

/// Insert a prop only if the Option is Some.
pub fn put_optional(
  props: Dict(String, PropValue),
  key: String,
  value: Option(a),
  encoder: fn(a) -> PropValue,
) -> Dict(String, PropValue) {
  case value {
    option.Some(v) -> dict.insert(props, key, encoder(v))
    option.None -> props
  }
}

/// Insert an optional bool prop.
pub fn put_optional_bool(
  props: Dict(String, PropValue),
  key: String,
  value: Option(Bool),
) -> Dict(String, PropValue) {
  put_optional(props, key, value, BoolVal)
}

/// Insert an optional int prop.
pub fn put_optional_int(
  props: Dict(String, PropValue),
  key: String,
  value: Option(Int),
) -> Dict(String, PropValue) {
  put_optional(props, key, value, IntVal)
}

/// Insert an optional float prop.
pub fn put_optional_float(
  props: Dict(String, PropValue),
  key: String,
  value: Option(Float),
) -> Dict(String, PropValue) {
  put_optional(props, key, value, FloatVal)
}

/// Insert an optional string prop.
pub fn put_optional_string(
  props: Dict(String, PropValue),
  key: String,
  value: Option(String),
) -> Dict(String, PropValue) {
  put_optional(props, key, value, StringVal)
}
