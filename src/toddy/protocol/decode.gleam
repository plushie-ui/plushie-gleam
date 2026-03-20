//// Decode inbound wire messages into typed Gleam values.
////
//// Supports both MessagePack and JSON wire formats. The Rust binary sends
//// three top-level message types: "hello" (handshake), "event" (user
//// interaction dispatched by family), and "effect_response" (platform
//// result). Additionally, "op_query_response" messages carry system
//// query results.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import glepack
import glepack/data
import glepack/error as glepack_error
import toddy/event.{
  type Event, type KeyLocation, type Modifiers, type MouseButton,
  type ScrollUnit,
}
import toddy/protocol

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// A decoded inbound message from the Rust binary.
pub type InboundMessage {
  /// Handshake sent by the Rust binary on startup.
  Hello(
    protocol: Int,
    version: String,
    name: String,
    backend: String,
    extensions: List(String),
  )

  /// A user interaction or system event.
  EventMessage(Event)
}

// ---------------------------------------------------------------------------
// PropValue -- internal intermediate representation
// ---------------------------------------------------------------------------

/// Internal JSON-like value used as the common representation after
/// deserializing either MessagePack or JSON wire data.
type PropValue {
  PString(String)
  PInt(Int)
  PFloat(Float)
  PBool(Bool)
  PNull
  PList(List(PropValue))
  PMap(Dict(String, PropValue))
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Decode raw wire bytes into an InboundMessage.
pub fn decode_message(
  data: BitArray,
  format: protocol.Format,
) -> Result(InboundMessage, protocol.DecodeError) {
  use map <- result.try(deserialize(data, format))
  dispatch(map)
}

/// Split a scoped wire ID into (local_id, scope_list).
///
/// Named containers scope their children with "/" separators. The scope
/// list is reversed so the nearest container is first.
///
///     split_scoped_id("form/email")
///     // -> #("email", ["form"])
///
///     split_scoped_id("sidebar/form/email")
///     // -> #("email", ["form", "sidebar"])
///
///     split_scoped_id("button")
///     // -> #("button", [])
///
pub fn split_scoped_id(wire_id: String) -> #(String, List(String)) {
  case string.split(wire_id, "/") {
    [local] -> #(local, [])
    parts -> {
      let assert [local, ..scope] = list.reverse(parts)
      #(local, scope)
    }
  }
}

// ---------------------------------------------------------------------------
// Deserialization -- wire bytes to Dict(String, PropValue)
// ---------------------------------------------------------------------------

fn deserialize(
  data: BitArray,
  format: protocol.Format,
) -> Result(Dict(String, PropValue), protocol.DecodeError) {
  case format {
    protocol.Msgpack -> deserialize_msgpack(data)
    protocol.Json -> deserialize_json(data)
  }
}

fn deserialize_msgpack(
  data: BitArray,
) -> Result(Dict(String, PropValue), protocol.DecodeError) {
  case glepack.unpack_exact(data) {
    Ok(value) ->
      case msgpack_to_prop(value) {
        PMap(map) -> Ok(map)
        _ ->
          Error(protocol.DeserializationFailed("top-level value is not a map"))
      }
    Error(e) ->
      Error(protocol.DeserializationFailed(glepack_error.to_string(e)))
  }
}

fn deserialize_json(
  data: BitArray,
) -> Result(Dict(String, PropValue), protocol.DecodeError) {
  case bit_array.to_string(data) {
    Error(_) -> Error(protocol.DeserializationFailed("invalid UTF-8"))
    Ok(text) -> {
      let text = string.trim_end(text)
      case json.parse(text, decode.dynamic) {
        Ok(dyn) ->
          case dynamic_to_prop(dyn) {
            PMap(map) -> Ok(map)
            _ ->
              Error(protocol.DeserializationFailed(
                "top-level value is not a map",
              ))
          }
        Error(_) -> Error(protocol.DeserializationFailed("invalid JSON"))
      }
    }
  }
}

// ---------------------------------------------------------------------------
// MessagePack data.Value -> PropValue
// ---------------------------------------------------------------------------

fn msgpack_to_prop(value: data.Value) -> PropValue {
  case value {
    data.Nil -> PNull
    data.Boolean(b) -> PBool(b)
    data.Integer(n) -> PInt(n)
    data.Float(f) -> PFloat(f)
    data.String(s) -> PString(s)
    data.Binary(_) -> PNull
    data.Array(items) -> PList(list.map(items, msgpack_to_prop))
    data.Map(entries) -> PMap(msgpack_map_to_string_dict(entries))
    data.Extension(_, _) -> PNull
  }
}

fn msgpack_map_to_string_dict(
  entries: Dict(data.Value, data.Value),
) -> Dict(String, PropValue) {
  dict.fold(entries, dict.new(), fn(acc, key, value) {
    case key {
      data.String(k) -> dict.insert(acc, k, msgpack_to_prop(value))
      _ -> acc
    }
  })
}

// ---------------------------------------------------------------------------
// Dynamic (from JSON) -> PropValue
// ---------------------------------------------------------------------------

fn dynamic_to_prop(dyn: Dynamic) -> PropValue {
  // Try each type in order. Gleam's dynamic decoders return Error
  // on type mismatch, so we chain through until one matches.
  case decode.run(dyn, decode.string) {
    Ok(s) -> PString(s)
    Error(_) ->
      case decode.run(dyn, decode.bool) {
        Ok(b) -> PBool(b)
        Error(_) ->
          case decode.run(dyn, decode.int) {
            Ok(n) -> PInt(n)
            Error(_) ->
              case decode.run(dyn, decode.float) {
                Ok(f) -> PFloat(f)
                Error(_) ->
                  case decode.run(dyn, decode.list(decode.dynamic)) {
                    Ok(items) -> PList(list.map(items, dynamic_to_prop))
                    Error(_) ->
                      case
                        decode.run(
                          dyn,
                          decode.dict(decode.string, decode.dynamic),
                        )
                      {
                        Ok(entries) ->
                          PMap(
                            dict.map_values(entries, fn(_k, v) {
                              dynamic_to_prop(v)
                            }),
                          )
                        Error(_) ->
                          // null / nil
                          PNull
                      }
                  }
              }
          }
      }
  }
}

// ---------------------------------------------------------------------------
// Map accessor helpers
// ---------------------------------------------------------------------------

fn get_string(
  map: Dict(String, PropValue),
  key: String,
) -> Result(String, protocol.DecodeError) {
  case dict.get(map, key) {
    Ok(PString(s)) -> Ok(s)
    Ok(_) ->
      Error(protocol.MalformedEvent("expected string for \"" <> key <> "\""))
    Error(_) ->
      Error(protocol.MalformedEvent("missing field \"" <> key <> "\""))
  }
}

fn get_int(
  map: Dict(String, PropValue),
  key: String,
) -> Result(Int, protocol.DecodeError) {
  case dict.get(map, key) {
    Ok(PInt(n)) -> Ok(n)
    Ok(PFloat(f)) -> Ok(float.truncate(f))
    Ok(_) ->
      Error(protocol.MalformedEvent("expected int for \"" <> key <> "\""))
    Error(_) ->
      Error(protocol.MalformedEvent("missing field \"" <> key <> "\""))
  }
}

fn get_float(
  map: Dict(String, PropValue),
  key: String,
) -> Result(Float, protocol.DecodeError) {
  case dict.get(map, key) {
    Ok(PFloat(f)) -> Ok(f)
    Ok(PInt(n)) -> Ok(int.to_float(n))
    Ok(_) ->
      Error(protocol.MalformedEvent("expected float for \"" <> key <> "\""))
    Error(_) ->
      Error(protocol.MalformedEvent("missing field \"" <> key <> "\""))
  }
}

fn get_bool(
  map: Dict(String, PropValue),
  key: String,
) -> Result(Bool, protocol.DecodeError) {
  case dict.get(map, key) {
    Ok(PBool(b)) -> Ok(b)
    Ok(_) ->
      Error(protocol.MalformedEvent("expected bool for \"" <> key <> "\""))
    Error(_) ->
      Error(protocol.MalformedEvent("missing field \"" <> key <> "\""))
  }
}

fn get_optional_string(
  map: Dict(String, PropValue),
  key: String,
) -> Option(String) {
  case dict.get(map, key) {
    Ok(PString(s)) -> Some(s)
    _ -> None
  }
}

fn get_string_or(
  map: Dict(String, PropValue),
  key: String,
  default: String,
) -> String {
  case dict.get(map, key) {
    Ok(PString(s)) -> s
    _ -> default
  }
}

fn get_bool_or(map: Dict(String, PropValue), key: String, default: Bool) -> Bool {
  case dict.get(map, key) {
    Ok(PBool(b)) -> b
    _ -> default
  }
}

fn get_float_or(
  map: Dict(String, PropValue),
  key: String,
  default: Float,
) -> Float {
  case dict.get(map, key) {
    Ok(PFloat(f)) -> f
    Ok(PInt(n)) -> int.to_float(n)
    _ -> default
  }
}

fn get_int_or(map: Dict(String, PropValue), key: String, default: Int) -> Int {
  case dict.get(map, key) {
    Ok(PInt(n)) -> n
    Ok(PFloat(f)) -> float.truncate(f)
    _ -> default
  }
}

fn get_map(map: Dict(String, PropValue), key: String) -> Dict(String, PropValue) {
  case dict.get(map, key) {
    Ok(PMap(m)) -> m
    _ -> dict.new()
  }
}

fn get_string_list(map: Dict(String, PropValue), key: String) -> List(String) {
  case dict.get(map, key) {
    Ok(PList(items)) ->
      list.filter_map(items, fn(item) {
        case item {
          PString(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
    _ -> []
  }
}

fn prop_to_dynamic(value: PropValue) -> Dynamic {
  case value {
    PString(s) -> dynamic.string(s)
    PInt(n) -> dynamic.int(n)
    PFloat(f) -> dynamic.float(f)
    PBool(b) -> dynamic.bool(b)
    PNull -> dynamic.nil()
    PList(items) -> dynamic.list(list.map(items, prop_to_dynamic))
    PMap(entries) ->
      dynamic.properties(
        dict.to_list(entries)
        |> list.map(fn(pair) {
          #(dynamic.string(pair.0), prop_to_dynamic(pair.1))
        }),
      )
  }
}

// ---------------------------------------------------------------------------
// Dispatch -- route on "type" field
// ---------------------------------------------------------------------------

fn dispatch(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use msg_type <- result.try(get_string(map, "type"))
  case msg_type {
    "hello" -> decode_hello(map)
    "event" -> decode_event(map)
    "effect_response" -> decode_effect_response(map)
    "op_query_response" -> decode_op_query_response(map)
    _ -> Error(protocol.UnknownMessageType(msg_type))
  }
}

// ---------------------------------------------------------------------------
// Hello
// ---------------------------------------------------------------------------

fn decode_hello(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use proto <- result.try(get_int(map, "protocol"))
  use version <- result.try(get_string(map, "version"))
  use name <- result.try(get_string(map, "name"))
  let backend = get_string_or(map, "backend", "unknown")
  let extensions = get_string_list(map, "extensions")
  Ok(Hello(protocol: proto, version:, name:, backend:, extensions:))
}

// ---------------------------------------------------------------------------
// Effect response
// ---------------------------------------------------------------------------

fn decode_effect_response(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use request_id <- result.try(get_string(map, "id"))
  use status <- result.try(get_string(map, "status"))
  let result_val = case status {
    "ok" -> {
      let r = case dict.get(map, "result") {
        Ok(v) -> prop_to_dynamic(v)
        Error(_) -> dynamic.nil()
      }
      event.EffectOk(r)
    }
    "cancelled" -> event.EffectCancelled
    "error" -> {
      let r = case dict.get(map, "error") {
        Ok(v) -> prop_to_dynamic(v)
        Error(_) -> dynamic.nil()
      }
      event.EffectError(r)
    }
    _ -> event.EffectError(dynamic.string("unknown status: " <> status))
  }
  Ok(EventMessage(event.EffectResponse(request_id:, result: result_val)))
}

// ---------------------------------------------------------------------------
// Op query response
// ---------------------------------------------------------------------------

fn decode_op_query_response(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use kind <- result.try(get_string(map, "kind"))
  let tag = get_string_or(map, "tag", "")
  let data_val = case dict.get(map, "data") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  let evt = case kind {
    "system_info" -> event.SystemInfo(tag:, data: data_val)
    "system_theme" -> {
      let theme = case dict.get(map, "data") {
        Ok(PString(s)) -> s
        _ -> "unknown"
      }
      event.SystemTheme(tag:, theme:)
    }
    "list_images" ->
      event.ImageList(
        tag:,
        handles: get_string_list(get_map(map, "data_map"), "handles"),
      )
    "tree_hash" -> {
      let hash = case dict.get(map, "data") {
        Ok(PString(s)) -> s
        _ -> ""
      }
      event.TreeHash(tag:, hash:)
    }
    "find_focused" -> {
      let widget_id = case dict.get(map, "data") {
        Ok(PString(s)) -> Some(s)
        Ok(PNull) -> None
        _ -> None
      }
      event.FocusedWidget(tag:, widget_id:)
    }
    _ -> event.SystemInfo(tag:, data: data_val)
  }
  Ok(EventMessage(evt))
}

// ---------------------------------------------------------------------------
// Event dispatch -- route on "family" field
// ---------------------------------------------------------------------------

fn decode_event(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use family <- result.try(get_string(map, "family"))
  case family {
    // Widget events
    "click" -> decode_widget_click(map)
    "input" -> decode_widget_string_value(map, event.WidgetInput)
    "submit" -> decode_widget_string_value(map, event.WidgetSubmit)
    "toggle" -> decode_widget_toggle(map)
    "select" -> decode_widget_string_value(map, event.WidgetSelect)
    "slide" -> decode_widget_float_value(map, event.WidgetSlide)
    "slide_release" -> decode_widget_float_value(map, event.WidgetSlideRelease)
    "paste" -> decode_widget_string_value(map, event.WidgetPaste)
    "open" -> decode_widget_no_value(map, event.WidgetOpen)
    "close" -> decode_widget_no_value(map, event.WidgetClose)
    "option_hovered" ->
      decode_widget_string_value(map, event.WidgetOptionHovered)
    "sort" -> decode_widget_sort(map)
    "key_binding" -> decode_widget_key_binding(map)
    "scroll" -> decode_widget_scroll(map)

    // Key events
    "key_press" -> decode_key_press(map)
    "key_release" -> decode_key_release(map)
    "modifiers_changed" -> decode_modifiers_changed(map)

    // Window events
    "window_opened" -> decode_window_opened(map)
    "window_closed" -> decode_window_id_event(map, event.WindowClosed)
    "window_close_requested" ->
      decode_window_id_event(map, event.WindowCloseRequested)
    "window_resized" -> decode_window_resized(map)
    "window_moved" -> decode_window_moved(map)
    "window_focused" -> decode_window_id_event(map, event.WindowFocused)
    "window_unfocused" -> decode_window_id_event(map, event.WindowUnfocused)
    "window_rescaled" -> decode_window_rescaled(map)
    "file_hovered" -> decode_window_file(map, event.WindowFileHovered)
    "file_dropped" -> decode_window_file(map, event.WindowFileDropped)
    "files_hovered_left" ->
      decode_window_id_event(map, event.WindowFilesHoveredLeft)

    // Mouse events
    "cursor_moved" -> decode_cursor_moved(map)
    "cursor_entered" -> Ok(EventMessage(event.MouseEntered))
    "cursor_left" -> Ok(EventMessage(event.MouseLeft))
    "button_pressed" -> decode_mouse_button(map, event.MouseButtonPressed)
    "button_released" -> decode_mouse_button(map, event.MouseButtonReleased)
    "wheel_scrolled" -> decode_wheel_scrolled(map)

    // Touch events
    "finger_pressed" -> decode_touch(map, event.TouchPressed)
    "finger_moved" -> decode_touch(map, event.TouchMoved)
    "finger_lifted" -> decode_touch(map, event.TouchLifted)
    "finger_lost" -> decode_touch(map, event.TouchLost)

    // IME events
    "ime_opened" -> Ok(EventMessage(event.ImeOpened))
    "ime_preedit" -> decode_ime_preedit(map)
    "ime_commit" -> decode_ime_commit(map)
    "ime_closed" -> Ok(EventMessage(event.ImeClosed))

    // Sensor events
    "sensor_resize" -> decode_sensor_resize(map)

    // MouseArea events
    "mouse_right_press" ->
      decode_mouse_area_no_coords(map, event.MouseAreaRightPress)
    "mouse_right_release" ->
      decode_mouse_area_no_coords(map, event.MouseAreaRightRelease)
    "mouse_middle_press" ->
      decode_mouse_area_no_coords(map, event.MouseAreaMiddlePress)
    "mouse_middle_release" ->
      decode_mouse_area_no_coords(map, event.MouseAreaMiddleRelease)
    "mouse_double_click" ->
      decode_mouse_area_no_coords(map, event.MouseAreaDoubleClick)
    "mouse_enter" -> decode_widget_no_value(map, event.MouseAreaEnter)
    "mouse_exit" -> decode_widget_no_value(map, event.MouseAreaExit)
    "mouse_move" -> decode_mouse_area_move(map)
    "mouse_scroll" -> decode_mouse_area_scroll(map)

    // Canvas events
    "canvas_press" -> decode_canvas_button(map, event.CanvasPress)
    "canvas_release" -> decode_canvas_button(map, event.CanvasRelease)
    "canvas_move" -> decode_canvas_move(map)
    "canvas_scroll" -> decode_canvas_scroll(map)

    // Pane events
    "pane_resized" -> decode_pane_resized(map)
    "pane_dragged" -> decode_pane_dragged(map)
    "pane_clicked" -> decode_pane_simple(map, event.PaneClicked)
    "pane_focus_cycle" -> decode_pane_simple(map, event.PaneFocusCycle)

    // System events
    "animation_frame" -> decode_animation_frame(map)
    "theme_changed" -> decode_theme_changed(map)
    "all_windows_closed" -> Ok(EventMessage(event.AllWindowsClosed))

    // Unknown family -- wrap in the catch-all WidgetEvent
    _ -> decode_generic_widget_event(map, family)
  }
}

// ---------------------------------------------------------------------------
// Modifier parsing
// ---------------------------------------------------------------------------

fn parse_modifiers(map: Dict(String, PropValue)) -> Modifiers {
  let mods = get_map(map, "modifiers")
  event.Modifiers(
    shift: get_bool_or(mods, "shift", False),
    ctrl: get_bool_or(mods, "ctrl", False),
    alt: get_bool_or(mods, "alt", False),
    logo: get_bool_or(mods, "logo", False),
    command: get_bool_or(mods, "command", False),
  )
}

fn parse_key_location(loc: String) -> KeyLocation {
  case loc {
    "left" -> event.LeftSide
    "right" -> event.RightSide
    "numpad" -> event.Numpad
    _ -> event.Standard
  }
}

fn parse_mouse_button(value: String) -> MouseButton {
  case value {
    "left" -> event.LeftButton
    "right" -> event.RightButton
    "middle" -> event.MiddleButton
    "back" -> event.BackButton
    "forward" -> event.ForwardButton
    other -> event.OtherButton(other)
  }
}

fn parse_scroll_unit(value: String) -> ScrollUnit {
  case value {
    "pixel" -> event.Pixel
    _ -> event.Line
  }
}

// ---------------------------------------------------------------------------
// Widget event decoders
// ---------------------------------------------------------------------------

fn decode_widget_click(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.WidgetClick(id: local, scope:)))
}

fn decode_widget_string_value(
  map: Dict(String, PropValue),
  constructor: fn(String, List(String), String) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  use value <- result.try(get_string(map, "value"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(constructor(local, scope, value)))
}

fn decode_widget_toggle(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  use value <- result.try(get_bool(map, "value"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.WidgetToggle(id: local, scope:, value:)))
}

fn decode_widget_float_value(
  map: Dict(String, PropValue),
  constructor: fn(String, List(String), Float) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  use value <- result.try(get_float(map, "value"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(constructor(local, scope, value)))
}

fn decode_widget_no_value(
  map: Dict(String, PropValue),
  constructor: fn(String, List(String)) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(constructor(local, scope)))
}

fn decode_widget_sort(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let column = get_string_or(data, "column", "")
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.WidgetSort(id: local, scope:, value: column)))
}

fn decode_widget_key_binding(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let binding = case dict.get(data, "binding") {
    Ok(PString(s)) -> s
    _ ->
      case dict.get(map, "data") {
        Ok(PString(s)) -> s
        _ -> ""
      }
  }
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.WidgetKeyBinding(id: local, scope:, value: binding)))
}

fn decode_widget_scroll(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let #(local, scope) = split_scoped_id(id)
  let scroll_data =
    event.ScrollData(
      absolute_x: get_float_or(data, "absolute_x", 0.0),
      absolute_y: get_float_or(data, "absolute_y", 0.0),
      relative_x: get_float_or(data, "relative_x", 0.0),
      relative_y: get_float_or(data, "relative_y", 0.0),
      bounds_width: get_float_or(data, "bounds_width", 0.0),
      bounds_height: get_float_or(data, "bounds_height", 0.0),
      content_width: get_float_or(data, "content_width", 0.0),
      content_height: get_float_or(data, "content_height", 0.0),
    )
  Ok(EventMessage(event.WidgetScroll(id: local, scope:, data: scroll_data)))
}

fn decode_generic_widget_event(
  map: Dict(String, PropValue),
  family: String,
) -> Result(InboundMessage, protocol.DecodeError) {
  let id = get_string_or(map, "id", "")
  let #(local, scope) = split_scoped_id(id)
  let value = case dict.get(map, "value") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  let data = case dict.get(map, "data") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  Ok(
    EventMessage(event.WidgetEvent(
      kind: family,
      id: local,
      scope:,
      value:,
      data:,
    )),
  )
}

// ---------------------------------------------------------------------------
// Key event decoders
// ---------------------------------------------------------------------------

fn decode_key_press(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  let key = get_string_or(data, "key", "")
  let modifiers = parse_modifiers(map)
  let physical_key = get_optional_string(data, "physical_key")
  let location = parse_key_location(get_string_or(data, "location", "standard"))
  let text = get_optional_string(data, "text")
  let repeat = get_bool_or(data, "repeat", False)
  Ok(
    EventMessage(event.KeyPress(
      key:,
      modifiers:,
      physical_key:,
      location:,
      text:,
      repeat:,
    )),
  )
}

fn decode_key_release(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  let key = get_string_or(data, "key", "")
  let modifiers = parse_modifiers(map)
  let physical_key = get_optional_string(data, "physical_key")
  let location = parse_key_location(get_string_or(data, "location", "standard"))
  let text = get_optional_string(data, "text")
  Ok(
    EventMessage(event.KeyRelease(
      key:,
      modifiers:,
      physical_key:,
      location:,
      text:,
    )),
  )
}

fn decode_modifiers_changed(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let modifiers = parse_modifiers(map)
  Ok(EventMessage(event.ModifiersChanged(modifiers:)))
}

// ---------------------------------------------------------------------------
// Window event decoders
// ---------------------------------------------------------------------------

fn decode_window_opened(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use window_id <- result.try(get_string(data, "window_id"))
  use width <- result.try(get_float(data, "width"))
  use height <- result.try(get_float(data, "height"))
  let x = get_float_or(data, "x", 0.0)
  let y = get_float_or(data, "y", 0.0)
  // Position may also be nested under a "position" key
  let #(px, py) = case dict.get(data, "position") {
    Ok(PMap(pos)) -> #(get_float_or(pos, "x", x), get_float_or(pos, "y", y))
    _ -> #(x, y)
  }
  let scale_factor = get_float_or(data, "scale_factor", 1.0)
  Ok(
    EventMessage(event.WindowOpened(
      window_id:,
      width:,
      height:,
      x: px,
      y: py,
      scale_factor:,
    )),
  )
}

fn decode_window_id_event(
  map: Dict(String, PropValue),
  constructor: fn(String) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use window_id <- result.try(get_string(data, "window_id"))
  Ok(EventMessage(constructor(window_id)))
}

fn decode_window_resized(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use window_id <- result.try(get_string(data, "window_id"))
  use width <- result.try(get_float(data, "width"))
  use height <- result.try(get_float(data, "height"))
  Ok(EventMessage(event.WindowResized(window_id:, width:, height:)))
}

fn decode_window_moved(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use window_id <- result.try(get_string(data, "window_id"))
  use x <- result.try(get_float(data, "x"))
  use y <- result.try(get_float(data, "y"))
  Ok(EventMessage(event.WindowMoved(window_id:, x:, y:)))
}

fn decode_window_rescaled(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use window_id <- result.try(get_string(data, "window_id"))
  use scale_factor <- result.try(get_float(data, "scale_factor"))
  Ok(EventMessage(event.WindowRescaled(window_id:, scale_factor:)))
}

fn decode_window_file(
  map: Dict(String, PropValue),
  constructor: fn(String, String) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use window_id <- result.try(get_string(data, "window_id"))
  use path <- result.try(get_string(data, "path"))
  Ok(EventMessage(constructor(window_id, path)))
}

// ---------------------------------------------------------------------------
// Mouse event decoders
// ---------------------------------------------------------------------------

fn decode_cursor_moved(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use x <- result.try(get_float(data, "x"))
  use y <- result.try(get_float(data, "y"))
  Ok(EventMessage(event.MouseMoved(x:, y:)))
}

fn decode_mouse_button(
  map: Dict(String, PropValue),
  constructor: fn(MouseButton, Float, Float) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  let button_str = get_string_or(map, "value", "left")
  let button = parse_mouse_button(button_str)
  let data = get_map(map, "data")
  let x = get_float_or(data, "x", 0.0)
  let y = get_float_or(data, "y", 0.0)
  Ok(EventMessage(constructor(button, x, y)))
}

fn decode_wheel_scrolled(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use delta_x <- result.try(get_float(data, "delta_x"))
  use delta_y <- result.try(get_float(data, "delta_y"))
  let unit = parse_scroll_unit(get_string_or(data, "unit", "line"))
  Ok(EventMessage(event.MouseWheelScrolled(delta_x:, delta_y:, unit:)))
}

// ---------------------------------------------------------------------------
// Touch event decoders
// ---------------------------------------------------------------------------

fn decode_touch(
  map: Dict(String, PropValue),
  constructor: fn(Int, Float, Float) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use finger_id <- result.try(get_int(data, "id"))
  use x <- result.try(get_float(data, "x"))
  use y <- result.try(get_float(data, "y"))
  Ok(EventMessage(constructor(finger_id, x, y)))
}

// ---------------------------------------------------------------------------
// IME event decoders
// ---------------------------------------------------------------------------

fn decode_ime_preedit(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  let text = get_string_or(data, "text", "")
  let cursor = case dict.get(data, "cursor") {
    Ok(PMap(c)) -> {
      let start = get_int_or(c, "start", 0)
      let end = get_int_or(c, "end", 0)
      Some(#(start, end))
    }
    _ -> None
  }
  Ok(EventMessage(event.ImePreedit(text:, cursor:)))
}

fn decode_ime_commit(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  let text = get_string_or(data, "text", "")
  Ok(EventMessage(event.ImeCommit(text:)))
}

// ---------------------------------------------------------------------------
// Sensor event decoders
// ---------------------------------------------------------------------------

fn decode_sensor_resize(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  use width <- result.try(get_float(data, "width"))
  use height <- result.try(get_float(data, "height"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.SensorResize(id: local, scope:, width:, height:)))
}

// ---------------------------------------------------------------------------
// MouseArea event decoders
// ---------------------------------------------------------------------------

fn decode_mouse_area_no_coords(
  map: Dict(String, PropValue),
  constructor: fn(String, List(String), Float, Float) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let x = get_float_or(data, "x", 0.0)
  let y = get_float_or(data, "y", 0.0)
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(constructor(local, scope, x, y)))
}

fn decode_mouse_area_move(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  use x <- result.try(get_float(data, "x"))
  use y <- result.try(get_float(data, "y"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.MouseAreaMove(id: local, scope:, x:, y:)))
}

fn decode_mouse_area_scroll(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  use delta_x <- result.try(get_float(data, "delta_x"))
  use delta_y <- result.try(get_float(data, "delta_y"))
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.MouseAreaScroll(id: local, scope:, delta_x:, delta_y:)))
}

// ---------------------------------------------------------------------------
// Canvas event decoders
// ---------------------------------------------------------------------------

fn decode_canvas_button(
  map: Dict(String, PropValue),
  constructor: fn(String, List(String), Float, Float, String) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let x = get_float_or(data, "x", 0.0)
  let y = get_float_or(data, "y", 0.0)
  let button = get_string_or(data, "button", "left")
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(constructor(local, scope, x, y, button)))
}

fn decode_canvas_move(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let x = get_float_or(data, "x", 0.0)
  let y = get_float_or(data, "y", 0.0)
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.CanvasMove(id: local, scope:, x:, y:)))
}

fn decode_canvas_scroll(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let delta_x = get_float_or(data, "delta_x", 0.0)
  let delta_y = get_float_or(data, "delta_y", 0.0)
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.CanvasScroll(id: local, scope:, delta_x:, delta_y:)))
}

// ---------------------------------------------------------------------------
// Pane event decoders
// ---------------------------------------------------------------------------

fn decode_pane_resized(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let split = case dict.get(data, "split") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  let ratio = get_float_or(data, "ratio", 0.5)
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(event.PaneResized(id: local, scope:, split:, ratio:)))
}

fn decode_pane_dragged(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let pane = case dict.get(data, "pane") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  let target = case dict.get(data, "target") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  let action = get_string_or(data, "action", "")
  let region = get_optional_string(data, "region")
  let #(local, scope) = split_scoped_id(id)
  Ok(
    EventMessage(event.PaneDragged(
      id: local,
      scope:,
      pane:,
      target:,
      action:,
      region:,
    )),
  )
}

fn decode_pane_simple(
  map: Dict(String, PropValue),
  constructor: fn(String, List(String), Dynamic) -> Event,
) -> Result(InboundMessage, protocol.DecodeError) {
  use id <- result.try(get_string(map, "id"))
  let data = get_map(map, "data")
  let pane = case dict.get(data, "pane") {
    Ok(v) -> prop_to_dynamic(v)
    Error(_) -> dynamic.nil()
  }
  let #(local, scope) = split_scoped_id(id)
  Ok(EventMessage(constructor(local, scope, pane)))
}

// ---------------------------------------------------------------------------
// System event decoders
// ---------------------------------------------------------------------------

fn decode_animation_frame(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  let data = get_map(map, "data")
  use timestamp <- result.try(get_int(data, "timestamp"))
  Ok(EventMessage(event.AnimationFrame(timestamp:)))
}

fn decode_theme_changed(
  map: Dict(String, PropValue),
) -> Result(InboundMessage, protocol.DecodeError) {
  use theme <- result.try(get_string(map, "value"))
  Ok(EventMessage(event.ThemeChanged(theme:)))
}
