import gleam/dynamic
import gleam/option
import gleeunit/should
import plushie/event.{
  type Event, AnimationFrame, Async, AsyncEvent, Click, Close, CloseRequested,
  CustomWidget, Effect, EffectCancelled, EffectError, EffectEvent, Enter,
  EventTarget, FileDropped, FileHovered, FileOpened, FilesHoveredLeft, Ime,
  ImeCommit, ImeEvent, ImePreedit, Input, Key, KeyBinding, KeyEvent, KeyPressed,
  LeftButton, Modifiers, ModifiersChanged, ModifiersEvent, Mouse, Move, Open,
  OptionHovered, PaneClicked, PaneResized, Paste, Press, Resize, Resized,
  ScrollData, Scrolled, Select, Slide, SlideRelease, Sort, Standard, Stream,
  StreamEvent, Submit, System, ThemeChanged, Timer, TimerEvent, Toggle, Touch,
  Widget, Window, WindowEvent,
}

// -- Widget events -----------------------------------------------------------

pub fn events_widget_click_construct_test() {
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: [],
        full: "save",
      )),
    )
  let assert Widget(Click(target:)) = event
  target.id |> should.equal("save")
  target.scope |> should.equal([])
}

pub fn events_widget_click_match_test() {
  let event: Event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: [],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(id: "save", ..))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_click_scope_test() {
  let event: Event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: ["form"],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save",
      scope: ["form"],
      ..,
    ))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_input_match_test() {
  let event: Event =
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "search",
        scope: [],
        full: "search",
      ),
      value: "hello",
    ))
  case event {
    Widget(Input(target: EventTarget(id: "search", ..), value:)) ->
      value |> should.equal("hello")
    _ -> should.fail()
  }
}

pub fn events_widget_submit_match_test() {
  let event: Event =
    Widget(Submit(
      target: EventTarget(
        window_id: "main",
        id: "search",
        scope: [],
        full: "search",
      ),
      value: "query",
    ))
  case event {
    Widget(Submit(target: EventTarget(id: "search", ..), value: query)) ->
      query |> should.equal("query")
    _ -> should.fail()
  }
}

pub fn events_widget_toggle_match_test() {
  let event: Event =
    Widget(Toggle(
      target: EventTarget(
        window_id: "main",
        id: "dark_mode",
        scope: [],
        full: "dark_mode",
      ),
      value: True,
    ))
  case event {
    Widget(Toggle(target: EventTarget(id: "dark_mode", ..), value: enabled)) ->
      enabled |> should.be_true()
    _ -> should.fail()
  }
}

pub fn events_widget_select_match_test() {
  let event: Event =
    Widget(Select(
      target: EventTarget(
        window_id: "main",
        id: "theme_picker",
        scope: [],
        full: "theme_picker",
      ),
      value: "nord",
    ))
  case event {
    Widget(Select(target: EventTarget(id: "theme_picker", ..), value: theme)) ->
      theme |> should.equal("nord")
    _ -> should.fail()
  }
}

pub fn events_widget_slide_match_test() {
  let event: Event =
    Widget(Slide(
      target: EventTarget(
        window_id: "main",
        id: "volume",
        scope: [],
        full: "volume",
      ),
      value: 75.0,
    ))
  case event {
    Widget(Slide(target: EventTarget(id: "volume", ..), value:)) ->
      value |> should.equal(75.0)
    _ -> should.fail()
  }
}

pub fn events_widget_slide_release_match_test() {
  let event: Event =
    Widget(SlideRelease(
      target: EventTarget(
        window_id: "main",
        id: "volume",
        scope: [],
        full: "volume",
      ),
      value: 75.0,
    ))
  case event {
    Widget(SlideRelease(target: EventTarget(id: "volume", ..), value:)) ->
      value |> should.equal(75.0)
    _ -> should.fail()
  }
}

pub fn events_widget_key_binding_match_test() {
  let event: Event =
    Widget(KeyBinding(
      target: EventTarget(
        window_id: "main",
        id: "editor",
        scope: [],
        full: "editor",
      ),
      value: "save",
    ))
  case event {
    Widget(KeyBinding(target: EventTarget(id: "editor", ..), value: "save")) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_scrolled_match_test() {
  let event: Event =
    Widget(Scrolled(
      target: EventTarget(
        window_id: "main",
        id: "log_view",
        scope: [],
        full: "log_view",
      ),
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
    ))
  case event {
    Widget(Scrolled(target: EventTarget(id: "log_view", ..), data: viewport)) -> {
      let at_bottom = viewport.relative_y >=. 0.99
      at_bottom |> should.be_false()
    }
    _ -> should.fail()
  }
}

pub fn events_widget_paste_match_test() {
  let event: Event =
    Widget(Paste(
      target: EventTarget(
        window_id: "main",
        id: "url_input",
        scope: [],
        full: "url_input",
      ),
      value: " text ",
    ))
  case event {
    Widget(Paste(target: EventTarget(id: "url_input", ..), value: text)) ->
      text |> should.equal(" text ")
    _ -> should.fail()
  }
}

pub fn events_widget_option_hovered_match_test() {
  let event: Event =
    Widget(OptionHovered(
      target: EventTarget(
        window_id: "main",
        id: "search",
        scope: [],
        full: "search",
      ),
      value: "opt1",
    ))
  case event {
    Widget(OptionHovered(target: EventTarget(id: "search", ..), value:)) ->
      value |> should.equal("opt1")
    _ -> should.fail()
  }
}

pub fn events_widget_open_close_match_test() {
  let open: Event =
    Widget(
      Open(target: EventTarget(
        window_id: "main",
        id: "country_picker",
        scope: [],
        full: "country_picker",
      )),
    )
  let close: Event =
    Widget(
      Close(target: EventTarget(
        window_id: "main",
        id: "country_picker",
        scope: [],
        full: "country_picker",
      )),
    )
  case open {
    Widget(Open(target: EventTarget(id: "country_picker", ..))) ->
      should.be_true(True)
    _ -> should.fail()
  }
  case close {
    Widget(Close(target: EventTarget(id: "country_picker", ..))) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_sort_match_test() {
  let event: Event =
    Widget(Sort(
      target: EventTarget(
        window_id: "main",
        id: "users",
        scope: [],
        full: "users",
      ),
      value: "name",
    ))
  case event {
    Widget(Sort(target: EventTarget(id: "users", ..), value: column_key)) ->
      column_key |> should.equal("name")
    _ -> should.fail()
  }
}

// -- Pointer events (widget-scoped) ------------------------------------------

pub fn events_widget_enter_match_test() {
  let event: Event =
    Widget(Enter(
      target: EventTarget(
        window_id: "main",
        id: "hover_zone",
        scope: [],
        full: "hover_zone",
      ),
      x: option.None,
      y: option.None,
    ))
  case event {
    Widget(Enter(target: EventTarget(id: "hover_zone", ..), ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_widget_move_match_test() {
  let event: Event =
    Widget(Move(
      target: EventTarget(
        window_id: "main",
        id: "canvas_area",
        scope: [],
        full: "canvas_area",
      ),
      x: 10.0,
      y: 20.0,
      pointer: Mouse,
      finger: option.None,
      modifiers: event.modifiers_none(),
      captured: False,
    ))
  case event {
    Widget(Move(target: EventTarget(id: "canvas_area", ..), x:, y:, ..)) -> {
      x |> should.equal(10.0)
      y |> should.equal(20.0)
    }
    _ -> should.fail()
  }
}

// -- Canvas events (now unified pointer) -------------------------------------

pub fn events_widget_press_match_test() {
  let event: Event =
    Widget(Press(
      target: EventTarget(
        window_id: "main",
        id: "draw_area",
        scope: [],
        full: "draw_area",
      ),
      x: 42.0,
      y: 100.0,
      button: LeftButton,
      pointer: Mouse,
      finger: option.None,
      modifiers: event.modifiers_none(),
      captured: False,
    ))
  case event {
    Widget(Press(
      target: EventTarget(id: "draw_area", ..),
      x:,
      y:,
      button: LeftButton,
      ..,
    )) -> {
      x |> should.equal(42.0)
      y |> should.equal(100.0)
    }
    _ -> should.fail()
  }
}

pub fn events_widget_move_canvas_match_test() {
  let event: Event =
    Widget(Move(
      target: EventTarget(
        window_id: "main",
        id: "draw_area",
        scope: [],
        full: "draw_area",
      ),
      x: 5.0,
      y: 10.0,
      pointer: Mouse,
      finger: option.None,
      modifiers: event.modifiers_none(),
      captured: False,
    ))
  case event {
    Widget(Move(target: EventTarget(id: "draw_area", ..), x:, y:, ..)) -> {
      x |> should.equal(5.0)
      y |> should.equal(10.0)
    }
    _ -> should.fail()
  }
}

pub fn events_canvas_element_event_match_test() {
  let event: Event =
    Widget(CustomWidget(
      kind: "canvas_element_click",
      target: EventTarget(
        window_id: "main",
        id: "chart",
        scope: [],
        full: "chart",
      ),
      value: dynamic.nil(),
      data: dynamic.nil(),
    ))
  case event {
    Widget(CustomWidget(
      kind: "canvas_element_click",
      target: EventTarget(id: "chart", ..),
      ..,
    )) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Sensor events (now WidgetResize) ----------------------------------------

pub fn events_widget_resize_match_test() {
  let event: Event =
    Widget(Resize(
      target: EventTarget(
        window_id: "main",
        id: "content_area",
        scope: [],
        full: "content_area",
      ),
      width: 800.0,
      height: 600.0,
    ))
  case event {
    Widget(Resize(target: EventTarget(id: "content_area", ..), width:, height:)) -> {
      width |> should.equal(800.0)
      height |> should.equal(600.0)
    }
    _ -> should.fail()
  }
}

// -- PaneGrid events ---------------------------------------------------------

pub fn events_pane_resized_match_test() {
  let event: Event =
    Widget(PaneResized(
      target: EventTarget(
        window_id: "main",
        id: "editor",
        scope: [],
        full: "editor",
      ),
      split: dynamic.string("split_1"),
      ratio: 0.5,
    ))
  case event {
    Widget(PaneResized(target: EventTarget(id: "editor", ..), ratio:, ..)) ->
      ratio |> should.equal(0.5)
    _ -> should.fail()
  }
}

pub fn events_pane_clicked_match_test() {
  let event: Event =
    Widget(PaneClicked(
      target: EventTarget(
        window_id: "main",
        id: "editor",
        scope: [],
        full: "editor",
      ),
      pane: dynamic.string("left"),
    ))
  case event {
    Widget(PaneClicked(target: EventTarget(id: "editor", ..), ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- Keyboard events ---------------------------------------------------------

pub fn events_key_press_cmd_s_match_test() {
  let event: Event =
    Key(KeyEvent(
      event_type: KeyPressed,
      window_id: "",
      key: "s",
      modified_key: "s",
      modifiers: Modifiers(..event.modifiers_none(), command: True),
      physical_key: option.Some("KeyS"),
      location: Standard,
      text: option.Some("s"),
      repeat: False,
      captured: False,
    ))
  case event {
    Key(KeyEvent(
      event_type: KeyPressed,
      key: "s",
      modifiers: Modifiers(command: True, ..),
      ..,
    )) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_key_press_escape_match_test() {
  let event: Event =
    Key(KeyEvent(
      event_type: KeyPressed,
      window_id: "",
      key: "Escape",
      modified_key: "Escape",
      modifiers: event.modifiers_none(),
      physical_key: option.Some("Escape"),
      location: Standard,
      text: option.None,
      repeat: False,
      captured: False,
    ))
  case event {
    Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_key_press_physical_key_match_test() {
  let event: Event =
    Key(KeyEvent(
      event_type: KeyPressed,
      window_id: "",
      key: "w",
      modified_key: "w",
      modifiers: event.modifiers_none(),
      physical_key: option.Some("KeyW"),
      location: Standard,
      text: option.Some("w"),
      repeat: False,
      captured: False,
    ))
  case event {
    Key(KeyEvent(event_type: KeyPressed, physical_key: option.Some("KeyW"), ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_key_press_text_field_match_test() {
  let event: Event =
    Key(KeyEvent(
      event_type: KeyPressed,
      window_id: "",
      key: "a",
      modified_key: "a",
      modifiers: event.modifiers_none(),
      physical_key: option.Some("KeyA"),
      location: Standard,
      text: option.Some("a"),
      repeat: False,
      captured: False,
    ))
  case event {
    Key(KeyEvent(event_type: KeyPressed, text: option.Some(text), ..)) ->
      text |> should.equal("a")
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
    Ime(ImeEvent(
      event_type: ImePreedit,
      window_id: "",
      text: option.Some("compose"),
      cursor: option.Some(#(0, 7)),
      captured: False,
    ))
  let assert Ime(ImeEvent(text: option.Some(text), ..)) = event
  text |> should.equal("compose")
}

pub fn events_ime_commit_match_test() {
  let event =
    Ime(ImeEvent(
      event_type: ImeCommit,
      window_id: "",
      text: option.Some("final"),
      cursor: option.None,
      captured: False,
    ))
  let assert Ime(ImeEvent(text: option.Some(text), ..)) = event
  text |> should.equal("final")
}

// -- Pointer subscription events (global) ------------------------------------

pub fn events_pointer_moved_match_test() {
  let event: Event =
    Widget(Move(
      target: EventTarget(window_id: "", id: "", scope: [], full: ""),
      x: 100.0,
      y: 200.0,
      pointer: Mouse,
      finger: option.None,
      modifiers: event.modifiers_none(),
      captured: False,
    ))
  let assert Widget(Move(x:, y:, ..)) = event
  x |> should.equal(100.0)
  y |> should.equal(200.0)
}

pub fn events_pointer_button_pressed_match_test() {
  let event: Event =
    Widget(Press(
      target: EventTarget(window_id: "", id: "", scope: [], full: ""),
      x: 0.0,
      y: 0.0,
      button: LeftButton,
      pointer: Mouse,
      finger: option.None,
      modifiers: event.modifiers_none(),
      captured: False,
    ))
  case event {
    Widget(Press(button: LeftButton, ..)) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Touch events (now unified pointer with Touch type) ----------------------

pub fn events_touch_pressed_match_test() {
  let event: Event =
    Widget(Press(
      target: EventTarget(window_id: "", id: "", scope: [], full: ""),
      x: 50.0,
      y: 75.0,
      button: LeftButton,
      pointer: Touch,
      finger: option.Some(0),
      modifiers: event.modifiers_none(),
      captured: False,
    ))
  case event {
    Widget(Press(x:, y:, pointer: Touch, ..)) -> {
      x |> should.equal(50.0)
      y |> should.equal(75.0)
    }
    _ -> should.fail()
  }
}

// -- Modifier state events ---------------------------------------------------

pub fn events_modifiers_changed_match_test() {
  let event =
    ModifiersChanged(ModifiersEvent(
      window_id: "",
      modifiers: Modifiers(
        shift: True,
        ctrl: False,
        alt: False,
        logo: False,
        command: False,
      ),
      captured: False,
    ))
  let assert ModifiersChanged(ModifiersEvent(modifiers:, ..)) = event
  modifiers.shift |> should.be_true()
}

// -- Window events -----------------------------------------------------------

pub fn events_window_close_requested_match_test() {
  let event: Event =
    Window(WindowEvent(
      event_type: CloseRequested,
      window_id: "main",
      width: option.None,
      height: option.None,
      x: option.None,
      y: option.None,
      scale_factor: option.None,
      path: option.None,
    ))
  case event {
    Window(WindowEvent(event_type: CloseRequested, window_id: "main", ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_window_resized_match_test() {
  let event: Event =
    Window(WindowEvent(
      event_type: Resized,
      window_id: "main",
      width: option.Some(800.0),
      height: option.Some(600.0),
      x: option.None,
      y: option.None,
      scale_factor: option.None,
      path: option.None,
    ))
  case event {
    Window(WindowEvent(event_type: Resized, window_id: "main", ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_window_file_drag_drop_match_test() {
  let hovered: Event =
    Window(WindowEvent(
      event_type: FileHovered,
      window_id: "main",
      width: option.None,
      height: option.None,
      x: option.None,
      y: option.None,
      scale_factor: option.None,
      path: option.Some("/foo.txt"),
    ))
  let dropped: Event =
    Window(WindowEvent(
      event_type: FileDropped,
      window_id: "main",
      width: option.None,
      height: option.None,
      x: option.None,
      y: option.None,
      scale_factor: option.None,
      path: option.Some("/foo.txt"),
    ))
  let left: Event =
    Window(WindowEvent(
      event_type: FilesHoveredLeft,
      window_id: "main",
      width: option.None,
      height: option.None,
      x: option.None,
      y: option.None,
      scale_factor: option.None,
      path: option.None,
    ))
  case hovered {
    Window(WindowEvent(
      event_type: FileHovered,
      window_id: "main",
      path: option.Some(path),
      ..,
    )) -> path |> should.equal("/foo.txt")
    _ -> should.fail()
  }
  case dropped {
    Window(WindowEvent(
      event_type: FileDropped,
      window_id: "main",
      path: option.Some(path),
      ..,
    )) -> path |> should.equal("/foo.txt")
    _ -> should.fail()
  }
  case left {
    Window(WindowEvent(event_type: FilesHoveredLeft, window_id: "main", ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- System events -----------------------------------------------------------

pub fn events_animation_frame_construct_test() {
  let event = System(AnimationFrame(timestamp: 12_345))
  let assert System(AnimationFrame(timestamp:)) = event
  timestamp |> should.equal(12_345)
}

pub fn events_theme_changed_construct_test() {
  let event = System(ThemeChanged(theme: "dark"))
  let assert System(ThemeChanged(theme:)) = event
  theme |> should.equal("dark")
}

// -- Timer events ------------------------------------------------------------

pub fn events_timer_tick_match_test() {
  let event: Event = Timer(TimerEvent(tag: "tick", timestamp: 1_000_000))
  case event {
    Timer(TimerEvent(tag: "tick", timestamp: ts)) ->
      ts |> should.equal(1_000_000)
    _ -> should.fail()
  }
}

// -- Command result events ---------------------------------------------------

pub fn events_async_result_ok_match_test() {
  let event: Event =
    Async(AsyncEvent(tag: "data_loaded", result: Ok(dynamic.string("hello"))))
  case event {
    Async(AsyncEvent(tag: "data_loaded", result: Ok(_))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_async_result_error_match_test() {
  let event: Event =
    Async(AsyncEvent(tag: "data_loaded", result: Error(dynamic.string("fail"))))
  case event {
    Async(AsyncEvent(tag: "data_loaded", result: Error(_))) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_stream_value_match_test() {
  let event: Event =
    Stream(StreamEvent(tag: "file_import", value: dynamic.int(42)))
  case event {
    Stream(StreamEvent(tag: "file_import", ..)) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Effect result events ----------------------------------------------------

pub fn events_effect_response_ok_match_test() {
  let event: Event =
    Effect(EffectEvent(
      tag: "import",
      result: FileOpened(path: "/tmp/notes.txt"),
    ))
  case event {
    Effect(EffectEvent(tag: "import", result: FileOpened(path: _p))) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_effect_response_cancelled_match_test() {
  let event: Event = Effect(EffectEvent(tag: "import", result: EffectCancelled))
  case event {
    Effect(EffectEvent(tag: "import", result: EffectCancelled)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_effect_response_error_match_test() {
  let event: Event =
    Effect(EffectEvent(tag: "import", result: EffectError(message: "err")))
  case event {
    Effect(EffectEvent(result: EffectError(message: _), ..)) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- Pattern matching tips ---------------------------------------------------

pub fn events_pattern_prefix_match_test() {
  let event: Event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "nav:settings",
        scope: [],
        full: "nav:settings",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(id: "nav:" <> section, ..))) ->
      section |> should.equal("settings")
    _ -> should.fail()
  }
}

pub fn events_pattern_toggle_prefix_match_test() {
  let event: Event =
    Widget(Toggle(
      target: EventTarget(
        window_id: "main",
        id: "setting:theme",
        scope: [],
        full: "setting:theme",
      ),
      value: True,
    ))
  case event {
    Widget(Toggle(target: EventTarget(id: "setting:" <> key, ..), value:)) -> {
      key |> should.equal("theme")
      value |> should.be_true()
    }
    _ -> should.fail()
  }
}

// -- Scope matching ----------------------------------------------------------

pub fn events_scope_sidebar_match_test() {
  let event: Event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: ["sidebar"],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save",
      scope: ["sidebar", ..],
      ..,
    ))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_scope_main_match_test() {
  let event: Event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: ["main"],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save",
      scope: ["main", ..],
      ..,
    ))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn events_catch_all_test() {
  let event: Event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "unknown",
        scope: [],
        full: "unknown",
      )),
    )
  let result = case event {
    Widget(Click(target: EventTarget(id: "save", ..))) -> "save"
    _ -> "fallback"
  }
  result |> should.equal("fallback")
}
