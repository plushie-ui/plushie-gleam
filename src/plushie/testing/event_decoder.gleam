//// Wire event decoder for test backends.
////
//// Decodes wire-format event maps (as received from the renderer) into
//// typed Event values. Shared between all test backends that receive
//// wire events, keeping decoding logic in one place.

@target(erlang)
import gleam/dict.{type Dict}
@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/dynamic/decode
@target(erlang)
import gleam/list
@target(erlang)
import gleam/option.{None, Some}
@target(erlang)
import gleam/string
@target(erlang)
import plushie/event.{type Event, type Modifiers, Modifiers}

@target(erlang)
/// Decode a wire event map into a typed Event.
/// Returns Ok(event) or Error(Nil) for unrecognised families.
pub fn decode_test_event(
  family: String,
  id: String,
  data: Dict(String, Dynamic),
) -> Result(Event, Nil) {
  let #(local, scope) = split_scoped_id(id)
  let window_id = get_required_string(data, "window_id")

  case family {
    // -- Widget events -------------------------------------------------------
    "click" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetClick(window_id:, id: local, scope:)
      })
    "input" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetInput(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "value", ""),
        )
      })
    "submit" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetSubmit(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "value", ""),
        )
      })
    "toggle" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetToggle(
          window_id:,
          id: local,
          scope:,
          value: get_bool(data, "value", False),
        )
      })
    "select" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetSelect(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "value", ""),
        )
      })
    "slide" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetSlide(
          window_id:,
          id: local,
          scope:,
          value: get_float(data, "value", 0.0),
        )
      })
    "slide_release" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetSlideRelease(
          window_id:,
          id: local,
          scope:,
          value: get_float(data, "value", 0.0),
        )
      })
    "paste" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetPaste(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "value", ""),
        )
      })
    "sort" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetSort(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "column", ""),
        )
      })
    "open" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetOpen(window_id:, id: local, scope:)
      })
    "close" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetClose(window_id:, id: local, scope:)
      })
    "option_hovered" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetOptionHovered(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "value", ""),
        )
      })
    "key_binding" ->
      require_window_event(window_id, fn(window_id) {
        event.WidgetKeyBinding(
          window_id:,
          id: local,
          scope:,
          value: get_string(data, "value", ""),
        )
      })
    "scroll" -> {
      let scroll_data =
        event.ScrollData(
          absolute_x: get_float(data, "absolute_x", 0.0),
          absolute_y: get_float(data, "absolute_y", 0.0),
          relative_x: get_float(data, "relative_x", 0.0),
          relative_y: get_float(data, "relative_y", 0.0),
          bounds_width: get_float(data, "bounds_width", 0.0),
          bounds_height: get_float(data, "bounds_height", 0.0),
          content_width: get_float(data, "content_width", 0.0),
          content_height: get_float(data, "content_height", 0.0),
        )
      require_window_event(window_id, fn(window_id) {
        event.WidgetScroll(window_id:, id: local, scope:, data: scroll_data)
      })
    }

    // -- Key events ----------------------------------------------------------
    "key_press" -> Ok(decode_key_press(data))
    "key_release" -> Ok(decode_key_release(data))

    // -- Mouse events (global subscriptions) ---------------------------------
    "cursor_moved" ->
      Ok(event.MouseMoved(
        x: get_float(data, "x", 0.0),
        y: get_float(data, "y", 0.0),
        captured: False,
      ))
    "cursor_entered" -> Ok(event.MouseEntered(captured: False))
    "cursor_left" -> Ok(event.MouseLeft(captured: False))
    "button_pressed" ->
      Ok(event.MouseButtonPressed(
        button: decode_mouse_button(get_string(data, "button", "left")),
        captured: False,
      ))
    "button_released" ->
      Ok(event.MouseButtonReleased(
        button: decode_mouse_button(get_string(data, "button", "left")),
        captured: False,
      ))
    "wheel_scrolled" ->
      Ok(event.MouseWheelScrolled(
        delta_x: get_float(data, "delta_x", 0.0),
        delta_y: get_float(data, "delta_y", 0.0),
        unit: event.Line,
        captured: False,
      ))

    // -- Touch events --------------------------------------------------------
    "finger_pressed" ->
      Ok(event.TouchPressed(
        finger_id: get_int(data, "finger_id", 0),
        x: get_float(data, "x", 0.0),
        y: get_float(data, "y", 0.0),
        captured: False,
      ))
    "finger_moved" ->
      Ok(event.TouchMoved(
        finger_id: get_int(data, "finger_id", 0),
        x: get_float(data, "x", 0.0),
        y: get_float(data, "y", 0.0),
        captured: False,
      ))
    "finger_lifted" ->
      Ok(event.TouchLifted(
        finger_id: get_int(data, "finger_id", 0),
        x: get_float(data, "x", 0.0),
        y: get_float(data, "y", 0.0),
        captured: False,
      ))
    "finger_lost" ->
      Ok(event.TouchLost(
        finger_id: get_int(data, "finger_id", 0),
        x: get_float(data, "x", 0.0),
        y: get_float(data, "y", 0.0),
        captured: False,
      ))

    // -- Window events -------------------------------------------------------
    "window_opened" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowOpened(
          window_id:,
          width: get_float(data, "width", 0.0),
          height: get_float(data, "height", 0.0),
          position_x: get_optional_float(data, "position_x"),
          position_y: get_optional_float(data, "position_y"),
          scale_factor: get_float(data, "scale_factor", 1.0),
        )
      })
    "window_closed" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowClosed(window_id:)
      })
    "window_close_requested" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowCloseRequested(window_id:)
      })
    "window_moved" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowMoved(
          window_id:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
        )
      })
    "window_resized" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowResized(
          window_id:,
          width: get_float(data, "width", 0.0),
          height: get_float(data, "height", 0.0),
        )
      })
    "window_focused" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowFocused(window_id:)
      })
    "window_unfocused" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowUnfocused(window_id:)
      })
    "window_rescaled" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowRescaled(
          window_id:,
          scale_factor: get_float(data, "scale_factor", 1.0),
        )
      })
    "window_file_hovered" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowFileHovered(window_id:, path: get_string(data, "path", ""))
      })
    "window_file_dropped" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowFileDropped(window_id:, path: get_string(data, "path", ""))
      })
    "window_files_hovered_left" ->
      require_window_event(window_id, fn(window_id) {
        event.WindowFilesHoveredLeft(window_id:)
      })

    // -- IME events ----------------------------------------------------------
    "ime_opened" -> Ok(event.ImeOpened(captured: False))
    "ime_preedit" ->
      Ok(event.ImePreedit(
        text: get_string(data, "text", ""),
        cursor: None,
        captured: False,
      ))
    "ime_commit" ->
      Ok(event.ImeCommit(text: get_string(data, "text", ""), captured: False))
    "ime_closed" -> Ok(event.ImeClosed(captured: False))

    // -- Modifiers changed ---------------------------------------------------
    "modifiers_changed" ->
      Ok(event.ModifiersChanged(
        modifiers: decode_modifiers(data),
        captured: False,
      ))

    // -- MouseArea events ----------------------------------------------------
    "mouse_area_right_press" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaRightPress(window_id:, id: local, scope:)
      })
    "mouse_area_right_release" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaRightRelease(window_id:, id: local, scope:)
      })
    "mouse_area_middle_press" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaMiddlePress(window_id:, id: local, scope:)
      })
    "mouse_area_middle_release" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaMiddleRelease(window_id:, id: local, scope:)
      })
    "mouse_area_double_click" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaDoubleClick(window_id:, id: local, scope:)
      })
    "mouse_area_enter" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaEnter(window_id:, id: local, scope:)
      })
    "mouse_area_exit" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaExit(window_id:, id: local, scope:)
      })
    "mouse_area_move" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaMove(
          window_id:,
          id: local,
          scope:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
        )
      })
    "mouse_area_scroll" ->
      require_window_event(window_id, fn(window_id) {
        event.MouseAreaScroll(
          window_id:,
          id: local,
          scope:,
          delta_x: get_float(data, "delta_x", 0.0),
          delta_y: get_float(data, "delta_y", 0.0),
        )
      })

    // -- Canvas events -------------------------------------------------------
    "canvas_press" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasPress(
          window_id:,
          id: local,
          scope:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: get_string(data, "button", "left"),
        )
      })
    "canvas_release" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasRelease(
          window_id:,
          id: local,
          scope:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: get_string(data, "button", "left"),
        )
      })
    "canvas_move" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasMove(
          window_id:,
          id: local,
          scope:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
        )
      })
    "canvas_scroll" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasScroll(
          window_id:,
          id: local,
          scope:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          delta_x: get_float(data, "delta_x", 0.0),
          delta_y: get_float(data, "delta_y", 0.0),
        )
      })

    // -- Canvas shape events -------------------------------------------------
    "canvas_element_enter" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementEnter(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          captured: False,
        )
      })
    "canvas_element_leave" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementLeave(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          captured: False,
        )
      })
    "canvas_element_click" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementClick(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: get_string(data, "button", "left"),
          captured: False,
        )
      })
    "canvas_element_drag" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementDrag(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          delta_x: get_float(data, "delta_x", 0.0),
          delta_y: get_float(data, "delta_y", 0.0),
          captured: False,
        )
      })
    "canvas_element_drag_end" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementDragEnd(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          captured: False,
        )
      })
    "canvas_element_focused" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementFocused(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          captured: False,
        )
      })
    "canvas_element_blurred" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementBlurred(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
        )
      })
    "canvas_element_key_press" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementKeyPress(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          key: get_string(data, "key", ""),
          modifiers: decode_modifiers(data),
          captured: False,
        )
      })
    "canvas_element_key_release" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasElementKeyRelease(
          window_id:,
          id: local,
          scope:,
          element_id: get_string(data, "element_id", ""),
          key: get_string(data, "key", ""),
          modifiers: decode_modifiers(data),
          captured: False,
        )
      })
    "canvas_focused" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasFocused(window_id:, id: local, scope:)
      })
    "canvas_blurred" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasBlurred(window_id:, id: local, scope:)
      })
    "canvas_group_focused" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasGroupFocused(
          window_id:,
          id: local,
          scope:,
          group_id: get_string(data, "group_id", ""),
        )
      })
    "canvas_group_blurred" ->
      require_window_event(window_id, fn(window_id) {
        event.CanvasGroupBlurred(
          window_id:,
          id: local,
          scope:,
          group_id: get_string(data, "group_id", ""),
        )
      })
    "diagnostic" ->
      Ok(event.Diagnostic(
        level: get_string(data, "level", ""),
        element_id: get_string(data, "element_id", ""),
        code: get_string(data, "code", ""),
        message: get_string(data, "message", ""),
      ))

    // -- Pane events ---------------------------------------------------------
    "pane_resized" ->
      require_window_event(window_id, fn(window_id) {
        event.PaneResized(
          window_id:,
          id: local,
          scope:,
          split: get_dynamic(data, "split"),
          ratio: get_float(data, "ratio", 0.5),
        )
      })
    "pane_dragged" ->
      require_window_event(window_id, fn(window_id) {
        event.PaneDragged(
          window_id:,
          id: local,
          scope:,
          pane: get_dynamic(data, "pane"),
          target: get_dynamic(data, "target"),
          action: get_string(data, "action", ""),
          region: get_optional_string(data, "region"),
          edge: get_optional_string(data, "edge"),
        )
      })
    "pane_clicked" ->
      require_window_event(window_id, fn(window_id) {
        event.PaneClicked(
          window_id:,
          id: local,
          scope:,
          pane: get_dynamic(data, "pane"),
        )
      })
    "pane_focus_cycle" ->
      require_window_event(window_id, fn(window_id) {
        event.PaneFocusCycle(
          window_id:,
          id: local,
          scope:,
          pane: get_dynamic(data, "pane"),
        )
      })

    // -- Sensor events -------------------------------------------------------
    "sensor_resize" ->
      require_window_event(window_id, fn(window_id) {
        event.SensorResize(
          window_id:,
          id: local,
          scope:,
          width: get_float(data, "width", 0.0),
          height: get_float(data, "height", 0.0),
        )
      })

    // -- System events -------------------------------------------------------
    "animation_frame" ->
      Ok(event.AnimationFrame(timestamp: get_int(data, "timestamp", 0)))
    "theme_changed" ->
      Ok(event.ThemeChanged(theme: get_string(data, "theme", "")))
    "all_windows_closed" -> Ok(event.AllWindowsClosed)

    _ -> Error(Nil)
  }
}

// -- Scoped ID splitting -----------------------------------------------------

@target(erlang)
fn split_scoped_id(id: String) -> #(String, List(String)) {
  case string.split(id, "/") {
    [] -> #(id, [])
    [single] -> #(single, [])
    segments -> {
      let assert Ok(local) = list.last(segments)
      let scope = list.take(segments, list.length(segments) - 1) |> list.reverse
      #(local, scope)
    }
  }
}

@target(erlang)
fn get_required_string(
  data: Dict(String, Dynamic),
  key: String,
) -> Result(String, Nil) {
  case dict.get(data, key) {
    Ok(value) ->
      case decode.run(value, decode.string) {
        Ok(text) if text != "" -> Ok(text)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

@target(erlang)
fn require_window_event(
  window_id: Result(String, Nil),
  build: fn(String) -> Event,
) -> Result(Event, Nil) {
  case window_id {
    Ok(window_id) -> Ok(build(window_id))
    Error(_) -> Error(Nil)
  }
}

// -- Key event decoding ------------------------------------------------------

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
fn modifiers_none() -> Modifiers {
  Modifiers(shift: False, ctrl: False, alt: False, logo: False, command: False)
}

@target(erlang)
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

// -- Mouse button decoding ---------------------------------------------------

@target(erlang)
fn decode_mouse_button(name: String) -> event.MouseButton {
  case name {
    "left" -> event.LeftButton
    "right" -> event.RightButton
    "middle" -> event.MiddleButton
    "back" -> event.BackButton
    "forward" -> event.ForwardButton
    other -> event.OtherButton(other)
  }
}

// -- Dict helpers ------------------------------------------------------------

@target(erlang)
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

@target(erlang)
fn get_optional_string(
  data: Dict(String, Dynamic),
  key: String,
) -> option.Option(String) {
  case dict.get(data, key) {
    Ok(val) ->
      case decode.run(val, decode.string) {
        Ok(s) -> Some(s)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

@target(erlang)
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

@target(erlang)
fn get_optional_float(
  data: Dict(String, Dynamic),
  key: String,
) -> option.Option(Float) {
  case dict.get(data, key) {
    Ok(val) ->
      case decode.run(val, decode.float) {
        Ok(f) -> Some(f)
        Error(_) ->
          case decode.run(val, decode.int) {
            Ok(i) -> Some(int_to_float(i))
            Error(_) -> None
          }
      }
    Error(_) -> None
  }
}

@target(erlang)
fn get_int(data: Dict(String, Dynamic), key: String, default: Int) -> Int {
  case dict.get(data, key) {
    Ok(val) ->
      case decode.run(val, decode.int) {
        Ok(i) -> i
        Error(_) -> default
      }
    Error(_) -> default
  }
}

@target(erlang)
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

@target(erlang)
fn get_dynamic(data: Dict(String, Dynamic), key: String) -> Dynamic {
  case dict.get(data, key) {
    Ok(val) -> val
    Error(_) -> dynamic.nil()
  }
}

@target(erlang)
@external(erlang, "erlang", "float")
fn int_to_float(i: Int) -> Float
