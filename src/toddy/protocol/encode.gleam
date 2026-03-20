//// Encode outbound messages for the toddy wire protocol.
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
import glepack
import glepack/data
import toddy/app.{type Settings}
import toddy/node.{
  type Node, type PropValue, BoolVal, DictVal, FloatVal, IntVal, ListVal,
  NullVal, StringVal,
}
import toddy/patch.{
  type PatchOp, DeleteNode, InsertChild, MoveNode, ReplaceNode, UpdateProps,
}
import toddy/prop/theme
import toddy/protocol.{
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
    ListVal(items) ->
      json.preprocessed_array(list.map(items, prop_value_to_json))
    DictVal(d) ->
      dict.to_list(d)
      |> list.map(fn(pair) { #(pair.0, prop_value_to_json(pair.1)) })
      |> json.object
  }
}

/// Convert a PropValue to glepack's data.Value type.
pub fn prop_value_to_msgpack(v: PropValue) -> data.Value {
  case v {
    StringVal(s) -> data.String(s)
    IntVal(n) -> data.Integer(n)
    FloatVal(f) -> data.Float(f)
    BoolVal(b) -> data.Boolean(b)
    NullVal -> data.Nil
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
    Json -> {
      let j =
        dict.to_list(message)
        |> list.map(fn(pair) { #(pair.0, prop_value_to_json(pair.1)) })
        |> json.object
      let s = json.to_string(j) <> "\n"
      Ok(bit_array.from_string(s))
    }
    Msgpack -> {
      let v = prop_value_to_msgpack(DictVal(message))
      case glepack.pack(v) {
        Ok(bytes) -> Ok(bytes)
        Error(_) -> Error(SerializationFailed("msgpack encoding failed"))
      }
    }
  }
}

// --- PatchOp conversion ------------------------------------------------------

/// Convert a PatchOp to its wire PropValue representation.
pub fn patch_op_to_prop_value(op: PatchOp) -> PropValue {
  case op {
    ReplaceNode(path:, node:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("replace_node")),
          #("path", StringVal(path)),
          #("node", node_to_prop_value(node)),
        ]),
      )
    UpdateProps(path:, props:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("update_props")),
          #("path", StringVal(path)),
          #("props", DictVal(props)),
        ]),
      )
    InsertChild(path:, index:, node:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("insert_child")),
          #("path", StringVal(path)),
          #("index", IntVal(index)),
          #("node", node_to_prop_value(node)),
        ]),
      )
    DeleteNode(path:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("delete_node")),
          #("path", StringVal(path)),
        ]),
      )
    MoveNode(path:, index:) ->
      DictVal(
        dict.from_list([
          #("op", StringVal("move_node")),
          #("path", StringVal(path)),
          #("index", IntVal(index)),
        ]),
      )
  }
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
pub fn encode_settings(
  settings: Settings,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [
    #("protocol_version", IntVal(protocol.protocol_version)),
    #("antialiasing", BoolVal(settings.antialiasing)),
    #("default_text_size", FloatVal(settings.default_text_size)),
    #("vsync", BoolVal(settings.vsync)),
    #("scale_factor", FloatVal(settings.scale_factor)),
  ]
  let fields = case settings.theme {
    option.Some(t) -> [#("theme", theme.to_prop_value(t)), ..fields]
    option.None -> fields
  }
  let fields = case settings.fonts {
    [] -> fields
    fonts -> [#("fonts", ListVal(list.map(fonts, StringVal))), ..fields]
  }
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
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("kind", StringVal(kind)), #("tag", StringVal(tag))]
  serialize(message("subscribe", session, fields), format)
}

/// Encode an unsubscribe message to stop an event source.
pub fn encode_unsubscribe(
  kind: String,
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("kind", StringVal(kind))]
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

/// Encode an image operation (create, update, delete).
pub fn encode_image_op(
  op: String,
  payload: Dict(String, PropValue),
  session: String,
  format: Format,
) -> Result(BitArray, EncodeError) {
  let fields = [#("op", StringVal(op)), #("payload", DictVal(payload))]
  serialize(message("image_op", session, fields), format)
}

/// Encode an extension command for custom widget operations.
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
