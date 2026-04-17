import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/option
import gleeunit/should
import plushie/command
import plushie/event.{type Event, System, SystemTheme, Timer, TimerEvent}
import plushie/subscription

// -- command.none ------------------------------------------------------------

pub fn commands_none_test() {
  command.none() |> should.equal(command.None)
}

// -- command.async -----------------------------------------------------------

pub fn commands_async_construct_test() {
  let work = fn() { dynamic.string("result") }
  let cmd = command.async(work, "data_fetched")
  case cmd {
    command.Async(tag: "data_fetched", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- command.stream ----------------------------------------------------------

pub fn commands_stream_construct_test() {
  let work = fn(emit) {
    emit(dynamic.int(1))
    dynamic.string("done")
  }
  let cmd = command.stream(work, "file_import")
  case cmd {
    command.Stream(tag: "file_import", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- command.cancel ----------------------------------------------------------

pub fn commands_cancel_construct_test() {
  command.cancel("file_import")
  |> should.equal(command.Cancel(tag: "file_import"))
}

// -- command.done ------------------------------------------------------------

pub fn commands_done_construct_test() {
  let cmd = command.done(dynamic.nil(), fn(_) { "msg" })
  case cmd {
    command.Done(..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- command.exit ------------------------------------------------------------

pub fn commands_exit_construct_test() {
  command.exit() |> should.equal(command.Exit)
}

// -- Focus commands ----------------------------------------------------------

pub fn commands_focus_construct_test() {
  command.focus("todo_input")
  |> should.equal(command.Renderer(command.Focus(widget_id: "todo_input")))
}

pub fn commands_focus_next_construct_test() {
  command.focus_next() |> should.equal(command.Renderer(command.FocusNext))
}

pub fn commands_focus_previous_construct_test() {
  command.focus_previous()
  |> should.equal(command.Renderer(command.FocusPrevious))
}

// -- Text operations ---------------------------------------------------------

pub fn commands_select_all_construct_test() {
  command.select_all("editor")
  |> should.equal(command.Renderer(command.SelectAll(widget_id: "editor")))
}

pub fn commands_move_cursor_to_front_construct_test() {
  let cmd = command.Renderer(command.MoveCursorToFront(widget_id: "editor"))
  case cmd {
    command.Renderer(command.MoveCursorToFront(widget_id:)) ->
      widget_id |> should.equal("editor")
    _ -> should.fail()
  }
}

pub fn commands_move_cursor_to_end_construct_test() {
  let cmd = command.Renderer(command.MoveCursorToEnd(widget_id: "editor"))
  case cmd {
    command.Renderer(command.MoveCursorToEnd(widget_id:)) ->
      widget_id |> should.equal("editor")
    _ -> should.fail()
  }
}

pub fn commands_move_cursor_to_construct_test() {
  let cmd =
    command.Renderer(command.MoveCursorTo(widget_id: "editor", position: 5))
  case cmd {
    command.Renderer(command.MoveCursorTo(widget_id:, position:)) -> {
      widget_id |> should.equal("editor")
      position |> should.equal(5)
    }
    _ -> should.fail()
  }
}

pub fn commands_select_range_construct_test() {
  let cmd =
    command.Renderer(command.SelectRange(
      widget_id: "editor",
      start_pos: 5,
      end_pos: 10,
    ))
  case cmd {
    command.Renderer(command.SelectRange(widget_id:, start_pos:, end_pos:)) -> {
      widget_id |> should.equal("editor")
      start_pos |> should.equal(5)
      end_pos |> should.equal(10)
    }
    _ -> should.fail()
  }
}

// -- Scroll operations -------------------------------------------------------

pub fn commands_snap_to_end_construct_test() {
  let cmd = command.Renderer(command.SnapToEnd(widget_id: "chat_log"))
  case cmd {
    command.Renderer(command.SnapToEnd(widget_id:)) ->
      widget_id |> should.equal("chat_log")
    _ -> should.fail()
  }
}

pub fn commands_snap_to_construct_test() {
  let cmd =
    command.Renderer(command.SnapTo(widget_id: "scroller", x: 0.0, y: 100.0))
  case cmd {
    command.Renderer(command.SnapTo(widget_id:, x:, y:)) -> {
      widget_id |> should.equal("scroller")
      x |> should.equal(0.0)
      y |> should.equal(100.0)
    }
    _ -> should.fail()
  }
}

pub fn commands_scroll_by_construct_test() {
  let cmd =
    command.Renderer(command.ScrollBy(widget_id: "scroller", x: 0.0, y: 50.0))
  case cmd {
    command.Renderer(command.ScrollBy(widget_id:, ..)) ->
      widget_id |> should.equal("scroller")
    _ -> should.fail()
  }
}

// -- Window management -------------------------------------------------------

pub fn commands_close_window_construct_test() {
  command.close_window("main")
  |> should.equal(
    command.Renderer(command.Window(command.CloseWindow(window_id: "main"))),
  )
}

pub fn commands_resize_window_construct_test() {
  command.resize_window("main", 800.0, 600.0)
  |> should.equal(
    command.Renderer(
      command.Window(command.ResizeWindow(
        window_id: "main",
        width: 800.0,
        height: 600.0,
      )),
    ),
  )
}

pub fn commands_move_window_construct_test() {
  command.move_window("main", 100.0, 200.0)
  |> should.equal(
    command.Renderer(
      command.Window(command.MoveWindow(window_id: "main", x: 100.0, y: 200.0)),
    ),
  )
}

pub fn commands_maximize_window_construct_test() {
  command.maximize_window("main")
  |> should.equal(
    command.Renderer(
      command.Window(command.MaximizeWindow(window_id: "main", maximized: True)),
    ),
  )
}

pub fn commands_minimize_window_construct_test() {
  command.minimize_window("main")
  |> should.equal(
    command.Renderer(
      command.Window(command.MinimizeWindow(window_id: "main", minimized: True)),
    ),
  )
}

pub fn commands_toggle_maximize_construct_test() {
  command.toggle_maximize("main")
  |> should.equal(
    command.Renderer(command.Window(command.ToggleMaximize(window_id: "main"))),
  )
}

pub fn commands_toggle_decorations_construct_test() {
  command.toggle_decorations("main")
  |> should.equal(
    command.Renderer(
      command.Window(command.ToggleDecorations(window_id: "main")),
    ),
  )
}

pub fn commands_focus_window_construct_test() {
  command.focus_window("main")
  |> should.equal(
    command.Renderer(command.Window(command.FocusWindow(window_id: "main"))),
  )
}

pub fn commands_screenshot_construct_test() {
  command.screenshot("main", "shot_1")
  |> should.equal(
    command.Renderer(
      command.Window(command.Screenshot(window_id: "main", tag: "shot_1")),
    ),
  )
}

pub fn commands_set_window_mode_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.SetWindowMode(
        window_id: "main",
        mode: "fullscreen",
      )),
    )
  case cmd {
    command.Renderer(command.Window(command.SetWindowMode(window_id:, mode:))) -> {
      window_id |> should.equal("main")
      mode |> should.equal("fullscreen")
    }
    _ -> should.fail()
  }
}

pub fn commands_set_window_level_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.SetWindowLevel(
        window_id: "main",
        level: "always_on_top",
      )),
    )
  case cmd {
    command.Renderer(command.Window(command.SetWindowLevel(window_id:, level:))) -> {
      window_id |> should.equal("main")
      level |> should.equal("always_on_top")
    }
    _ -> should.fail()
  }
}

pub fn commands_drag_window_construct_test() {
  let cmd =
    command.Renderer(command.Window(command.DragWindow(window_id: "main")))
  case cmd {
    command.Renderer(command.Window(command.DragWindow(window_id:))) ->
      window_id |> should.equal("main")
    _ -> should.fail()
  }
}

pub fn commands_set_resizable_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.SetResizable(window_id: "main", resizable: True)),
    )
  case cmd {
    command.Renderer(command.Window(command.SetResizable(resizable:, ..))) ->
      resizable |> should.be_true()
    _ -> should.fail()
  }
}

pub fn commands_set_min_size_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.SetMinSize(
        window_id: "main",
        width: 400.0,
        height: 300.0,
      )),
    )
  case cmd {
    command.Renderer(command.Window(command.SetMinSize(width:, height:, ..))) -> {
      width |> should.equal(400.0)
      height |> should.equal(300.0)
    }
    _ -> should.fail()
  }
}

pub fn commands_set_max_size_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.SetMaxSize(
        window_id: "main",
        width: 1920.0,
        height: 1080.0,
      )),
    )
  case cmd {
    command.Renderer(command.Window(command.SetMaxSize(width:, ..))) ->
      width |> should.equal(1920.0)
    _ -> should.fail()
  }
}

pub fn commands_enable_mouse_passthrough_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.EnableMousePassthrough(window_id: "main")),
    )
  case cmd {
    command.Renderer(command.Window(command.EnableMousePassthrough(window_id:))) ->
      window_id |> should.equal("main")
    _ -> should.fail()
  }
}

pub fn commands_allow_automatic_tabbing_construct_test() {
  let cmd =
    command.Renderer(
      command.System(command.AllowAutomaticTabbing(enabled: True)),
    )
  case cmd {
    command.Renderer(command.System(command.AllowAutomaticTabbing(enabled:))) ->
      enabled |> should.be_true()
    _ -> should.fail()
  }
}

pub fn commands_request_attention_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.RequestUserAttention(
        window_id: "main",
        urgency: option.Some("critical"),
      )),
    )
  case cmd {
    command.Renderer(command.Window(command.RequestUserAttention(window_id:, ..))) ->
      window_id |> should.equal("main")
    _ -> should.fail()
  }
}

pub fn commands_set_resize_increments_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.SetResizeIncrements(
        window_id: "main",
        width: option.Some(10.0),
        height: option.Some(10.0),
      )),
    )
  case cmd {
    command.Renderer(command.Window(command.SetResizeIncrements(window_id:, ..))) ->
      window_id |> should.equal("main")
    _ -> should.fail()
  }
}

// -- Window queries ----------------------------------------------------------

pub fn commands_window_size_construct_test() {
  let cmd =
    command.Renderer(
      command.Window(command.GetWindowSize(window_id: "main", tag: "got_size")),
    )
  case cmd {
    command.Renderer(command.Window(command.GetWindowSize(window_id:, tag:))) -> {
      window_id |> should.equal("main")
      tag |> should.equal("got_size")
    }
    _ -> should.fail()
  }
}

pub fn commands_system_theme_construct_test() {
  let cmd =
    command.Renderer(
      command.System(command.GetSystemTheme(tag: "theme_detected")),
    )
  case cmd {
    command.Renderer(command.System(command.GetSystemTheme(tag:))) ->
      tag |> should.equal("theme_detected")
    _ -> should.fail()
  }
}

pub fn commands_system_theme_event_match_test() {
  let event: Event = System(SystemTheme(tag: "theme_detected", theme: "dark"))
  case event {
    System(SystemTheme(tag: "theme_detected", theme: mode)) ->
      mode |> should.equal("dark")
    _ -> should.fail()
  }
}

// -- Image operations --------------------------------------------------------

pub fn commands_create_image_construct_test() {
  command.create_image("preview", <<0, 1, 2>>)
  |> should.equal(
    command.Renderer(
      command.Image(command.CreateImage(handle: "preview", data: <<0, 1, 2>>)),
    ),
  )
}

pub fn commands_create_image_rgba_construct_test() {
  let cmd =
    command.Renderer(
      command.Image(
        command.CreateImageRgba(handle: "img", width: 2, height: 2, pixels: <<
          0:size(128),
        >>),
      ),
    )
  case cmd {
    command.Renderer(command.Image(command.CreateImageRgba(handle:, width:, ..))) -> {
      handle |> should.equal("img")
      width |> should.equal(2)
    }
    _ -> should.fail()
  }
}

pub fn commands_delete_image_construct_test() {
  command.delete_image("preview")
  |> should.equal(
    command.Renderer(command.Image(command.DeleteImage(handle: "preview"))),
  )
}

pub fn commands_clear_images_construct_test() {
  command.clear_images()
  |> should.equal(command.Renderer(command.Image(command.ClearImages)))
}

pub fn commands_list_images_construct_test() {
  let cmd =
    command.Renderer(command.Image(command.ListImages(tag: "list_result")))
  case cmd {
    command.Renderer(command.Image(command.ListImages(tag:))) ->
      tag |> should.equal("list_result")
    _ -> should.fail()
  }
}

// -- PaneGrid operations -----------------------------------------------------

pub fn commands_pane_split_construct_test() {
  let cmd =
    command.Renderer(command.PaneSplit(
      pane_grid_id: "pane_grid",
      pane_id: "editor",
      axis: "horizontal",
      new_pane_id: "new_editor",
    ))
  case cmd {
    command.Renderer(command.PaneSplit(pane_grid_id:, axis:, ..)) -> {
      pane_grid_id |> should.equal("pane_grid")
      axis |> should.equal("horizontal")
    }
    _ -> should.fail()
  }
}

pub fn commands_pane_close_construct_test() {
  let cmd =
    command.Renderer(command.PaneClose(pane_grid_id: "grid", pane_id: "p1"))
  case cmd {
    command.Renderer(command.PaneClose(pane_grid_id:, ..)) ->
      pane_grid_id |> should.equal("grid")
    _ -> should.fail()
  }
}

pub fn commands_pane_swap_construct_test() {
  let cmd =
    command.Renderer(command.PaneSwap(
      pane_grid_id: "grid",
      pane_a: "a",
      pane_b: "b",
    ))
  case cmd {
    command.Renderer(command.PaneSwap(pane_grid_id:, ..)) ->
      pane_grid_id |> should.equal("grid")
    _ -> should.fail()
  }
}

pub fn commands_pane_maximize_construct_test() {
  let cmd =
    command.Renderer(command.PaneMaximize(pane_grid_id: "grid", pane_id: "p1"))
  case cmd {
    command.Renderer(command.PaneMaximize(pane_grid_id:, ..)) ->
      pane_grid_id |> should.equal("grid")
    _ -> should.fail()
  }
}

pub fn commands_pane_restore_construct_test() {
  command.Renderer(command.PaneRestore(pane_grid_id: "grid"))
  |> should.equal(command.Renderer(command.PaneRestore(pane_grid_id: "grid")))
}

// -- Timer -------------------------------------------------------------------

pub fn commands_send_after_construct_test() {
  let cmd = command.send_after(3000, "ClearMessage")
  case cmd {
    command.SendAfter(delay_ms: 3000, msg: "ClearMessage") ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- Batch -------------------------------------------------------------------

pub fn commands_batch_construct_test() {
  let cmds = [
    command.focus("name_input"),
    command.send_after(5000, "AutoSave"),
  ]
  let batch = command.batch(cmds)
  batch |> should.equal(command.Batch(commands: cmds))
}

// -- Widget commands ---------------------------------------------------------

pub fn commands_extension_command_construct_test() {
  let cmd =
    command.Renderer(command.NativeCommand(
      node_id: "term-1",
      op: "write",
      payload: dict.new(),
    ))
  case cmd {
    command.Renderer(command.NativeCommand(node_id:, op:, ..)) -> {
      node_id |> should.equal("term-1")
      op |> should.equal("write")
    }
    _ -> should.fail()
  }
}

pub fn commands_extension_commands_construct_test() {
  let cmds = [
    #("term-1", "write", dict.new()),
    #("log-1", "append", dict.new()),
  ]
  let cmd = command.Renderer(command.NativeCommands(commands: cmds))
  case cmd {
    command.Renderer(command.NativeCommands(commands:)) ->
      commands |> list.length() |> should.equal(2)
    _ -> should.fail()
  }
}

// -- Subscriptions -----------------------------------------------------------

pub fn commands_subscription_every_construct_test() {
  subscription.every(1000, "tick")
  |> should.equal(subscription.Every(interval_ms: 1000, tag: "tick"))
}

pub fn commands_subscription_on_key_press_construct_test() {
  subscription.on_key_press()
  |> should.equal(subscription.Renderer(
    kind: subscription.KeyPress,
    max_rate: option.None,
    window_id: option.None,
  ))
}

pub fn commands_subscription_set_max_rate_test() {
  let sub =
    subscription.on_pointer_move()
    |> subscription.set_max_rate(30)
  subscription.get_max_rate(sub) |> should.equal(option.Some(30))
}

pub fn commands_subscription_set_max_rate_zero_test() {
  let sub =
    subscription.on_pointer_move()
    |> subscription.set_max_rate(0)
  subscription.get_max_rate(sub) |> should.equal(option.Some(0))
}

pub fn commands_subscription_on_animation_frame_test() {
  let sub =
    subscription.on_animation_frame()
    |> subscription.set_max_rate(60)
  subscription.get_max_rate(sub) |> should.equal(option.Some(60))
}

pub fn commands_subscription_every_ignores_max_rate_test() {
  let sub =
    subscription.every(1000, "tick")
    |> subscription.set_max_rate(30)
  subscription.get_max_rate(sub) |> should.equal(option.None)
}

pub fn commands_subscription_wire_tag_test() {
  subscription.wire_tag(subscription.on_window_close())
  |> should.equal("on_window_close")
}

pub fn commands_subscription_window_scoped_wire_tag_test() {
  subscription.on_key_press()
  |> subscription.set_window("editor")
  |> subscription.wire_tag()
  |> should.equal("on_key_press:editor")
}

pub fn commands_subscription_wire_kind_test() {
  subscription.wire_kind(subscription.on_pointer_button())
  |> should.equal("on_pointer_button")
  subscription.wire_kind(subscription.on_pointer_scroll())
  |> should.equal("on_pointer_scroll")
  subscription.wire_kind(subscription.on_pointer_touch())
  |> should.equal("on_pointer_touch")
  subscription.wire_kind(subscription.on_ime())
  |> should.equal("on_ime")
  subscription.wire_kind(subscription.on_theme_change())
  |> should.equal("on_theme_change")
  subscription.wire_kind(subscription.on_file_drop())
  |> should.equal("on_file_drop")
  subscription.wire_kind(subscription.on_event())
  |> should.equal("on_event")
}

// -- Subscription lifecycle --------------------------------------------------

pub fn commands_subscription_lifecycle_on_test() {
  let subs = [subscription.every(5000, "poll")]
  list.length(subs) |> should.equal(1)
}

pub fn commands_subscription_lifecycle_off_test() {
  let subs: List(subscription.Subscription) = []
  list.length(subs) |> should.equal(0)
}

// -- Timer tick event from subscription --------------------------------------

pub fn commands_timer_tick_event_test() {
  let event: Event = Timer(TimerEvent(tag: "poll", timestamp: 100))
  case event {
    Timer(TimerEvent(tag: "poll", ..)) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Update testability pattern ----------------------------------------------

pub fn commands_update_testability_test() {
  let cmd = command.async(fn() { dynamic.string("data") }, "fetch")
  case cmd {
    command.Async(tag: "fetch", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Chaining pattern (multi-step async) -------------------------------------

pub fn commands_chaining_pattern_test() {
  let step1 = command.async(fn() { dynamic.nil() }, "validated")
  let step2 = command.async(fn() { dynamic.nil() }, "built")
  let step3 = command.async(fn() { dynamic.nil() }, "deployed")
  case step1 {
    command.Async(tag: "validated", ..) -> should.be_true(True)
    _ -> should.fail()
  }
  case step2 {
    command.Async(tag: "built", ..) -> should.be_true(True)
    _ -> should.fail()
  }
  case step3 {
    command.Async(tag: "deployed", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}
