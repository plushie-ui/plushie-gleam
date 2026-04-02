//// Shared helpers for widget builder modules.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import plushie/node.{
  type Node, type PropValue, BoolVal, FloatVal, IntVal, StringVal,
}

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

/// Validate that a widget has at most one child. Panics with a
/// descriptive message if the constraint is violated.
pub fn validate_single_child(
  id: String,
  kind: String,
  children: List(Node),
) -> Nil {
  case list.length(children) > 1 {
    True ->
      panic as {
        kind
        <> " \""
        <> id
        <> "\" accepts at most 1 child, got "
        <> int.to_string(list.length(children))
      }
    False -> Nil
  }
}

/// Validate that a widget has exactly 2 children. Panics with a
/// descriptive message if the constraint is violated.
pub fn validate_pair_children(
  id: String,
  kind: String,
  children: List(Node),
) -> Nil {
  let count = list.length(children)
  case count == 2 {
    True -> Nil
    False ->
      panic as {
        kind
        <> " \""
        <> id
        <> "\" requires exactly 2 children, got "
        <> int.to_string(count)
      }
  }
}
