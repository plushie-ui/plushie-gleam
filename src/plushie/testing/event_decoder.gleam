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
import gleam/option.{None, Some}
@target(erlang)
import gleam/result
@target(erlang)
import gleam/string
@target(erlang)
import plushie/event.{
  type Event, type Modifiers, type MouseButton, type PointerType, BackButton,
  EventTarget, ForwardButton, LeftButton, MiddleButton, Modifiers, Mouse,
  OtherButton, Pen, RightButton, Touch,
}

@target(erlang)
/// Decode a wire event map into a typed Event.
/// Returns Ok(event) or Error(Nil) for unrecognised families.
pub fn decode_test_event(
  family: String,
  id: String,
  data: Dict(String, Dynamic),
) -> Result(Event, Nil) {
  let window_id = get_required_string(data, "window_id")
  let target = case window_id {
    Ok(wid) -> event.make_target(id, wid)
    Error(_) -> event.make_target(id, "")
  }

  case family {
    // -- Widget events -------------------------------------------------------
    "click" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Click(target:))
      })
    "input" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Input(target:, value: get_string(data, "value", "")))
      })
    "submit" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Submit(target:, value: get_string(data, "value", "")))
      })
    "toggle" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Toggle(
          target:,
          value: get_bool(data, "value", False),
        ))
      })
    "select" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Select(target:, value: get_string(data, "value", "")))
      })
    "slide" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Slide(target:, value: get_float(data, "value", 0.0)))
      })
    "slide_release" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.SlideRelease(
          target:,
          value: get_float(data, "value", 0.0),
        ))
      })
    "paste" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Paste(target:, value: get_string(data, "value", "")))
      })
    "sort" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Sort(target:, value: get_string(data, "column", "")))
      })
    "open" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Open(target:))
      })
    "close" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Close(target:))
      })
    "option_hovered" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.OptionHovered(
          target:,
          value: get_string(data, "value", ""),
        ))
      })
    "key_binding" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.KeyBinding(
          target:,
          value: get_string(data, "value", ""),
        ))
      })
    "scrolled" -> {
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
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Scrolled(target:, data: scroll_data))
      })
    }

    // -- Key events ----------------------------------------------------------
    "key_press" -> Ok(decode_key_press(data, result.unwrap(window_id, "")))
    "key_release" -> Ok(decode_key_release(data, result.unwrap(window_id, "")))

    // -- Pointer subscription events -------------------------------------------
    "cursor_moved" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Move(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          pointer: Mouse,
          finger: option.None,
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    }
    "cursor_entered" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(
          event.Enter(
            target: EventTarget(
              window_id: wid,
              id: wid,
              scope: [],
              full: wid,
            ),
            x: None,
            y: None,
          ),
        ),
      )
    }
    "cursor_left" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(
          event.Exit(
            target: EventTarget(
              window_id: wid,
              id: wid,
              scope: [],
              full: wid,
            ),
            x: None,
            y: None,
          ),
        ),
      )
    }
    "button_pressed" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Press(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: 0.0,
          y: 0.0,
          button: decode_mouse_button(get_string(data, "button", "left")),
          pointer: Mouse,
          finger: option.None,
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    }
    "button_released" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Release(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: 0.0,
          y: 0.0,
          button: decode_mouse_button(get_string(data, "button", "left")),
          pointer: Mouse,
          finger: option.None,
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    }
    "wheel_scrolled" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Scroll(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: 0.0,
          y: 0.0,
          delta_x: get_float(data, "delta_x", 0.0),
          delta_y: get_float(data, "delta_y", 0.0),
          pointer: Mouse,
          modifiers: event.modifiers_none(),
          unit: option.Some(event.Line),
          captured: False,
        )),
      )
    }

    // -- Touch subscription events -------------------------------------------
    "finger_pressed" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Press(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: LeftButton,
          pointer: Touch,
          finger: option.Some(get_int(data, "finger_id", 0)),
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    }
    "finger_moved" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Move(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          pointer: Touch,
          finger: option.Some(get_int(data, "finger_id", 0)),
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    }
    "finger_lifted" | "finger_lost" -> {
      let wid = result.unwrap(window_id, "")
      Ok(
        event.Widget(event.Release(
          target: EventTarget(window_id: wid, id: wid, scope: [], full: wid),
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: LeftButton,
          pointer: Touch,
          finger: option.Some(get_int(data, "finger_id", 0)),
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    }

    // -- Window events -------------------------------------------------------
    "window_opened" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.Opened,
          window_id:,
          width: Some(get_float(data, "width", 0.0)),
          height: Some(get_float(data, "height", 0.0)),
          x: get_optional_float(data, "position_x"),
          y: get_optional_float(data, "position_y"),
          scale_factor: Some(get_float(data, "scale_factor", 1.0)),
          path: None,
        ))
      })
    "window_closed" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.Closed,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: None,
        ))
      })
    "window_close_requested" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.CloseRequested,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: None,
        ))
      })
    "window_moved" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.Moved,
          window_id:,
          width: None,
          height: None,
          x: Some(get_float(data, "x", 0.0)),
          y: Some(get_float(data, "y", 0.0)),
          scale_factor: None,
          path: None,
        ))
      })
    "window_resized" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.Resized,
          window_id:,
          width: Some(get_float(data, "width", 0.0)),
          height: Some(get_float(data, "height", 0.0)),
          x: None,
          y: None,
          scale_factor: None,
          path: None,
        ))
      })
    "window_focused" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.WindowFocused,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: None,
        ))
      })
    "window_unfocused" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.WindowUnfocused,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: None,
        ))
      })
    "window_rescaled" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.Rescaled,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: Some(get_float(data, "scale_factor", 1.0)),
          path: None,
        ))
      })
    "window_file_hovered" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.FileHovered,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: Some(get_string(data, "path", "")),
        ))
      })
    "window_file_dropped" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.FileDropped,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: Some(get_string(data, "path", "")),
        ))
      })
    "window_files_hovered_left" ->
      require_window_event(window_id, fn(window_id) {
        event.Window(event.WindowEvent(
          event_type: event.FilesHoveredLeft,
          window_id:,
          width: None,
          height: None,
          x: None,
          y: None,
          scale_factor: None,
          path: None,
        ))
      })

    // -- IME events ----------------------------------------------------------
    "ime_opened" ->
      Ok(
        event.Ime(event.ImeEvent(
          event_type: event.ImeOpened,
          window_id: result.unwrap(window_id, ""),
          text: None,
          cursor: None,
          captured: False,
        )),
      )
    "ime_preedit" ->
      Ok(
        event.Ime(event.ImeEvent(
          event_type: event.ImePreedit,
          window_id: result.unwrap(window_id, ""),
          text: Some(get_string(data, "text", "")),
          cursor: None,
          captured: False,
        )),
      )
    "ime_commit" ->
      Ok(
        event.Ime(event.ImeEvent(
          event_type: event.ImeCommit,
          window_id: result.unwrap(window_id, ""),
          text: Some(get_string(data, "text", "")),
          cursor: None,
          captured: False,
        )),
      )
    "ime_closed" ->
      Ok(
        event.Ime(event.ImeEvent(
          event_type: event.ImeClosed,
          window_id: result.unwrap(window_id, ""),
          text: None,
          cursor: None,
          captured: False,
        )),
      )

    // -- Modifiers changed ---------------------------------------------------
    "modifiers_changed" ->
      Ok(
        event.ModifiersChanged(event.ModifiersEvent(
          window_id: result.unwrap(window_id, ""),
          modifiers: decode_modifiers(data),
          captured: False,
        )),
      )

    // -- Unified pointer events -------------------------------------------------
    // New wire families from the updated renderer protocol.
    "press" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Press(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: decode_mouse_button(get_string(data, "button", "left")),
          pointer: decode_pointer_type(get_string(data, "pointer", "mouse")),
          finger: decode_finger(data),
          modifiers: decode_modifiers(data),
          captured: False,
        ))
      })
    "release" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Release(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          button: decode_mouse_button(get_string(data, "button", "left")),
          pointer: decode_pointer_type(get_string(data, "pointer", "mouse")),
          finger: decode_finger(data),
          modifiers: decode_modifiers(data),
          captured: False,
        ))
      })
    "move" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Move(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          pointer: decode_pointer_type(get_string(data, "pointer", "mouse")),
          finger: decode_finger(data),
          modifiers: decode_modifiers(data),
          captured: False,
        ))
      })
    "scroll" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Scroll(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          delta_x: get_float(data, "delta_x", 0.0),
          delta_y: get_float(data, "delta_y", 0.0),
          pointer: decode_pointer_type(get_string(data, "pointer", "mouse")),
          modifiers: decode_modifiers(data),
          unit: option.None,
          captured: False,
        ))
      })
    "enter" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Enter(
          target:,
          x: get_optional_float(data, "x"),
          y: get_optional_float(data, "y"),
        ))
      })
    "exit" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Exit(
          target:,
          x: get_optional_float(data, "x"),
          y: get_optional_float(data, "y"),
        ))
      })
    "double_click" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.DoubleClick(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          pointer: decode_pointer_type(get_string(data, "pointer", "mouse")),
          modifiers: decode_modifiers(data),
        ))
      })
    "resize" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Resize(
          target:,
          width: get_float(data, "width", 0.0),
          height: get_float(data, "height", 0.0),
        ))
      })
    "focused" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Focused(target:))
      })
    "blurred" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Blurred(target:))
      })
    "drag" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Drag(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
          delta_x: get_float(data, "delta_x", 0.0),
          delta_y: get_float(data, "delta_y", 0.0),
        ))
      })
    "drag_end" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.DragEnd(
          target:,
          x: get_float(data, "x", 0.0),
          y: get_float(data, "y", 0.0),
        ))
      })
    "transition_complete" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.TransitionComplete(
          target:,
          tag: get_string(data, "tag", ""),
          prop: get_string(data, "prop", ""),
        ))
      })

    "diagnostic" ->
      Ok(
        event.Error(event.Diagnostic(
          level: get_string(data, "level", ""),
          element_id: get_string(data, "element_id", ""),
          code: get_string(data, "code", ""),
          message: get_string(data, "message", ""),
        )),
      )

    // -- Pane events ---------------------------------------------------------
    "pane_resized" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.PaneResized(
          target:,
          split: get_dynamic(data, "split"),
          ratio: get_float(data, "ratio", 0.5),
        ))
      })
    "pane_dragged" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.PaneDragged(
          target:,
          pane: get_dynamic(data, "pane"),
          drop_target: get_dynamic(data, "target"),
          action: get_string(data, "action", ""),
          region: get_optional_string(data, "region"),
          edge: get_optional_string(data, "edge"),
        ))
      })
    "pane_clicked" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.PaneClicked(target:, pane: get_dynamic(data, "pane")))
      })
    "pane_focus_cycle" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.PaneFocusCycle(
          target:,
          pane: get_dynamic(data, "pane"),
        ))
      })

    // -- Sensor events (unified WidgetResize) ---------------------------------
    "sensor_resize" ->
      require_window_event(window_id, fn(_window_id) {
        event.Widget(event.Resize(
          target:,
          width: get_float(data, "width", 0.0),
          height: get_float(data, "height", 0.0),
        ))
      })

    // -- System events -------------------------------------------------------
    "animation_frame" ->
      Ok(
        event.System(
          event.AnimationFrame(timestamp: get_int(data, "timestamp", 0)),
        ),
      )
    "theme_changed" ->
      Ok(event.System(event.ThemeChanged(theme: get_string(data, "theme", ""))))
    "all_windows_closed" -> Ok(event.System(event.AllWindowsClosed))

    _ -> Error(Nil)
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
fn decode_key_press(data: Dict(String, Dynamic), window_id: String) -> Event {
  let key = parse_wire_key_name(get_string(data, "value", ""))
  let modifiers = decode_modifiers(data)
  let text = case string.length(key) == 1 {
    True -> Some(key)
    False -> None
  }
  event.Key(event.KeyEvent(
    event_type: event.KeyPressed,
    window_id:,
    key:,
    modified_key: key,
    modifiers:,
    physical_key: None,
    location: event.Standard,
    text:,
    repeat: False,
    captured: False,
  ))
}

@target(erlang)
fn decode_key_release(data: Dict(String, Dynamic), window_id: String) -> Event {
  let key = parse_wire_key_name(get_string(data, "value", ""))
  let modifiers = decode_modifiers(data)
  let text = case string.length(key) == 1 {
    True -> Some(key)
    False -> None
  }
  event.Key(event.KeyEvent(
    event_type: event.KeyReleased,
    window_id:,
    key:,
    modified_key: key,
    modifiers:,
    physical_key: None,
    location: event.Standard,
    text:,
    repeat: False,
    captured: False,
  ))
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
fn decode_mouse_button(name: String) -> MouseButton {
  case name {
    "left" -> LeftButton
    "right" -> RightButton
    "middle" -> MiddleButton
    "back" -> BackButton
    "forward" -> ForwardButton
    other -> OtherButton(other)
  }
}

@target(erlang)
fn decode_pointer_type(name: String) -> PointerType {
  case name {
    "touch" -> Touch
    "pen" -> Pen
    _ -> Mouse
  }
}

@target(erlang)
fn decode_finger(data: Dict(String, Dynamic)) -> option.Option(Int) {
  case dict.get(data, "finger") {
    Ok(val) ->
      case decode.run(val, decode.int) {
        Ok(n) -> option.Some(n)
        Error(_) -> option.None
      }
    Error(_) -> option.None
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
