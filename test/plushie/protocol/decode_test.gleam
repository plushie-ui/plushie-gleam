import gleam/bit_array
import gleam/option.{None, Some}
import gleeunit/should
import plushie/event
import plushie/protocol
import plushie/protocol/decode

// ---------------------------------------------------------------------------
// split_scoped_id
// ---------------------------------------------------------------------------

pub fn split_scoped_id_simple_test() {
  let #(id, scope) = decode.split_scoped_id("button")
  should.equal(id, "button")
  should.equal(scope, [])
}

pub fn split_scoped_id_single_scope_test() {
  let #(id, scope) = decode.split_scoped_id("form/email")
  should.equal(id, "email")
  should.equal(scope, ["form"])
}

pub fn split_scoped_id_multi_scope_test() {
  let #(id, scope) = decode.split_scoped_id("sidebar/form/email")
  should.equal(id, "email")
  should.equal(scope, ["form", "sidebar"])
}

pub fn split_scoped_id_deep_scope_test() {
  let #(id, scope) = decode.split_scoped_id("a/b/c/d")
  should.equal(id, "d")
  should.equal(scope, ["c", "b", "a"])
}

// ---------------------------------------------------------------------------
// Hello message
// ---------------------------------------------------------------------------

pub fn decode_hello_json_test() {
  let json =
    "{\"type\":\"hello\",\"protocol\":1,\"version\":\"0.1.0\",\"name\":\"plushie\"}"
  let data = bit_array.from_string(json)
  let assert Ok(msg) = decode.decode_message(data, protocol.Json)
  case msg {
    decode.Hello(protocol:, version:, name:, ..) -> {
      should.equal(protocol, 1)
      should.equal(version, "0.1.0")
      should.equal(name, "plushie")
    }
    _ -> should.fail()
  }
}

pub fn decode_hello_with_extras_json_test() {
  let json =
    "{\"type\":\"hello\",\"protocol\":1,\"version\":\"0.2.0\",\"name\":\"plushie\",\"backend\":\"iced\",\"extensions\":[\"canvas\"]}"
  let data = bit_array.from_string(json)
  let assert Ok(msg) = decode.decode_message(data, protocol.Json)
  case msg {
    decode.Hello(
      protocol:,
      version:,
      name:,
      backend:,
      extensions:,
      transport: _,
    ) -> {
      should.equal(protocol, 1)
      should.equal(version, "0.2.0")
      should.equal(name, "plushie")
      should.equal(backend, "iced")
      should.equal(extensions, ["canvas"])
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Click event
// ---------------------------------------------------------------------------

pub fn decode_click_json_test() {
  let json = "{\"type\":\"event\",\"family\":\"click\",\"id\":\"btn_save\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WidgetClick(id:, scope:) -> {
      should.equal(id, "btn_save")
      should.equal(scope, [])
    }
    _ -> should.fail()
  }
}

pub fn decode_click_scoped_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"click\",\"id\":\"form/btn_save\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WidgetClick(id:, scope:) -> {
      should.equal(id, "btn_save")
      should.equal(scope, ["form"])
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Input event
// ---------------------------------------------------------------------------

pub fn decode_input_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"input\",\"id\":\"name_field\",\"value\":\"Arthur Dent\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WidgetInput(id:, scope:, value:) -> {
      should.equal(id, "name_field")
      should.equal(scope, [])
      should.equal(value, "Arthur Dent")
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Toggle event
// ---------------------------------------------------------------------------

pub fn decode_toggle_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"toggle\",\"id\":\"dark_mode\",\"value\":true}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WidgetToggle(id:, scope:, value:) -> {
      should.equal(id, "dark_mode")
      should.equal(scope, [])
      should.equal(value, True)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Slide event
// ---------------------------------------------------------------------------

pub fn decode_slide_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"slide\",\"id\":\"volume\",\"value\":0.75}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WidgetSlide(id:, scope:, value:) -> {
      should.equal(id, "volume")
      should.equal(scope, [])
      should.equal(value, 0.75)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Key press event
// ---------------------------------------------------------------------------

pub fn decode_key_press_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"key_press\",\"modifiers\":{\"ctrl\":true,\"shift\":false,\"alt\":false,\"logo\":false,\"command\":false},\"data\":{\"key\":\"s\",\"physical_key\":\"KeyS\",\"location\":\"standard\",\"text\":\"s\",\"repeat\":false}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.KeyPress(
      key:,
      modified_key:,
      modifiers:,
      physical_key:,
      location:,
      text:,
      repeat:,
      captured:,
    ) -> {
      should.equal(key, "s")
      should.equal(modified_key, "s")
      should.equal(modifiers.ctrl, True)
      should.equal(modifiers.shift, False)
      should.equal(physical_key, Some("KeyS"))
      should.equal(location, event.Standard)
      should.equal(text, Some("s"))
      should.equal(repeat, False)
      should.equal(captured, False)
    }
    _ -> should.fail()
  }
}

pub fn decode_key_press_numpad_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"key_press\",\"modifiers\":{},\"data\":{\"key\":\"5\",\"location\":\"numpad\",\"repeat\":true}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.KeyPress(key:, location:, repeat:, ..) -> {
      should.equal(key, "5")
      should.equal(location, event.Numpad)
      should.equal(repeat, True)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Window opened event
// ---------------------------------------------------------------------------

pub fn decode_window_opened_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"window_opened\",\"data\":{\"window_id\":\"main\",\"width\":800.0,\"height\":600.0,\"x\":100.0,\"y\":50.0,\"scale_factor\":2.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WindowOpened(
      window_id:,
      width:,
      height:,
      position_x:,
      position_y:,
      scale_factor:,
    ) -> {
      should.equal(window_id, "main")
      should.equal(width, 800.0)
      should.equal(height, 600.0)
      should.equal(position_x, Some(100.0))
      should.equal(position_y, Some(50.0))
      should.equal(scale_factor, 2.0)
    }
    _ -> should.fail()
  }
}

pub fn decode_window_closed_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"window_closed\",\"data\":{\"window_id\":\"settings\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WindowClosed(window_id:) -> should.equal(window_id, "settings")
    _ -> should.fail()
  }
}

pub fn decode_window_resized_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"window_resized\",\"data\":{\"window_id\":\"main\",\"width\":1024.0,\"height\":768.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WindowResized(window_id:, width:, height:) -> {
      should.equal(window_id, "main")
      should.equal(width, 1024.0)
      should.equal(height, 768.0)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Effect response
// ---------------------------------------------------------------------------

pub fn decode_effect_response_ok_json_test() {
  let json =
    "{\"type\":\"effect_response\",\"id\":\"req_42\",\"status\":\"ok\",\"result\":{\"path\":\"/tmp/test.txt\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.EffectResponse(request_id:, result:) -> {
      should.equal(request_id, "req_42")
      case result {
        event.EffectOk(_) -> Nil
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

pub fn decode_effect_response_cancelled_json_test() {
  let json =
    "{\"type\":\"effect_response\",\"id\":\"req_99\",\"status\":\"cancelled\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.EffectResponse(request_id:, result:) -> {
      should.equal(request_id, "req_99")
      should.equal(result, event.EffectCancelled)
    }
    _ -> should.fail()
  }
}

pub fn decode_effect_response_error_json_test() {
  let json =
    "{\"type\":\"effect_response\",\"id\":\"req_7\",\"status\":\"error\",\"error\":\"not found\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.EffectResponse(request_id:, result:) -> {
      should.equal(request_id, "req_7")
      case result {
        event.EffectError(_) -> Nil
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Unknown family
// ---------------------------------------------------------------------------

pub fn decode_unknown_family_falls_through_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"quantum_flux\",\"id\":\"widget_x\",\"value\":42}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WidgetEvent(kind:, id:, scope:, ..) -> {
      should.equal(kind, "quantum_flux")
      should.equal(id, "widget_x")
      should.equal(scope, [])
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Unknown message type
// ---------------------------------------------------------------------------

pub fn decode_unknown_message_type_json_test() {
  let json = "{\"type\":\"warp_drive\"}"
  let data = bit_array.from_string(json)
  let assert Error(protocol.UnknownMessageType("warp_drive")) =
    decode.decode_message(data, protocol.Json)
}

// ---------------------------------------------------------------------------
// Malformed data
// ---------------------------------------------------------------------------

pub fn decode_invalid_json_test() {
  let data = bit_array.from_string("not json at all")
  let assert Error(protocol.DeserializationFailed(_)) =
    decode.decode_message(data, protocol.Json)
}

pub fn decode_non_map_json_test() {
  let data = bit_array.from_string("[1, 2, 3]")
  let assert Error(protocol.DeserializationFailed(_)) =
    decode.decode_message(data, protocol.Json)
}

// ---------------------------------------------------------------------------
// Mouse events
// ---------------------------------------------------------------------------

pub fn decode_cursor_moved_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"cursor_moved\",\"data\":{\"x\":150.5,\"y\":200.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseMoved(x:, y:, captured:) -> {
      should.equal(x, 150.5)
      should.equal(y, 200.0)
      should.equal(captured, False)
    }
    _ -> should.fail()
  }
}

pub fn decode_cursor_entered_json_test() {
  let json = "{\"type\":\"event\",\"family\":\"cursor_entered\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(event.MouseEntered(captured: False))) =
    decode.decode_message(data, protocol.Json)
}

pub fn decode_cursor_left_json_test() {
  let json = "{\"type\":\"event\",\"family\":\"cursor_left\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(event.MouseLeft(captured: False))) =
    decode.decode_message(data, protocol.Json)
}

pub fn decode_wheel_scrolled_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"wheel_scrolled\",\"data\":{\"delta_x\":0.0,\"delta_y\":-3.0,\"unit\":\"line\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseWheelScrolled(delta_x:, delta_y:, unit:, captured:) -> {
      should.equal(delta_x, 0.0)
      should.equal(delta_y, -3.0)
      should.equal(unit, event.Line)
      should.equal(captured, False)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Touch events
// ---------------------------------------------------------------------------

pub fn decode_finger_pressed_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"finger_pressed\",\"data\":{\"id\":1,\"x\":100.0,\"y\":200.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.TouchPressed(finger_id:, x:, y:, captured:) -> {
      should.equal(finger_id, 1)
      should.equal(x, 100.0)
      should.equal(y, 200.0)
      should.equal(captured, False)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// All windows closed
// ---------------------------------------------------------------------------

pub fn decode_all_windows_closed_json_test() {
  let json = "{\"type\":\"event\",\"family\":\"all_windows_closed\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(event.AllWindowsClosed)) =
    decode.decode_message(data, protocol.Json)
}

// ---------------------------------------------------------------------------
// Animation frame
// ---------------------------------------------------------------------------

pub fn decode_animation_frame_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"animation_frame\",\"data\":{\"timestamp\":1234567890}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.AnimationFrame(timestamp:) -> should.equal(timestamp, 1_234_567_890)
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Theme changed
// ---------------------------------------------------------------------------

pub fn decode_theme_changed_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"theme_changed\",\"value\":\"dark\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.ThemeChanged(theme:) -> should.equal(theme, "dark")
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Modifiers changed
// ---------------------------------------------------------------------------

pub fn decode_modifiers_changed_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"modifiers_changed\",\"modifiers\":{\"shift\":true,\"ctrl\":false,\"alt\":true,\"logo\":false,\"command\":false}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.ModifiersChanged(modifiers:, captured:) -> {
      should.equal(modifiers.shift, True)
      should.equal(modifiers.ctrl, False)
      should.equal(modifiers.alt, True)
      should.equal(captured, False)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// JSONL trailing newline
// ---------------------------------------------------------------------------

pub fn decode_json_with_trailing_newline_test() {
  let json =
    "{\"type\":\"hello\",\"protocol\":1,\"version\":\"0.1.0\",\"name\":\"plushie\"}\n"
  let data = bit_array.from_string(json)
  let assert Ok(decode.Hello(..)) = decode.decode_message(data, protocol.Json)
}

// ---------------------------------------------------------------------------
// captured:true on subscription events
// ---------------------------------------------------------------------------

pub fn decode_key_press_captured_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"key_press\",\"captured\":true,\"modifiers\":{},\"data\":{\"key\":\"a\",\"modified_key\":\"A\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.KeyPress(key:, modified_key:, captured:, ..) -> {
      should.equal(key, "a")
      should.equal(modified_key, "A")
      should.equal(captured, True)
    }
    _ -> should.fail()
  }
}

pub fn decode_key_press_modified_key_fallback_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"key_press\",\"modifiers\":{},\"data\":{\"key\":\"Enter\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.KeyPress(key:, modified_key:, ..) -> {
      should.equal(key, "Enter")
      should.equal(modified_key, "Enter")
    }
    _ -> should.fail()
  }
}

pub fn decode_cursor_moved_captured_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"cursor_moved\",\"captured\":true,\"data\":{\"x\":10.0,\"y\":20.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseMoved(captured:, ..) -> should.equal(captured, True)
    _ -> should.fail()
  }
}

pub fn decode_cursor_entered_captured_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"cursor_entered\",\"captured\":true}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(event.MouseEntered(captured: True))) =
    decode.decode_message(data, protocol.Json)
}

pub fn decode_finger_pressed_captured_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"finger_pressed\",\"captured\":true,\"data\":{\"id\":0,\"x\":5.0,\"y\":5.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.TouchPressed(captured:, ..) -> should.equal(captured, True)
    _ -> should.fail()
  }
}

pub fn decode_ime_opened_captured_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"ime_opened\",\"id\":\"input1\",\"captured\":true}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.ImeOpened(captured:) -> should.equal(captured, True)
    _ -> should.fail()
  }
}

pub fn decode_wheel_scrolled_captured_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"wheel_scrolled\",\"captured\":true,\"data\":{\"delta_x\":1.0,\"delta_y\":2.0,\"unit\":\"pixel\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseWheelScrolled(captured:, ..) -> should.equal(captured, True)
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Hello transport field
// ---------------------------------------------------------------------------

pub fn decode_hello_transport_default_json_test() {
  let json =
    "{\"type\":\"hello\",\"protocol\":1,\"version\":\"0.1.0\",\"name\":\"plushie\"}"
  let data = bit_array.from_string(json)
  let assert Ok(msg) = decode.decode_message(data, protocol.Json)
  case msg {
    decode.Hello(transport:, ..) -> should.equal(transport, "stdio")
    _ -> should.fail()
  }
}

pub fn decode_hello_transport_explicit_json_test() {
  let json =
    "{\"type\":\"hello\",\"protocol\":1,\"version\":\"0.1.0\",\"name\":\"plushie\",\"transport\":\"websocket\"}"
  let data = bit_array.from_string(json)
  let assert Ok(msg) = decode.decode_message(data, protocol.Json)
  case msg {
    decode.Hello(transport:, ..) -> should.equal(transport, "websocket")
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Announce event
// ---------------------------------------------------------------------------

pub fn decode_announce_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"announce\",\"data\":{\"text\":\"Item added\"}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.Announce(text:) -> should.equal(text, "Item added")
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// DuplicateNodeIds error event
// ---------------------------------------------------------------------------

pub fn decode_duplicate_node_ids_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"error\",\"id\":\"duplicate_node_ids\",\"data\":{\"ids\":[\"btn1\"]}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.DuplicateNodeIds(..) -> Nil
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// WindowOpened with no position
// ---------------------------------------------------------------------------

pub fn decode_window_opened_no_position_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"window_opened\",\"data\":{\"window_id\":\"main\",\"width\":800.0,\"height\":600.0,\"scale_factor\":1.0}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WindowOpened(position_x:, position_y:, ..) -> {
      should.equal(position_x, None)
      should.equal(position_y, None)
    }
    _ -> should.fail()
  }
}

pub fn decode_window_opened_nested_position_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"window_opened\",\"data\":{\"window_id\":\"w\",\"width\":400.0,\"height\":300.0,\"position\":{\"x\":10.0,\"y\":20.0}}}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.WindowOpened(position_x:, position_y:, ..) -> {
      should.equal(position_x, Some(10.0))
      should.equal(position_y, Some(20.0))
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// MouseArea events without coordinates
// ---------------------------------------------------------------------------

pub fn decode_mouse_right_press_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"mouse_right_press\",\"id\":\"area1\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseAreaRightPress(id:, scope:) -> {
      should.equal(id, "area1")
      should.equal(scope, [])
    }
    _ -> should.fail()
  }
}

pub fn decode_mouse_double_click_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"mouse_double_click\",\"id\":\"area2\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseAreaDoubleClick(id:, scope:) -> {
      should.equal(id, "area2")
      should.equal(scope, [])
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// MouseButton events without coordinates
// ---------------------------------------------------------------------------

pub fn decode_button_pressed_json_test() {
  let json =
    "{\"type\":\"event\",\"family\":\"button_pressed\",\"value\":\"right\"}"
  let data = bit_array.from_string(json)
  let assert Ok(decode.EventMessage(evt)) =
    decode.decode_message(data, protocol.Json)
  case evt {
    event.MouseButtonPressed(button:, captured:) -> {
      should.equal(button, event.RightButton)
      should.equal(captured, False)
    }
    _ -> should.fail()
  }
}
