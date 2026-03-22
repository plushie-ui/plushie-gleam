import gleam/bit_array
import gleam/dict
import gleam/json
import gleam/option
import gleam/string
import gleeunit/should
import glepack
import glepack/data
import plushie/app
import plushie/node.{
  BinaryVal, BoolVal, DictVal, FloatVal, IntVal, ListVal, Node, NullVal,
  StringVal,
}
import plushie/patch
import plushie/prop/theme
import plushie/protocol
import plushie/protocol/encode

// --- prop_value_to_json ------------------------------------------------------

pub fn prop_value_to_json_string_test() {
  let j = encode.prop_value_to_json(StringVal("hello"))
  should.equal(json.to_string(j), "\"hello\"")
}

pub fn prop_value_to_json_int_test() {
  let j = encode.prop_value_to_json(IntVal(42))
  should.equal(json.to_string(j), "42")
}

pub fn prop_value_to_json_float_test() {
  let j = encode.prop_value_to_json(FloatVal(3.14))
  should.equal(json.to_string(j), "3.14")
}

pub fn prop_value_to_json_bool_test() {
  let j = encode.prop_value_to_json(BoolVal(True))
  should.equal(json.to_string(j), "true")
}

pub fn prop_value_to_json_null_test() {
  let j = encode.prop_value_to_json(NullVal)
  should.equal(json.to_string(j), "null")
}

pub fn prop_value_to_json_list_test() {
  let j = encode.prop_value_to_json(ListVal([IntVal(1), IntVal(2), IntVal(3)]))
  should.equal(json.to_string(j), "[1,2,3]")
}

pub fn prop_value_to_json_dict_test() {
  let j =
    encode.prop_value_to_json(DictVal(dict.from_list([#("k", StringVal("v"))])))
  should.equal(json.to_string(j), "{\"k\":\"v\"}")
}

// --- prop_value_to_msgpack ---------------------------------------------------

pub fn prop_value_to_msgpack_string_test() {
  let v = encode.prop_value_to_msgpack(StringVal("hi"))
  should.equal(v, data.String("hi"))
}

pub fn prop_value_to_msgpack_int_test() {
  let v = encode.prop_value_to_msgpack(IntVal(99))
  should.equal(v, data.Integer(99))
}

pub fn prop_value_to_msgpack_float_test() {
  let v = encode.prop_value_to_msgpack(FloatVal(1.5))
  should.equal(v, data.Float(1.5))
}

pub fn prop_value_to_msgpack_bool_test() {
  let v = encode.prop_value_to_msgpack(BoolVal(False))
  should.equal(v, data.Boolean(False))
}

pub fn prop_value_to_msgpack_null_test() {
  let v = encode.prop_value_to_msgpack(NullVal)
  should.equal(v, data.Nil)
}

pub fn prop_value_to_msgpack_list_test() {
  let v = encode.prop_value_to_msgpack(ListVal([IntVal(1), StringVal("a")]))
  should.equal(v, data.Array([data.Integer(1), data.String("a")]))
}

pub fn prop_value_to_msgpack_dict_test() {
  let v =
    encode.prop_value_to_msgpack(DictVal(dict.from_list([#("x", IntVal(7))])))
  let expected =
    data.Map(dict.from_list([#(data.String("x"), data.Integer(7))]))
  should.equal(v, expected)
}

// --- node_to_prop_value ------------------------------------------------------

pub fn node_to_prop_value_maps_kind_to_type_test() {
  let n =
    Node(
      id: "btn",
      kind: "button",
      props: dict.from_list([#("label", StringVal("Click"))]),
      children: [],
    )
  let result = encode.node_to_prop_value(n)
  let assert DictVal(d) = result
  should.equal(dict.get(d, "id"), Ok(StringVal("btn")))
  should.equal(dict.get(d, "type"), Ok(StringVal("button")))

  let assert Ok(DictVal(props)) = dict.get(d, "props")
  should.equal(dict.get(props, "label"), Ok(StringVal("Click")))

  should.equal(dict.get(d, "children"), Ok(ListVal([])))
}

pub fn node_to_prop_value_nested_children_test() {
  let child = Node(id: "t", kind: "text", props: dict.new(), children: [])
  let parent =
    Node(id: "col", kind: "column", props: dict.new(), children: [child])
  let result = encode.node_to_prop_value(parent)
  let assert DictVal(d) = result
  let assert Ok(ListVal([DictVal(child_dict)])) = dict.get(d, "children")
  should.equal(dict.get(child_dict, "id"), Ok(StringVal("t")))
  should.equal(dict.get(child_dict, "type"), Ok(StringVal("text")))
}

// --- serialize ---------------------------------------------------------------

pub fn serialize_json_produces_newline_terminated_string_test() {
  let msg =
    dict.from_list([
      #("type", StringVal("test")),
      #("session", StringVal("")),
    ])
  let assert Ok(bytes) = encode.serialize(msg, protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.ends_with(s, "\n")
  let trimmed = string.drop_end(s, 1)
  assert string.contains(trimmed, "\"type\"")
  assert string.contains(trimmed, "\"test\"")
}

pub fn serialize_msgpack_round_trips_test() {
  let msg =
    dict.from_list([
      #("type", StringVal("ping")),
      #("value", IntVal(42)),
    ])
  let assert Ok(bytes) = encode.serialize(msg, protocol.Msgpack)
  let assert Ok(#(decoded, _rest)) = glepack.unpack(bytes)
  let assert data.Map(m) = decoded
  should.equal(dict.get(m, data.String("type")), Ok(data.String("ping")))
  should.equal(dict.get(m, data.String("value")), Ok(data.Integer(42)))
}

// --- encode_settings ---------------------------------------------------------

pub fn encode_settings_json_wraps_in_settings_key_test() {
  let settings = app.default_settings()
  let assert Ok(bytes) =
    encode.encode_settings(settings, "", protocol.Json, option.None)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"settings\"")
  assert string.contains(s, "\"session\":\"\"")
  // Settings fields should be nested under "settings" key
  assert string.contains(s, "\"settings\":{")
  assert string.contains(s, "\"protocol_version\":1")
  assert string.contains(s, "\"antialiasing\":true")
  assert string.contains(s, "\"default_text_size\":16.0")
}

pub fn encode_settings_without_theme_omits_theme_test() {
  let settings = app.default_settings()
  let assert Ok(bytes) =
    encode.encode_settings(settings, "", protocol.Json, option.None)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert !string.contains(s, "\"theme\"")
}

pub fn encode_settings_with_theme_includes_theme_test() {
  let settings =
    app.Settings(..app.default_settings(), theme: option.Some(theme.Dark))
  let assert Ok(bytes) =
    encode.encode_settings(settings, "", protocol.Json, option.None)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"theme\":\"dark\"")
}

pub fn encode_settings_with_fonts_includes_fonts_test() {
  let settings =
    app.Settings(..app.default_settings(), fonts: ["Fira Code", "Inter"])
  let assert Ok(bytes) =
    encode.encode_settings(settings, "", protocol.Json, option.None)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"fonts\"")
  assert string.contains(s, "\"Fira Code\"")
  assert string.contains(s, "\"Inter\"")
}

pub fn encode_settings_msgpack_has_nested_settings_test() {
  let settings = app.default_settings()
  let assert Ok(bytes) =
    encode.encode_settings(settings, "s1", protocol.Msgpack, option.None)
  let assert Ok(#(decoded, _)) = glepack.unpack(bytes)
  let assert data.Map(m) = decoded
  should.equal(dict.get(m, data.String("type")), Ok(data.String("settings")))
  should.equal(dict.get(m, data.String("session")), Ok(data.String("s1")))
  // Settings should be nested in a "settings" key
  let assert Ok(data.Map(settings_map)) = dict.get(m, data.String("settings"))
  should.equal(
    dict.get(settings_map, data.String("protocol_version")),
    Ok(data.Integer(1)),
  )
}

// --- encode_snapshot ---------------------------------------------------------

pub fn encode_snapshot_wraps_tree_test() {
  let tree =
    Node(
      id: "main",
      kind: "window",
      props: dict.from_list([#("title", StringVal("App"))]),
      children: [],
    )
  let assert Ok(bytes) = encode.encode_snapshot(tree, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"snapshot\"")
  assert string.contains(s, "\"tree\"")
  assert string.contains(s, "\"main\"")
}

pub fn encode_snapshot_msgpack_round_trip_test() {
  let tree = Node(id: "r", kind: "container", props: dict.new(), children: [])
  let assert Ok(bytes) = encode.encode_snapshot(tree, "", protocol.Msgpack)
  let assert Ok(#(decoded, _)) = glepack.unpack(bytes)
  let assert data.Map(m) = decoded
  should.equal(dict.get(m, data.String("type")), Ok(data.String("snapshot")))
  let assert Ok(data.Map(_)) = dict.get(m, data.String("tree"))
}

// --- encode_patch ------------------------------------------------------------

pub fn encode_patch_update_props_test() {
  let ops = [
    patch.UpdateProps(
      path: [0, 1],
      props: dict.from_list([#("value", StringVal("new"))]),
    ),
  ]
  let assert Ok(bytes) = encode.encode_patch(ops, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"patch\"")
  assert string.contains(s, "\"update_props\"")
  // Path should be an array of integers
  assert string.contains(s, "\"path\":[0,1]")
}

pub fn encode_patch_replace_node_test() {
  let replacement =
    Node(id: "new", kind: "text", props: dict.new(), children: [])
  let ops = [patch.ReplaceNode(path: [], node: replacement)]
  let assert Ok(bytes) = encode.encode_patch(ops, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"replace_node\"")
  assert string.contains(s, "\"path\":[]")
}

pub fn encode_patch_insert_child_test() {
  let child = Node(id: "added", kind: "button", props: dict.new(), children: [])
  let ops = [patch.InsertChild(path: [0], index: 2, node: child)]
  let assert Ok(bytes) = encode.encode_patch(ops, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"insert_child\"")
  assert string.contains(s, "\"path\":[0]")
  assert string.contains(s, "\"index\":2")
}

pub fn encode_patch_remove_child_test() {
  let ops = [patch.RemoveChild(path: [0], index: 3)]
  let assert Ok(bytes) = encode.encode_patch(ops, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"remove_child\"")
  assert string.contains(s, "\"index\":3")
}

pub fn encode_patch_multiple_ops_test() {
  let ops = [
    patch.RemoveChild(path: [0], index: 2),
    patch.RemoveChild(path: [0], index: 1),
  ]
  let assert Ok(bytes) = encode.encode_patch(ops, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"ops\"")
  assert string.contains(s, "\"remove_child\"")
}

pub fn encode_patch_msgpack_round_trip_test() {
  let ops = [
    patch.UpdateProps(path: [0], props: dict.from_list([#("v", IntVal(1))])),
  ]
  let assert Ok(bytes) = encode.encode_patch(ops, "", protocol.Msgpack)
  let assert Ok(#(decoded, _)) = glepack.unpack(bytes)
  let assert data.Map(m) = decoded
  should.equal(dict.get(m, data.String("type")), Ok(data.String("patch")))
  let assert Ok(data.Array([data.Map(op_map)])) =
    dict.get(m, data.String("ops"))
  should.equal(
    dict.get(op_map, data.String("op")),
    Ok(data.String("update_props")),
  )
}

// --- encode_subscribe / encode_unsubscribe -----------------------------------

pub fn encode_subscribe_test() {
  let assert Ok(bytes) =
    encode.encode_subscribe(
      "on_key_press",
      "keys",
      option.None,
      "",
      protocol.Json,
    )
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"subscribe\"")
  assert string.contains(s, "\"kind\":\"on_key_press\"")
  assert string.contains(s, "\"tag\":\"keys\"")
}

pub fn encode_subscribe_with_max_rate_test() {
  let assert Ok(bytes) =
    encode.encode_subscribe(
      "on_mouse_move",
      "mouse",
      option.Some(30),
      "",
      protocol.Json,
    )
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"subscribe\"")
  assert string.contains(s, "\"kind\":\"on_mouse_move\"")
  assert string.contains(s, "\"tag\":\"mouse\"")
  assert string.contains(s, "\"max_rate\":30")
}

pub fn encode_unsubscribe_test() {
  let assert Ok(bytes) =
    encode.encode_unsubscribe("on_key_press", "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"unsubscribe\"")
  assert string.contains(s, "\"kind\":\"on_key_press\"")
}

// --- encode_widget_op --------------------------------------------------------

pub fn encode_widget_op_test() {
  let payload = dict.from_list([#("id", StringVal("email_input"))])
  let assert Ok(bytes) =
    encode.encode_widget_op("focus", payload, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"widget_op\"")
  assert string.contains(s, "\"op\":\"focus\"")
  assert string.contains(s, "\"email_input\"")
}

// --- encode_window_op --------------------------------------------------------

pub fn encode_window_op_test() {
  let settings = dict.from_list([#("title", StringVal("Settings"))])
  let assert Ok(bytes) =
    encode.encode_window_op("open", "settings_win", settings, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"window_op\"")
  assert string.contains(s, "\"window_id\":\"settings_win\"")
  assert string.contains(s, "\"Settings\"")
}

// --- encode_effect -----------------------------------------------------------

pub fn encode_effect_test() {
  let payload = dict.from_list([#("path", StringVal("/tmp"))])
  let assert Ok(bytes) =
    encode.encode_effect("req-1", "open_file", payload, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"effect\"")
  assert string.contains(s, "\"id\":\"req-1\"")
  assert string.contains(s, "\"kind\":\"open_file\"")
}

// --- encode_image_op ---------------------------------------------------------

pub fn encode_image_op_flat_merges_payload_test() {
  let payload =
    dict.from_list([
      #("handle", StringVal("img-1")),
      #("data", BinaryVal(<<1, 2, 3>>)),
    ])
  let assert Ok(bytes) =
    encode.encode_image_op("create_image", payload, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"image_op\"")
  assert string.contains(s, "\"op\":\"create_image\"")
  // Payload fields are flat-merged, not nested under "payload"
  assert string.contains(s, "\"handle\":\"img-1\"")
  assert !string.contains(s, "\"payload\"")
  // Binary data is base64-encoded in JSON
  assert string.contains(s, "\"data\":\"AQID\"")
}

pub fn encode_image_op_msgpack_binary_native_test() {
  let payload =
    dict.from_list([
      #("handle", StringVal("logo")),
      #("data", BinaryVal(<<255, 0, 128>>)),
    ])
  let assert Ok(bytes) =
    encode.encode_image_op("create_image", payload, "", protocol.Msgpack)
  let assert Ok(#(decoded, _)) = glepack.unpack(bytes)
  let assert data.Map(m) = decoded
  should.equal(dict.get(m, data.String("type")), Ok(data.String("image_op")))
  should.equal(dict.get(m, data.String("op")), Ok(data.String("create_image")))
  should.equal(dict.get(m, data.String("handle")), Ok(data.String("logo")))
  // Binary data uses native msgpack binary type
  should.equal(
    dict.get(m, data.String("data")),
    Ok(data.Binary(<<255, 0, 128>>)),
  )
}

pub fn encode_image_op_delete_test() {
  let payload = dict.from_list([#("handle", StringVal("old-img"))])
  let assert Ok(bytes) =
    encode.encode_image_op("delete_image", payload, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"op\":\"delete_image\"")
  assert string.contains(s, "\"handle\":\"old-img\"")
  assert !string.contains(s, "\"payload\"")
}

// --- BinaryVal encoding ------------------------------------------------------

pub fn prop_value_to_json_binary_base64_test() {
  let j = encode.prop_value_to_json(BinaryVal(<<1, 2, 3>>))
  should.equal(json.to_string(j), "\"AQID\"")
}

pub fn prop_value_to_msgpack_binary_test() {
  let v = encode.prop_value_to_msgpack(BinaryVal(<<10, 20>>))
  should.equal(v, data.Binary(<<10, 20>>))
}

// --- encode_extension_command ------------------------------------------------

pub fn encode_extension_command_test() {
  let payload = dict.from_list([#("color", StringVal("red"))])
  let assert Ok(bytes) =
    encode.encode_extension_command(
      "canvas-1",
      "set_bg",
      payload,
      "",
      protocol.Json,
    )
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"extension_command\"")
  assert string.contains(s, "\"node_id\":\"canvas-1\"")
  assert string.contains(s, "\"op\":\"set_bg\"")
}

// --- encode_advance_frame ----------------------------------------------------

pub fn encode_advance_frame_test() {
  let assert Ok(bytes) = encode.encode_advance_frame(1000, "", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"type\":\"advance_frame\"")
  assert string.contains(s, "\"timestamp\":1000")
}

pub fn encode_advance_frame_msgpack_test() {
  let assert Ok(bytes) =
    encode.encode_advance_frame(500, "sess", protocol.Msgpack)
  let assert Ok(#(decoded, _)) = glepack.unpack(bytes)
  let assert data.Map(m) = decoded
  should.equal(
    dict.get(m, data.String("type")),
    Ok(data.String("advance_frame")),
  )
  should.equal(dict.get(m, data.String("timestamp")), Ok(data.Integer(500)))
  should.equal(dict.get(m, data.String("session")), Ok(data.String("sess")))
}

// --- Session field -----------------------------------------------------------

pub fn all_messages_include_session_test() {
  let assert Ok(bytes) =
    encode.encode_advance_frame(0, "my-session", protocol.Json)
  let assert Ok(s) = bit_array.to_string(bytes)
  assert string.contains(s, "\"session\":\"my-session\"")
}
