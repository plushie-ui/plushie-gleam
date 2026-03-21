//// Wire event decoder for test backends.
////
//// Decodes wire-format event maps (as received from the renderer) into
//// typed Event values. Shared between all test backends that receive
//// wire events, keeping decoding logic in one place.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import toddy/event.{type Event, type Modifiers, Modifiers}

/// Decode a wire event map into a typed Event.
/// Returns Ok(event) or Error(Nil) for unrecognised families.
pub fn decode_test_event(
  family: String,
  id: String,
  data: Dict(String, Dynamic),
) -> Result(Event, Nil) {
  let #(local, scope) = split_scoped_id(id)

  case family {
    "click" -> Ok(event.WidgetClick(id: local, scope:))
    "input" ->
      Ok(event.WidgetInput(
        id: local,
        scope:,
        value: get_string(data, "value", ""),
      ))
    "submit" ->
      Ok(event.WidgetSubmit(
        id: local,
        scope:,
        value: get_string(data, "value", ""),
      ))
    "toggle" ->
      Ok(event.WidgetToggle(
        id: local,
        scope:,
        value: get_bool(data, "value", False),
      ))
    "select" ->
      Ok(event.WidgetSelect(
        id: local,
        scope:,
        value: get_string(data, "value", ""),
      ))
    "slide" ->
      Ok(event.WidgetSlide(
        id: local,
        scope:,
        value: get_float(data, "value", 0.0),
      ))
    "slide_release" ->
      Ok(event.WidgetSlideRelease(
        id: local,
        scope:,
        value: get_float(data, "value", 0.0),
      ))
    "paste" ->
      Ok(event.WidgetPaste(
        id: local,
        scope:,
        value: get_string(data, "value", ""),
      ))
    "sort" ->
      Ok(event.WidgetSort(
        id: local,
        scope:,
        value: get_string(data, "column", ""),
      ))
    "open" -> Ok(event.WidgetOpen(id: local, scope:))
    "close" -> Ok(event.WidgetClose(id: local, scope:))
    "key_press" -> Ok(decode_key_press(data))
    "key_release" -> Ok(decode_key_release(data))
    "cursor_moved" ->
      Ok(event.MouseMoved(
        x: get_float(data, "x", 0.0),
        y: get_float(data, "y", 0.0),
        captured: False,
      ))
    "wheel_scrolled" ->
      Ok(event.MouseWheelScrolled(
        delta_x: get_float(data, "delta_x", 0.0),
        delta_y: get_float(data, "delta_y", 0.0),
        unit: event.Line,
        captured: False,
      ))
    _ -> Error(Nil)
  }
}

// -- Scoped ID splitting -----------------------------------------------------

fn split_scoped_id(id: String) -> #(String, List(String)) {
  case string.split(id, "/") {
    [] -> #(id, [])
    [single] -> #(single, [])
    segments -> {
      let assert Ok(local) = list.last(segments)
      let scope = list.take(segments, list.length(segments) - 1)
      #(local, scope)
    }
  }
}

// -- Key event decoding ------------------------------------------------------

fn decode_key_press(data: Dict(String, Dynamic)) -> Event {
  let key = parse_wire_key_name(get_string(data, "value", ""))
  let modifiers = decode_modifiers(data)
  let text = case string.length(key) == 1 {
    True -> Some(key)
    False -> None
  }
  event.KeyPress(
    key:,
    modified_key: key,
    modifiers:,
    physical_key: None,
    location: event.Standard,
    text:,
    repeat: False,
    captured: False,
  )
}

fn decode_key_release(data: Dict(String, Dynamic)) -> Event {
  let key = parse_wire_key_name(get_string(data, "value", ""))
  let modifiers = decode_modifiers(data)
  let text = case string.length(key) == 1 {
    True -> Some(key)
    False -> None
  }
  event.KeyRelease(
    key:,
    modified_key: key,
    modifiers:,
    physical_key: None,
    location: event.Standard,
    text:,
    captured: False,
  )
}

fn decode_modifiers(data: Dict(String, Dynamic)) -> Modifiers {
  case dict.get(data, "modifiers") {
    Ok(m) -> decode_modifiers_from_dynamic(m)
    Error(_) ->
      case dict.get(data, "data") {
        Ok(d) -> {
          // Try to extract "modifiers" sub-field from "data"
          case decode.run(d, decode.at(["modifiers"], decode.dynamic)) {
            Ok(m) -> decode_modifiers_from_dynamic(m)
            Error(_) -> modifiers_none()
          }
        }
        Error(_) -> modifiers_none()
      }
  }
}

fn decode_modifiers_from_dynamic(raw: Dynamic) -> Modifiers {
  let get_field = fn(name) {
    case decode.run(raw, decode.at([name], decode.bool)) {
      Ok(v) -> v
      Error(_) -> False
    }
  }
  let ctrl = get_field("ctrl")
  Modifiers(
    ctrl:,
    shift: get_field("shift"),
    alt: get_field("alt"),
    logo: get_field("logo"),
    command: ctrl,
  )
}

fn modifiers_none() -> Modifiers {
  Modifiers(shift: False, ctrl: False, alt: False, logo: False, command: False)
}

/// Map wire key names to canonical key strings.
fn parse_wire_key_name(name: String) -> String {
  case name {
    "enter" -> "Enter"
    "escape" -> "Escape"
    "tab" -> "Tab"
    "backspace" -> "Backspace"
    "space" -> " "
    "delete" -> "Delete"
    "up" -> "ArrowUp"
    "down" -> "ArrowDown"
    "left" -> "ArrowLeft"
    "right" -> "ArrowRight"
    "home" -> "Home"
    "end" -> "End"
    "page_up" -> "PageUp"
    "page_down" -> "PageDown"
    "f1" -> "F1"
    "f2" -> "F2"
    "f3" -> "F3"
    "f4" -> "F4"
    "f5" -> "F5"
    "f6" -> "F6"
    "f7" -> "F7"
    "f8" -> "F8"
    "f9" -> "F9"
    "f10" -> "F10"
    "f11" -> "F11"
    "f12" -> "F12"
    other -> other
  }
}

// -- Dict helpers ------------------------------------------------------------

fn get_string(
  data: Dict(String, Dynamic),
  key: String,
  default: String,
) -> String {
  case dict.get(data, key) {
    Ok(val) ->
      case decode.run(val, decode.string) {
        Ok(s) -> s
        Error(_) -> default
      }
    Error(_) -> default
  }
}

fn get_float(data: Dict(String, Dynamic), key: String, default: Float) -> Float {
  case dict.get(data, key) {
    Ok(val) ->
      case decode.run(val, decode.float) {
        Ok(f) -> f
        Error(_) ->
          case decode.run(val, decode.int) {
            Ok(i) -> int_to_float(i)
            Error(_) -> default
          }
      }
    Error(_) -> default
  }
}

fn get_bool(data: Dict(String, Dynamic), key: String, default: Bool) -> Bool {
  case dict.get(data, key) {
    Ok(val) ->
      case decode.run(val, decode.bool) {
        Ok(b) -> b
        Error(_) -> default
      }
    Error(_) -> default
  }
}

@external(erlang, "erlang", "float")
fn int_to_float(i: Int) -> Float
