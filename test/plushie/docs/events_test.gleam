import gleam/dynamic
import gleam/option
import gleeunit/should
import plushie/event.{
  type Event, AnimationFrame, AsyncResult, CanvasMove, CanvasPress,
  EffectCancelled, EffectError, EffectOk, EffectResponse, ImeCommit, ImePreedit,
  KeyPress, LeftButton, Modifiers, ModifiersChanged, MouseAreaEnter,
  MouseAreaMove, MouseButtonPressed, MouseMoved, PaneClicked, PaneResized,
  ScrollData, SensorResize, Standard, StreamValue, ThemeChanged, TimerTick,
  TouchPressed, WidgetClick, WidgetClose, WidgetEvent, WidgetInput,
  WidgetKeyBinding, WidgetOpen, WidgetOptionHovered, WidgetPaste, WidgetScroll,
  WidgetSelect, WidgetSlide, WidgetSlideRelease, WidgetSort, WidgetSubmit,
  WidgetToggle, WindowCloseRequested, WindowFileDropped, WindowFileHovered,
  WindowFilesHoveredLeft, WindowResized,
}

// -- Widget events -----------------------------------------------------------

pub fn events_widget_click_construct_test() {
  let event = WidgetClick(window_id: "main", id: "save", scope: [])
  event.id |> should.equal("save")
  event.scope |> should.equal([])
}

pub fn events_widget_click_match_test() {
  let event: Event = WidgetClick(window_id: "main", id: "save", scope: [])
  case event {
    WidgetClick(window_id: "main", id: "save", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_click_scope_test() {
  let event: Event = WidgetClick(window_id: "main", id: "save", scope: ["form"])
  case event {
    WidgetClick(window_id: "main", id: "save", scope: ["form"]) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_input_match_test() {
  let event: Event =
    WidgetInput(window_id: "main", id: "search", scope: [], value: "hello")
  case event {
    WidgetInput(window_id: "main", id: "search", value:, ..) ->
      value |> should.equal("hello")
    _ -> should.fail()
  }
}

pub fn events_widget_submit_match_test() {
  let event: Event =
    WidgetSubmit(window_id: "main", id: "search", scope: [], value: "query")
  case event {
    WidgetSubmit(window_id: "main", id: "search", value: query, ..) ->
      query |> should.equal("query")
    _ -> should.fail()
  }
}

pub fn events_widget_toggle_match_test() {
  let event: Event =
    WidgetToggle(window_id: "main", id: "dark_mode", scope: [], value: True)
  case event {
    WidgetToggle(window_id: "main", id: "dark_mode", value: enabled, ..) ->
      enabled |> should.be_true()
    _ -> should.fail()
  }
}

pub fn events_widget_select_match_test() {
  let event: Event =
    WidgetSelect(
      window_id: "main",
      id: "theme_picker",
      scope: [],
      value: "nord",
    )
  case event {
    WidgetSelect(window_id: "main", id: "theme_picker", value: theme, ..) ->
      theme |> should.equal("nord")
    _ -> should.fail()
  }
}

pub fn events_widget_slide_match_test() {
  let event: Event =
    WidgetSlide(window_id: "main", id: "volume", scope: [], value: 75.0)
  case event {
    WidgetSlide(window_id: "main", id: "volume", value:, ..) ->
      value |> should.equal(75.0)
    _ -> should.fail()
  }
}

pub fn events_widget_slide_release_match_test() {
  let event: Event =
    WidgetSlideRelease(window_id: "main", id: "volume", scope: [], value: 75.0)
  case event {
    WidgetSlideRelease(window_id: "main", id: "volume", value:, ..) ->
      value |> should.equal(75.0)
    _ -> should.fail()
  }
}

pub fn events_widget_key_binding_match_test() {
  let event: Event =
    WidgetKeyBinding(window_id: "main", id: "editor", scope: [], value: "save")
  case event {
    WidgetKeyBinding(window_id: "main", id: "editor", value: "save", ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_scroll_match_test() {
  let event: Event =
    WidgetScroll(
      window_id: "main",
      id: "log_view",
      scope: [],
      data: ScrollData(
        absolute_x: 0.0,
        absolute_y: 150.0,
        relative_x: 0.0,
        relative_y: 0.75,
        bounds_width: 400.0,
        bounds_height: 300.0,
        content_width: 400.0,
        content_height: 600.0,
      ),
    )
  case event {
    WidgetScroll(window_id: "main", id: "log_view", data: viewport, ..) -> {
      let at_bottom = viewport.relative_y >=. 0.99
      at_bottom |> should.be_false()
    }
    _ -> should.fail()
  }
}

pub fn events_widget_paste_match_test() {
  let event: Event =
    WidgetPaste(window_id: "main", id: "url_input", scope: [], value: " text ")
  case event {
    WidgetPaste(window_id: "main", id: "url_input", value: text, ..) ->
      text |> should.equal(" text ")
    _ -> should.fail()
  }
}

pub fn events_widget_option_hovered_match_test() {
  let event: Event =
    WidgetOptionHovered(
      window_id: "main",
      id: "search",
      scope: [],
      value: "opt1",
    )
  case event {
    WidgetOptionHovered(window_id: "main", id: "search", value:, ..) ->
      value |> should.equal("opt1")
    _ -> should.fail()
  }
}

pub fn events_widget_open_close_match_test() {
  let open: Event =
    WidgetOpen(window_id: "main", id: "country_picker", scope: [])
  let close: Event =
    WidgetClose(window_id: "main", id: "country_picker", scope: [])
  case open {
    WidgetOpen(window_id: "main", id: "country_picker", ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
  case close {
    WidgetClose(window_id: "main", id: "country_picker", ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_sort_match_test() {
  let event: Event =
    WidgetSort(window_id: "main", id: "users", scope: [], value: "name")
  case event {
    WidgetSort(window_id: "main", id: "users", value: column_key, ..) ->
      column_key |> should.equal("name")
    _ -> should.fail()
  }
}

// -- Mouse area events -------------------------------------------------------

pub fn events_mouse_area_enter_match_test() {
  let event: Event =
    MouseAreaEnter(window_id: "main", id: "hover_zone", scope: [])
  case event {
    MouseAreaEnter(window_id: "main", id: "hover_zone", ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_mouse_area_move_match_test() {
  let event: Event =
    MouseAreaMove(
      window_id: "main",
      id: "canvas_area",
      scope: [],
      x: 10.0,
      y: 20.0,
    )
  case event {
    MouseAreaMove(window_id: "main", id: "canvas_area", x:, y:, ..) -> {
      x |> should.equal(10.0)
      y |> should.equal(20.0)
    }
    _ -> should.fail()
  }
}

// -- Canvas events -----------------------------------------------------------

pub fn events_canvas_press_match_test() {
  let event: Event =
    CanvasPress(
      window_id: "main",
      id: "draw_area",
      scope: [],
      x: 42.0,
      y: 100.0,
      button: "left",
    )
  case event {
    CanvasPress(window_id: "main", id: "draw_area", x:, y:, button: "left", ..) -> {
      x |> should.equal(42.0)
      y |> should.equal(100.0)
    }
    _ -> should.fail()
  }
}

pub fn events_canvas_move_match_test() {
  let event: Event =
    CanvasMove(window_id: "main", id: "draw_area", scope: [], x: 5.0, y: 10.0)
  case event {
    CanvasMove(window_id: "main", id: "draw_area", x:, y:, ..) -> {
      x |> should.equal(5.0)
      y |> should.equal(10.0)
    }
    _ -> should.fail()
  }
}

pub fn events_canvas_element_event_match_test() {
  let event: Event =
    WidgetEvent(
      kind: "canvas_element_click",
      window_id: "main",
      id: "chart",
      scope: [],
      value: dynamic.nil(),
      data: dynamic.nil(),
    )
  case event {
    WidgetEvent(kind: "canvas_element_click", id: "chart", ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- Sensor events -----------------------------------------------------------

pub fn events_sensor_resize_match_test() {
  let event: Event =
    SensorResize(
      window_id: "main",
      id: "content_area",
      scope: [],
      width: 800.0,
      height: 600.0,
    )
  case event {
    SensorResize(window_id: "main", id: "content_area", width:, height:, ..) -> {
      width |> should.equal(800.0)
      height |> should.equal(600.0)
    }
    _ -> should.fail()
  }
}

// -- PaneGrid events ---------------------------------------------------------

pub fn events_pane_resized_match_test() {
  let event: Event =
    PaneResized(
      window_id: "main",
      id: "editor",
      scope: [],
      split: dynamic.string("split_1"),
      ratio: 0.5,
    )
  case event {
    PaneResized(window_id: "main", id: "editor", ratio:, ..) ->
      ratio |> should.equal(0.5)
    _ -> should.fail()
  }
}

pub fn events_pane_clicked_match_test() {
  let event: Event =
    PaneClicked(
      window_id: "main",
      id: "editor",
      scope: [],
      pane: dynamic.string("left"),
    )
  case event {
    PaneClicked(window_id: "main", id: "editor", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Keyboard events ---------------------------------------------------------

pub fn events_key_press_cmd_s_match_test() {
  let event: Event =
    KeyPress(
      window_id: "",
      key: "s",
      modified_key: "s",
      modifiers: Modifiers(..event.modifiers_none(), command: True),
      physical_key: option.Some("KeyS"),
      location: Standard,
      text: option.Some("s"),
      repeat: False,
      captured: False,
    )
  case event {
    KeyPress(key: "s", modifiers: Modifiers(command: True, ..), ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_key_press_escape_match_test() {
  let event: Event =
    KeyPress(
      window_id: "",
      key: "Escape",
      modified_key: "Escape",
      modifiers: event.modifiers_none(),
      physical_key: option.Some("Escape"),
      location: Standard,
      text: option.None,
      repeat: False,
      captured: False,
    )
  case event {
    KeyPress(key: "Escape", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_key_press_physical_key_match_test() {
  let event: Event =
    KeyPress(
      window_id: "",
      key: "w",
      modified_key: "w",
      modifiers: event.modifiers_none(),
      physical_key: option.Some("KeyW"),
      location: Standard,
      text: option.Some("w"),
      repeat: False,
      captured: False,
    )
  case event {
    KeyPress(physical_key: option.Some("KeyW"), ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_key_press_text_field_match_test() {
  let event: Event =
    KeyPress(
      window_id: "",
      key: "a",
      modified_key: "a",
      modifiers: event.modifiers_none(),
      physical_key: option.Some("KeyA"),
      location: Standard,
      text: option.Some("a"),
      repeat: False,
      captured: False,
    )
  case event {
    KeyPress(text: option.Some(text), ..) -> text |> should.equal("a")
    _ -> should.fail()
  }
}

pub fn events_modifiers_construct_test() {
  let mods =
    Modifiers(shift: True, ctrl: False, alt: False, logo: False, command: False)
  mods.shift |> should.be_true()
  mods.ctrl |> should.be_false()
}

// -- IME events --------------------------------------------------------------

pub fn events_ime_preedit_match_test() {
  let event =
    ImePreedit(
      window_id: "",
      text: "compose",
      cursor: option.Some(#(0, 7)),
      captured: False,
    )
  event.text |> should.equal("compose")
}

pub fn events_ime_commit_match_test() {
  let event = ImeCommit(window_id: "", text: "final", captured: False)
  event.text |> should.equal("final")
}

// -- Mouse events (global) ---------------------------------------------------

pub fn events_mouse_moved_match_test() {
  let event = MouseMoved(window_id: "", x: 100.0, y: 200.0, captured: False)
  event.x |> should.equal(100.0)
  event.y |> should.equal(200.0)
}

pub fn events_mouse_button_pressed_match_test() {
  let event: Event =
    MouseButtonPressed(window_id: "", button: LeftButton, captured: False)
  case event {
    MouseButtonPressed(button: LeftButton, ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Touch events ------------------------------------------------------------

pub fn events_touch_pressed_match_test() {
  let event =
    TouchPressed(window_id: "", finger_id: 0, x: 50.0, y: 75.0, captured: False)
  event.x |> should.equal(50.0)
  event.y |> should.equal(75.0)
}

// -- Modifier state events ---------------------------------------------------

pub fn events_modifiers_changed_match_test() {
  let event =
    ModifiersChanged(
      window_id: "",
      modifiers: Modifiers(
        shift: True,
        ctrl: False,
        alt: False,
        logo: False,
        command: False,
      ),
      captured: False,
    )
  event.modifiers.shift |> should.be_true()
}

// -- Window events -----------------------------------------------------------

pub fn events_window_close_requested_match_test() {
  let event: Event = WindowCloseRequested(window_id: "main")
  case event {
    WindowCloseRequested(window_id: "main") -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_window_resized_match_test() {
  let event: Event =
    WindowResized(window_id: "main", width: 800.0, height: 600.0)
  case event {
    WindowResized(window_id: "main", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_window_file_drag_drop_match_test() {
  let hovered: Event = WindowFileHovered(window_id: "main", path: "/foo.txt")
  let dropped: Event = WindowFileDropped(window_id: "main", path: "/foo.txt")
  let left: Event = WindowFilesHoveredLeft(window_id: "main")
  case hovered {
    WindowFileHovered(window_id: "main", path:) ->
      path |> should.equal("/foo.txt")
    _ -> should.fail()
  }
  case dropped {
    WindowFileDropped(window_id: "main", path:) ->
      path |> should.equal("/foo.txt")
    _ -> should.fail()
  }
  case left {
    WindowFilesHoveredLeft(window_id: "main") -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- System events -----------------------------------------------------------

pub fn events_animation_frame_construct_test() {
  let event = AnimationFrame(timestamp: 12_345)
  event.timestamp |> should.equal(12_345)
}

pub fn events_theme_changed_construct_test() {
  let event = ThemeChanged(theme: "dark")
  event.theme |> should.equal("dark")
}

// -- Timer events ------------------------------------------------------------

pub fn events_timer_tick_match_test() {
  let event: Event = TimerTick(tag: "tick", timestamp: 1_000_000)
  case event {
    TimerTick(tag: "tick", timestamp: ts) -> ts |> should.equal(1_000_000)
    _ -> should.fail()
  }
}

// -- Command result events ---------------------------------------------------

pub fn events_async_result_ok_match_test() {
  let event: Event =
    AsyncResult(tag: "data_loaded", result: Ok(dynamic.string("hello")))
  case event {
    AsyncResult(tag: "data_loaded", result: Ok(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_async_result_error_match_test() {
  let event: Event =
    AsyncResult(tag: "data_loaded", result: Error(dynamic.string("fail")))
  case event {
    AsyncResult(tag: "data_loaded", result: Error(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_stream_value_match_test() {
  let event: Event = StreamValue(tag: "file_import", value: dynamic.int(42))
  case event {
    StreamValue(tag: "file_import", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Effect result events ----------------------------------------------------

pub fn events_effect_response_ok_match_test() {
  let event: Event =
    EffectResponse(request_id: "ef_1234", result: EffectOk(dynamic.nil()))
  case event {
    EffectResponse(result: EffectOk(_data), ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_effect_response_cancelled_match_test() {
  let event: Event =
    EffectResponse(request_id: "ef_1234", result: EffectCancelled)
  case event {
    EffectResponse(result: EffectCancelled, ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_effect_response_error_match_test() {
  let event: Event =
    EffectResponse(
      request_id: "ef_1234",
      result: EffectError(dynamic.string("err")),
    )
  case event {
    EffectResponse(result: EffectError(_reason), ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Pattern matching tips ---------------------------------------------------

pub fn events_pattern_prefix_match_test() {
  let event: Event =
    WidgetClick(window_id: "main", id: "nav:settings", scope: [])
  case event {
    WidgetClick(window_id: "main", id: "nav:" <> section, ..) ->
      section |> should.equal("settings")
    _ -> should.fail()
  }
}

pub fn events_pattern_toggle_prefix_match_test() {
  let event: Event =
    WidgetToggle(window_id: "main", id: "setting:theme", scope: [], value: True)
  case event {
    WidgetToggle(window_id: "main", id: "setting:" <> key, value:, ..) -> {
      key |> should.equal("theme")
      value |> should.be_true()
    }
    _ -> should.fail()
  }
}

// -- Scope matching ----------------------------------------------------------

pub fn events_scope_sidebar_match_test() {
  let event: Event =
    WidgetClick(window_id: "main", id: "save", scope: ["sidebar"])
  case event {
    WidgetClick(window_id: "main", id: "save", scope: ["sidebar", ..]) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_scope_main_match_test() {
  let event: Event = WidgetClick(window_id: "main", id: "save", scope: ["main"])
  case event {
    WidgetClick(window_id: "main", id: "save", scope: ["main", ..]) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_catch_all_test() {
  let event: Event = WidgetClick(window_id: "main", id: "unknown", scope: [])
  let result = case event {
    WidgetClick(window_id: "main", id: "save", ..) -> "save"
    _ -> "fallback"
  }
  result |> should.equal("fallback")
}
