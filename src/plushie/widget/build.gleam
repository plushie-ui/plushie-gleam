//// Shared helpers for widget builder modules.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import plushie/node.{
  type Node, type PropValue, BoolVal, DictVal, FloatVal, IntVal, StringVal,
}
import plushie/prop/a11y.{type A11y}

/// Insert a pre-encoded animation descriptor (Transition, Spring, or
/// Sequence) as a prop value. The animation must already be encoded via
/// its module's `encode` function.
pub fn put_animated(
  props: Dict(String, PropValue),
  key: String,
  animation: PropValue,
) -> Dict(String, PropValue) {
  dict.insert(props, key, animation)
}

/// Merge animated prop overrides into a props dict. Animated values
/// take precedence over statically-encoded values for the same key.
pub fn merge_animated(
  props: Dict(String, PropValue),
  animated: Dict(String, PropValue),
) -> Dict(String, PropValue) {
  dict.merge(props, animated)
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

/// Apply default a11y props to a node's prop dict when no explicit a11y is set.
/// `role` is the default role string, `label_from_key` is an optional prop key
/// to derive the label from (e.g. "label", "placeholder", "content").
pub fn apply_default_a11y(
  props: Dict(String, PropValue),
  a11y_opt: Option(A11y),
  role: String,
  label_from_key: Option(String),
) -> Dict(String, PropValue) {
  apply_default_a11y_props(props, a11y_opt, role, label_from_key, [])
}

/// Apply default a11y props plus widget-specific defaults.
pub fn apply_default_a11y_props(
  props: Dict(String, PropValue),
  a11y_opt: Option(A11y),
  role: String,
  label_from_key: Option(String),
  extra_props: List(#(String, PropValue)),
) -> Dict(String, PropValue) {
  case a11y_opt {
    option.Some(explicit) ->
      dict.insert(props, "a11y", a11y.to_prop_value(explicit))
    option.None -> {
      let a11y_props = [#("role", StringVal(role)), ..extra_props]
      let a11y_props = case label_from_key {
        option.Some(key) ->
          case dict.get(props, key) {
            Ok(StringVal(label)) -> [#("label", StringVal(label)), ..a11y_props]
            _ -> a11y_props
          }
        option.None -> a11y_props
      }
      dict.insert(props, "a11y", DictVal(dict.from_list(a11y_props)))
    }
  }
}
