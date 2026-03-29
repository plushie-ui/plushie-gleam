//// Encode outbound messages for the plushie wire protocol.
////
//// Each function encodes a specific message type to wire format
//// (JSONL or MessagePack bytes). All outbound messages include a
//// "type" field identifying the message kind and a "session" field
//// for multiplexed session support.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/json
import gleam/list
import gleam/option
@target(erlang)
import glepack
@target(erlang)
import glepack/data
import plushie/app.{type Settings}
import plushie/node.{
  type Node, type PropValue, BinaryVal, BoolVal, DictVal, FloatVal, IntVal,
  ListVal, NullVal, StringVal,
}
import plushie/patch.{
  type PatchOp, InsertChild, RemoveChild, ReplaceNode, UpdateProps,
}
import plushie/prop/theme
import plushie/protocol.{
  type EncodeError, type Format, Json, Msgpack, SerializationFailed,
}

// --- PropValue conversion ----------------------------------------------------

/// Convert a PropValue to gleam_json's Json type.
pub fn prop_value_to_json(v: PropValue) -> json.Json {
  case v {
    StringVal(s) -> json.string(s)
    IntVal(n) -> json.int(n)
    FloatVal(f) -> json.float(f)
    BoolVal(b) -> json.bool(b)
    NullVal -> json.null()
    BinaryVal(bytes) -> json.string(bit_array.base64_encode(bytes, True))
    ListVal(items) ->
      json.preprocessed_array(list.map(items, prop_value_to_json))
    DictVal(d) ->
      dict.to_list(d)
      |> list.map(fn(pair) { #(pair.0, prop_value_to_json(pair.1)) })
      |> json.object
  }
}

@target(erlang)
/// Convert a PropValue to glepack's data.Value type.
pub fn prop_value_to_msgpack(v: PropValue) -> data.Value {
  case v {
    StringVal(s) -> data.String(s)
    IntVal(n) -> data.Integer(n)
    FloatVal(f) -> data.Float(f)
    BoolVal(b) -> data.Boolean(b)
    NullVal -> data.Nil
    BinaryVal(bytes) -> data.Binary(bytes)
    ListVal(items) -> data.Array(list.map(items, prop_value_to_msgpack))
    DictVal(d) ->
      dict.to_list(d)
      |> list.map(fn(pair) {
        #(data.String(pair.0), prop_value_to_msgpack(pair.1))
      })
      |> dict.from_list
      |> data.Map
  }
}

// --- Node conversion ---------------------------------------------------------

/// Convert a Node tree to a nested PropValue (DictVal).
/// Maps `kind` to the wire key `"type"`.
pub fn node_to_prop_value(n: Node) -> PropValue {
  // Meta is not included -- it's runtime-only data (widget
  // state, def) that the renderer doesn't understand.
  DictVal(
    dict.from_list([
      #("id", StringVal(n.id)),
      #("type", StringVal(n.kind)),
      #("props", DictVal(n.props)),
      #("children", ListVal(list.map(n.children, node_to_prop_value))),
    ]),
  )
}

// --- Serialization -----------------------------------------------------------

/// Serialize a message (represented as a Dict of PropValues) to wire bytes.
/// JSON format appends a newline; MessagePack produces raw bytes.
pub fn serialize(
  message: Dict(String, PropValue),
  format: Format,
) -> Result(BitArray, EncodeError) {
  case format {
    Json -> serialize_json(message)
    Msgpack -> serialize_msgpack(message)
  }
}

fn serialize_json(
  message: Dict(String, PropValue),
) -> Result(BitArray, EncodeError) {
  let j =
    dict.to_list(message)
    |> list.map(fn(pair) { #(pair.0, prop_value_to_json(pair.1)) })
    |> json.object
  let s = json.to_string(j) <> "\n"
  Ok(bit_array.from_string(s))
}

@target(erlang)
fn serialize_msgpack(
  message: Dict(String, PropValue),
) -> Result(BitArray, EncodeError) {
  let v = prop_value_to_msgpack(DictVal(message))
  case glepack.pack(v) {
    Ok(bytes) -> Ok(bytes)
    Error(_) -> Error(SerializationFailed("msgpack encoding failed"))
  }
}

@target(javascript)
fn serialize_msgpack(
  _message: Dict(String, PropValue),
) -> Result(BitArray, EncodeError) {
  Error(SerializationFailed("MessagePack not available on JavaScript target"))
}

// --- PatchOp conversion ------------------------------------------------------

/// Convert a PatchOp to its wire PropValue representation.
///
/// Paths are encoded as arrays of integers on the wire.
pub fn patch_op_to_prop_value(op: PatchOp) -> PropValue {
  case op {
    ReplaceNode(path:, node:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("replace_node")),
          #("path", path_to_prop_value(path)),
          #("node", node_to_prop_value(node)),
        ]),
      )
    UpdateProps(path:, props:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("update_props")),
          #("path", path_to_prop_value(path)),
          #("props", DictVal(props)),
        ]),
      )
    InsertChild(path:, index:, node:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("insert_child")),
          #("path", path_to_prop_value(path)),
          #("index", IntVal(index)),
          #("node", node_to_prop_value(node)),
        ]),
      )
    RemoveChild(path:, index:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("remove_child")),
          #("path", path_to_prop_value(path)),
          #("index", IntVal(index)),
        ]),
      )
  }
}

/// Encode a path (list of child indices) to a PropValue array.
fn path_to_prop_value(path: List(Int)) -> PropValue {
  ListVal(list.map(path, IntVal))
}

// --- Message builders --------------------------------------------------------

/// Build a message Dict with common fields.
fn message(
  msg_type: String,
  session: String,
  fields: List(#(String, PropValue)),
) -> Dict(String, PropValue) {
  dict.from_list([
    #("type", StringVal(msg_type)),
    #("session", StringVal(session)),
    ..fields
  ])
}

/// Encode a settings message sent on startup.
///
/// Settings are wrapped in a `"settings"` key in the wire message,
/// matching the Rust binary's expected format:
/// `{"type": "settings", "session": "", "settings": {...}}`
pub fn encode_settings(
  settings: Settings,
  session: String,
  format: Format,
  token: option.Option(String),
) -> Result(BitArray, EncodeError) {
  let settings_fields = [
    #("protocol_version", IntVal(protocol.protocol_version)),
    #("antialiasing", BoolVal(settings.antialiasing)),
    #("default_text_size", FloatVal(settings.default_text_size)),
    #("vsync", BoolVal(settings.vsync)),
    #("scale_factor", FloatVal(settings.scale_factor)),
  ]
  let settings_fields = case settings.theme {
    option.Some(t) -> [#("theme", theme.to_prop_value(t)), ..settings_fields]
    option.None -> settings_fields
  }
  let settings_fields = case settings.fonts {
    [] -> settings_fields
    fonts -> [
      #("fonts", ListVal(list.map(fonts, StringVal))),
      ..settings_fields
    ]
  }
  let settings_fields = case settings.default_font {
    option.Some(font) -> [#("default_font", font), ..settings_fields]
    option.None -> settings_fields
  }
  let settings_fields = case settings.default_event_rate {
    option.Some(rate) -> [
      #("default_event_rate", IntVal(rate)),
      ..settings_fields
    ]
    option.None -> settings_fields
  }
  let settings_fields = case token {
    option.Some(t) -> [#("token", StringVal(t)), ..settings_fields]
    option.None -> settings_fields
  }
  let fields = [#("settings", DictVal(dict.from_list(settings_fields)))]
  serialize(message("settings", session, fields), format)
}

/// Encode a full tree snapshot.
pub fn encode_snapshot(
  tree: Node,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("tree", node_to_prop_value(tree))]
  serialize(message("snapshot", session, fields), format)
}

/// Encode an incremental patch (list of diff operations).
pub fn encode_patch(
  ops: List(PatchOp),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("ops", ListVal(list.map(ops, patch_op_to_prop_value))),
  ]
  serialize(message("patch", session, fields), format)
}

/// Encode a widget operation (focus, scroll, etc.).
pub fn encode_widget_op(
  op: String,
  payload: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("op", StringVal(op)), #("payload", DictVal(payload))]
  serialize(message("widget_op", session, fields), format)
}

/// Encode a subscribe message to start an event source.
pub fn encode_subscribe(
  kind: String,
  tag: String,
  max_rate: option.Option(Int),
  window_id: option.Option(String),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("kind", StringVal(kind)), #("tag", StringVal(tag))]
  let fields = case max_rate {
    option.Some(rate) -> list.append(fields, [#("max_rate", IntVal(rate))])
    option.None -> fields
  }
  let fields = case window_id {
    option.Some(wid) -> list.append(fields, [#("window_id", StringVal(wid))])
    option.None -> fields
  }
  serialize(message("subscribe", session, fields), format)
}

/// Encode an unsubscribe message to stop an event source.
/// Includes the tag for targeted unsubscription when multiple
/// subscriptions of the same kind exist (e.g. window-scoped).
pub fn encode_unsubscribe(
  kind: String,
  tag: String,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("kind", StringVal(kind)), #("tag", StringVal(tag))]
  serialize(message("unsubscribe", session, fields), format)
}

/// Encode a window operation (open, close, configure).
pub fn encode_window_op(
  op: String,
  window_id: String,
  settings: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("op", StringVal(op)),
    #("window_id", StringVal(window_id)),
    #("settings", DictVal(settings)),
  ]
  serialize(message("window_op", session, fields), format)
}

/// Encode a system-wide operation.
pub fn encode_system_op(
  op: String,
  settings: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("op", StringVal(op)),
    #("settings", DictVal(settings)),
  ]
  serialize(message("system_op", session, fields), format)
}

/// Encode a system-wide query.
pub fn encode_system_query(
  op: String,
  settings: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("op", StringVal(op)),
    #("settings", DictVal(settings)),
  ]
  serialize(message("system_query", session, fields), format)
}

/// Encode a platform effect request (file dialog, clipboard, etc.).
pub fn encode_effect(
  id: String,
  kind: String,
  payload: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("id", StringVal(id)),
    #("kind", StringVal(kind)),
    #("payload", DictVal(payload)),
  ]
  serialize(message("effect", session, fields), format)
}

/// Encode an image operation (create_image, update_image, delete_image).
///
/// Payload fields are flat-merged into the top-level message dict
/// (not nested under "payload"), matching the Elixir reference.
pub fn encode_image_op(
  op: String,
  payload: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let base = message("image_op", session, [#("op", StringVal(op))])
  let merged = dict.merge(base, payload)
  serialize(merged, format)
}

/// Encode a widget command for native widget operations.
/// Wire key: "extension_command" (renderer-defined).
pub fn encode_extension_command(
  node_id: String,
  op: String,
  payload: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("node_id", StringVal(node_id)),
    #("op", StringVal(op)),
    #("payload", DictVal(payload)),
  ]
  serialize(message("extension_command", session, fields), format)
}

/// Encode a frame advance (test/headless mode).
pub fn encode_advance_frame(
  timestamp: Int,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("timestamp", IntVal(timestamp))]
  serialize(message("advance_frame", session, fields), format)
}

/// Encode an effect stub registration.
///
/// The renderer will return the given response value immediately
/// for any effect of this kind, without executing the real effect.
pub fn encode_register_effect_stub(
  kind: String,
  response: PropValue,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("kind", StringVal(kind)), #("response", response)]
  serialize(message("register_effect_stub", session, fields), format)
}

/// Encode an effect stub removal.
pub fn encode_unregister_effect_stub(
  kind: String,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("kind", StringVal(kind))]
  serialize(message("unregister_effect_stub", session, fields), format)
}

/// Encode an interact request (click, type_text, press, etc.).
///
/// Used by the scripting engine and testing infrastructure to perform
/// renderer-side interactions on the widget tree.
pub fn encode_interact(
  id: String,
  action: String,
  selector: Dict(String, PropValue),
  payload: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("id", StringVal(id)),
    #("action", StringVal(action)),
    #("selector", DictVal(selector)),
    #("payload", DictVal(payload)),
  ]
  serialize(message("interact", session, fields), format)
}
