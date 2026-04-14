/// Cross-format round-trip tests.
///
/// Encodes trees and messages as both JSON and MessagePack, then
/// verifies the decoded representations are structurally equivalent.
/// Catches encoding asymmetries between formats (e.g. a field present
/// in one format but missing in the other, or type coercion differences).
import gleam/bit_array
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import glepack
import glepack/data
import plushie/app
import plushie/node.{
  BoolVal, DictVal, FloatVal, IntVal, ListVal, Node, NullVal, StringVal,
}
import plushie/patch
import plushie/protocol
import plushie/protocol/encode

// -- Helpers ------------------------------------------------------------------

/// Convert a JSON-parsed Dynamic value into a glepack data.Value for
/// structural comparison with MsgPack output.
///
/// JSON numbers are always decoded as floats by gleam_json when they
/// have a decimal point, but integers survive as ints. The normalize
/// step handles any residual differences.
fn json_dynamic_to_data_value(dyn: Dynamic) -> data.Value {
  case decode.run(dyn, decode.string) {
    Ok(s) -> data.String(s)
    Error(_) ->
      case decode.run(dyn, decode.bool) {
        Ok(b) -> data.Boolean(b)
        Error(_) ->
          case decode.run(dyn, decode.int) {
            Ok(n) -> data.Integer(n)
            Error(_) ->
              case decode.run(dyn, decode.float) {
                Ok(f) -> data.Float(f)
                Error(_) ->
                  case decode.run(dyn, decode.list(decode.dynamic)) {
                    Ok(items) ->
                      data.Array(list.map(items, json_dynamic_to_data_value))
                    Error(_) ->
                      case
                        decode.run(
                          dyn,
                          decode.dict(decode.string, decode.dynamic),
                        )
                      {
                        Ok(entries) -> {
                          let pairs =
                            dict.to_list(entries)
                            |> list.map(fn(pair) {
                              #(
                                data.String(pair.0),
                                json_dynamic_to_data_value(pair.1),
                              )
                            })
                          data.Map(dict.from_list(pairs))
                        }
                        Error(_) -> data.Nil
                      }
                  }
              }
          }
      }
  }
}

/// Normalize a data.Value for comparison: convert Float values that
/// are exact integers back to Integer (JSON parses all numbers
/// as float when they have `.0`, but MsgPack preserves the type).
fn normalize_data_value(v: data.Value) -> data.Value {
  case v {
    data.Float(f) -> {
      case is_exact_integer(f) {
        True -> data.Integer(float_truncate(f))
        False -> data.Float(f)
      }
    }
    data.Array(items) -> data.Array(list.map(items, normalize_data_value))
    data.Map(m) -> {
      let entries =
        dict.to_list(m)
        |> list.map(fn(pair) {
          #(normalize_data_value(pair.0), normalize_data_value(pair.1))
        })
      data.Map(dict.from_list(entries))
    }
    _ -> v
  }
}

fn is_exact_integer(f: Float) -> Bool {
  let i = float_truncate(f)
  let back = int_to_float(i)
  f == back
}

@external(erlang, "erlang", "trunc")
fn float_truncate(f: Float) -> Int

@external(erlang, "erlang", "float")
fn int_to_float(i: Int) -> Float

/// Decode wire bytes from both formats, normalize, and compare.
fn assert_format_equivalence(
  json_bytes: BitArray,
  msgpack_bytes: BitArray,
) -> Nil {
  // Decode JSON
  let assert Ok(json_str) = bit_array.to_string(json_bytes)
  let trimmed = string.trim(json_str)
  let assert Ok(json_dyn) = json.parse(trimmed, decode.dynamic)
  let json_val = json_dynamic_to_data_value(json_dyn)

  // Decode MsgPack
  let assert Ok(#(msgpack_val, _rest)) = glepack.unpack(msgpack_bytes)

  // Normalize both and compare
  let json_normalized = normalize_data_value(json_val)
  let msgpack_normalized = normalize_data_value(msgpack_val)

  should.equal(json_normalized, msgpack_normalized)
}

// -- Tests --------------------------------------------------------------------

pub fn snapshot_simple_tree_round_trip_test() {
  let tree =
    Node(
      id: "main",
      kind: "window",
      props: dict.from_list([#("title", StringVal("Hello"))]),
      children: [],
      meta: dict.new(),
    )

  let assert Ok(json_bytes) =
    encode.encode_snapshot(tree, "test", protocol.Json)
  let assert Ok(msgpack_bytes) =
    encode.encode_snapshot(tree, "test", protocol.Msgpack)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn snapshot_nested_tree_round_trip_test() {
  let child_a =
    Node(
      id: "btn",
      kind: "button",
      props: dict.from_list([
        #("label", StringVal("Click")),
        #("width", IntVal(100)),
      ]),
      children: [],
      meta: dict.new(),
    )
  let child_b =
    Node(
      id: "slider",
      kind: "slider",
      props: dict.from_list([
        #("value", FloatVal(0.75)),
        #("min", FloatVal(0.0)),
        #("max", FloatVal(1.0)),
      ]),
      children: [],
      meta: dict.new(),
    )
  let tree =
    Node(
      id: "main",
      kind: "window",
      props: dict.from_list([#("title", StringVal("App"))]),
      children: [child_a, child_b],
      meta: dict.new(),
    )

  let assert Ok(json_bytes) =
    encode.encode_snapshot(tree, "test", protocol.Json)
  let assert Ok(msgpack_bytes) =
    encode.encode_snapshot(tree, "test", protocol.Msgpack)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn snapshot_all_prop_types_round_trip_test() {
  let tree =
    Node(
      id: "root",
      kind: "container",
      props: dict.from_list([
        #("str", StringVal("text")),
        #("int", IntVal(42)),
        #("float", FloatVal(3.14)),
        #("bool_t", BoolVal(True)),
        #("bool_f", BoolVal(False)),
        #("null", NullVal),
        #("list", ListVal([StringVal("a"), IntVal(1), BoolVal(False), NullVal])),
        #(
          "dict",
          DictVal(
            dict.from_list([
              #("nested_str", StringVal("inner")),
              #("nested_int", IntVal(99)),
            ]),
          ),
        ),
      ]),
      children: [],
      meta: dict.new(),
    )

  let assert Ok(json_bytes) =
    encode.encode_snapshot(tree, "test", protocol.Json)
  let assert Ok(msgpack_bytes) =
    encode.encode_snapshot(tree, "test", protocol.Msgpack)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn patch_ops_round_trip_test() {
  let ops = [
    patch.UpdateProps(
      path: [0, 1],
      props: dict.from_list([
        #("label", StringVal("Updated")),
        #("count", IntVal(5)),
      ]),
    ),
    patch.InsertChild(
      path: [0],
      index: 2,
      node: Node(
        id: "new",
        kind: "text",
        props: dict.from_list([#("content", StringVal("hello"))]),
        children: [],
        meta: dict.new(),
      ),
    ),
    patch.RemoveChild(path: [1], index: 0),
    patch.ReplaceNode(
      path: [0, 0],
      node: Node(
        id: "replaced",
        kind: "button",
        props: dict.new(),
        children: [],
        meta: dict.new(),
      ),
    ),
  ]

  let assert Ok(json_bytes) = encode.encode_patch(ops, "test", protocol.Json)
  let assert Ok(msgpack_bytes) =
    encode.encode_patch(ops, "test", protocol.Msgpack)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn settings_round_trip_test() {
  let settings = app.default_settings()

  let assert Ok(json_bytes) =
    encode.encode_settings(settings, "s1", protocol.Json, option.None)
  let assert Ok(msgpack_bytes) =
    encode.encode_settings(settings, "s1", protocol.Msgpack, option.None)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn subscribe_round_trip_test() {
  let assert Ok(json_bytes) =
    encode.encode_subscribe(
      "on_key_press",
      "keys",
      option.Some(60),
      option.None,
      "sess",
      protocol.Json,
    )
  let assert Ok(msgpack_bytes) =
    encode.encode_subscribe(
      "on_key_press",
      "keys",
      option.Some(60),
      option.None,
      "sess",
      protocol.Msgpack,
    )

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn command_round_trip_test() {
  let payload = dict.from_list([#("color", StringVal("red"))])

  let assert Ok(json_bytes) =
    encode.encode_command("canvas-1", "set_bg", payload, "s", protocol.Json)
  let assert Ok(msgpack_bytes) =
    encode.encode_command("canvas-1", "set_bg", payload, "s", protocol.Msgpack)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}

pub fn advance_frame_round_trip_test() {
  let assert Ok(json_bytes) =
    encode.encode_advance_frame(1234, "sess", protocol.Json)
  let assert Ok(msgpack_bytes) =
    encode.encode_advance_frame(1234, "sess", protocol.Msgpack)

  assert_format_equivalence(json_bytes, msgpack_bytes)
}
