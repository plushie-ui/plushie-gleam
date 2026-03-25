import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/option
import gleeunit/should
import plushie/command
import plushie/event.{type Event, SystemTheme, TimerTick}
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
  |> should.equal(command.Focus(widget_id: "todo_input"))
}

pub fn commands_focus_next_construct_test() {
  command.focus_next() |> should.equal(command.FocusNext)
}

pub fn commands_focus_previous_construct_test() {
  command.focus_previous() |> should.equal(command.FocusPrevious)
}

// -- Text operations ---------------------------------------------------------

pub fn commands_select_all_construct_test() {
  command.select_all("editor")
  |> should.equal(command.SelectAll(widget_id: "editor"))
}

pub fn commands_move_cursor_to_front_construct_test() {
  let cmd = command.MoveCursorToFront(widget_id: "editor")
  cmd.widget_id |> should.equal("editor")
}

pub fn commands_move_cursor_to_end_construct_test() {
  let cmd = command.MoveCursorToEnd(widget_id: "editor")
  cmd.widget_id |> should.equal("editor")
}

pub fn commands_move_cursor_to_construct_test() {
  let cmd = command.MoveCursorTo(widget_id: "editor", position: 5)
  cmd.widget_id |> should.equal("editor")
  cmd.position |> should.equal(5)
}

pub fn commands_select_range_construct_test() {
  let cmd = command.SelectRange(widget_id: "editor", start: 5, end: 10)
  cmd.widget_id |> should.equal("editor")
  cmd.start |> should.equal(5)
  cmd.end |> should.equal(10)
}

// -- Scroll operations -------------------------------------------------------

pub fn commands_snap_to_end_construct_test() {
  let cmd = command.SnapToEnd(widget_id: "chat_log")
  cmd.widget_id |> should.equal("chat_log")
}

pub fn commands_snap_to_construct_test() {
  let cmd = command.SnapTo(widget_id: "scroller", x: 0.0, y: 100.0)
  cmd.widget_id |> should.equal("scroller")
  cmd.x |> should.equal(0.0)
  cmd.y |> should.equal(100.0)
}

pub fn commands_scroll_by_construct_test() {
  let cmd = command.ScrollBy(widget_id: "scroller", x: 0.0, y: 50.0)
  cmd.widget_id |> should.equal("scroller")
}

// -- Window management -------------------------------------------------------

pub fn commands_close_window_construct_test() {
  command.close_window("main")
  |> should.equal(command.CloseWindow(window_id: "main"))
}

pub fn commands_resize_window_construct_test() {
  command.resize_window("main", 800.0, 600.0)
  |> should.equal(command.ResizeWindow(
    window_id: "main",
    width: 800.0,
    height: 600.0,
  ))
}

pub fn commands_move_window_construct_test() {
  command.move_window("main", 100.0, 200.0)
  |> should.equal(command.MoveWindow(window_id: "main", x: 100.0, y: 200.0))
}

pub fn commands_maximize_window_construct_test() {
  command.maximize_window("main")
  |> should.equal(command.MaximizeWindow(window_id: "main", maximized: True))
}

pub fn commands_minimize_window_construct_test() {
  command.minimize_window("main")
  |> should.equal(command.MinimizeWindow(window_id: "main", minimized: True))
}

pub fn commands_toggle_maximize_construct_test() {
  command.toggle_maximize("main")
  |> should.equal(command.ToggleMaximize(window_id: "main"))
}

pub fn commands_toggle_decorations_construct_test() {
  command.toggle_decorations("main")
  |> should.equal(command.ToggleDecorations(window_id: "main"))
}

pub fn commands_gain_focus_construct_test() {
  command.gain_focus("main")
  |> should.equal(command.GainFocus(window_id: "main"))
}

pub fn commands_screenshot_construct_test() {
  command.screenshot("main", "shot_1")
  |> should.equal(command.Screenshot(window_id: "main", tag: "shot_1"))
}

pub fn commands_set_window_mode_construct_test() {
  let cmd = command.SetWindowMode(window_id: "main", mode: "fullscreen")
  cmd.window_id |> should.equal("main")
  cmd.mode |> should.equal("fullscreen")
}

pub fn commands_set_window_level_construct_test() {
  let cmd = command.SetWindowLevel(window_id: "main", level: "always_on_top")
  cmd.window_id |> should.equal("main")
  cmd.level |> should.equal("always_on_top")
}

pub fn commands_drag_window_construct_test() {
  let cmd = command.DragWindow(window_id: "main")
  cmd.window_id |> should.equal("main")
}

pub fn commands_set_resizable_construct_test() {
  let cmd = command.SetResizable(window_id: "main", resizable: True)
  cmd.resizable |> should.be_true()
}

pub fn commands_set_min_size_construct_test() {
  let cmd = command.SetMinSize(window_id: "main", width: 400.0, height: 300.0)
  cmd.width |> should.equal(400.0)
  cmd.height |> should.equal(300.0)
}

pub fn commands_set_max_size_construct_test() {
  let cmd = command.SetMaxSize(window_id: "main", width: 1920.0, height: 1080.0)
  cmd.width |> should.equal(1920.0)
}

pub fn commands_enable_mouse_passthrough_construct_test() {
  let cmd = command.EnableMousePassthrough(window_id: "main")
  cmd.window_id |> should.equal("main")
}

pub fn commands_allow_automatic_tabbing_construct_test() {
  let cmd = command.AllowAutomaticTabbing(enabled: True)
  cmd.enabled |> should.be_true()
}

pub fn commands_request_user_attention_construct_test() {
  let cmd =
    command.RequestUserAttention(
      window_id: "main",
      urgency: option.Some("critical"),
    )
  cmd.window_id |> should.equal("main")
}

pub fn commands_set_resize_increments_construct_test() {
  let cmd =
    command.SetResizeIncrements(
      window_id: "main",
      width: option.Some(10.0),
      height: option.Some(10.0),
    )
  cmd.window_id |> should.equal("main")
}

// -- Window queries ----------------------------------------------------------

pub fn commands_get_window_size_construct_test() {
  let cmd = command.GetWindowSize(window_id: "main", tag: "got_size")
  cmd.window_id |> should.equal("main")
  cmd.tag |> should.equal("got_size")
}

pub fn commands_get_system_theme_construct_test() {
  let cmd = command.GetSystemTheme(tag: "theme_detected")
  cmd.tag |> should.equal("theme_detected")
}

pub fn commands_system_theme_event_match_test() {
  let event: Event = SystemTheme(tag: "theme_detected", theme: "dark")
  case event {
    SystemTheme(tag: "theme_detected", theme: mode) ->
      mode |> should.equal("dark")
    _ -> should.fail()
  }
}

// -- Image operations --------------------------------------------------------

pub fn commands_create_image_construct_test() {
  command.create_image("preview", <<0, 1, 2>>)
  |> should.equal(command.CreateImage(handle: "preview", data: <<0, 1, 2>>))
}

pub fn commands_create_image_rgba_construct_test() {
  let cmd =
    command.CreateImageRgba(handle: "img", width: 2, height: 2, pixels: <<
      0:size(128),
    >>)
  cmd.handle |> should.equal("img")
  cmd.width |> should.equal(2)
}

pub fn commands_delete_image_construct_test() {
  command.delete_image("preview")
  |> should.equal(command.DeleteImage(handle: "preview"))
}

pub fn commands_clear_images_construct_test() {
  command.clear_images() |> should.equal(command.ClearImages)
}

pub fn commands_list_images_construct_test() {
  let cmd = command.ListImages(tag: "list_result")
  cmd.tag |> should.equal("list_result")
}

// -- PaneGrid operations -----------------------------------------------------

pub fn commands_pane_split_construct_test() {
  let cmd =
    command.PaneSplit(
      pane_grid_id: "pane_grid",
      pane_id: "editor",
      axis: "horizontal",
      new_pane_id: "new_editor",
    )
  cmd.pane_grid_id |> should.equal("pane_grid")
  cmd.axis |> should.equal("horizontal")
}

pub fn commands_pane_close_construct_test() {
  let cmd = command.PaneClose(pane_grid_id: "grid", pane_id: "p1")
  cmd.pane_grid_id |> should.equal("grid")
}

pub fn commands_pane_swap_construct_test() {
  let cmd = command.PaneSwap(pane_grid_id: "grid", pane_a: "a", pane_b: "b")
  cmd.pane_grid_id |> should.equal("grid")
}

pub fn commands_pane_maximize_construct_test() {
  let cmd = command.PaneMaximize(pane_grid_id: "grid", pane_id: "p1")
  cmd.pane_grid_id |> should.equal("grid")
}

pub fn commands_pane_restore_construct_test() {
  command.PaneRestore(pane_grid_id: "grid")
  |> should.equal(command.PaneRestore(pane_grid_id: "grid"))
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

// -- Extension commands ------------------------------------------------------

pub fn commands_extension_command_construct_test() {
  let cmd =
    command.ExtensionCommand(
      node_id: "term-1",
      op: "write",
      payload: dict.new(),
    )
  cmd.node_id |> should.equal("term-1")
  cmd.op |> should.equal("write")
}

pub fn commands_extension_commands_construct_test() {
  let cmds = [
    #("term-1", "write", dict.new()),
    #("log-1", "append", dict.new()),
  ]
  let cmd = command.ExtensionCommands(commands: cmds)
  cmd.commands |> list.length() |> should.equal(2)
}

// -- Subscriptions -----------------------------------------------------------

pub fn commands_subscription_every_construct_test() {
  subscription.every(1000, "tick")
  |> should.equal(subscription.Every(interval_ms: 1000, tag: "tick"))
}

pub fn commands_subscription_on_key_press_construct_test() {
  subscription.on_key_press("key_event")
  |> should.equal(subscription.OnKeyPress(
    tag: "key_event",
    max_rate: option.None,
  ))
}

pub fn commands_subscription_set_max_rate_test() {
  let sub =
    subscription.on_mouse_move("mouse")
    |> subscription.set_max_rate(30)
  subscription.get_max_rate(sub) |> should.equal(option.Some(30))
}

pub fn commands_subscription_set_max_rate_zero_test() {
  let sub =
    subscription.on_mouse_move("mouse")
    |> subscription.set_max_rate(0)
  subscription.get_max_rate(sub) |> should.equal(option.Some(0))
}

pub fn commands_subscription_on_animation_frame_test() {
  let sub =
    subscription.on_animation_frame("frame")
    |> subscription.set_max_rate(60)
  subscription.get_max_rate(sub) |> should.equal(option.Some(60))
}

pub fn commands_subscription_every_ignores_max_rate_test() {
  let sub =
    subscription.every(1000, "tick")
    |> subscription.set_max_rate(30)
  subscription.get_max_rate(sub) |> should.equal(option.None)
}

pub fn commands_subscription_on_window_close_test() {
  let sub = subscription.on_window_close("win_close")
  subscription.tag(sub) |> should.equal("win_close")
}

pub fn commands_subscription_on_window_resize_test() {
  let sub = subscription.on_window_resize("win_resize")
  subscription.tag(sub) |> should.equal("win_resize")
}

pub fn commands_subscription_on_mouse_button_test() {
  let sub = subscription.on_mouse_button("mouse_btn")
  subscription.tag(sub) |> should.equal("mouse_btn")
}

pub fn commands_subscription_on_mouse_scroll_test() {
  let sub = subscription.on_mouse_scroll("scroll")
  subscription.tag(sub) |> should.equal("scroll")
}

pub fn commands_subscription_on_touch_test() {
  let sub = subscription.on_touch("touch")
  subscription.tag(sub) |> should.equal("touch")
}

pub fn commands_subscription_on_ime_test() {
  let sub = subscription.on_ime("ime")
  subscription.tag(sub) |> should.equal("ime")
}

pub fn commands_subscription_on_theme_change_test() {
  let sub = subscription.on_theme_change("theme")
  subscription.tag(sub) |> should.equal("theme")
}

pub fn commands_subscription_on_file_drop_test() {
  let sub = subscription.on_file_drop("files")
  subscription.tag(sub) |> should.equal("files")
}

pub fn commands_subscription_on_event_test() {
  let sub = subscription.on_event("all")
  subscription.tag(sub) |> should.equal("all")
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
  let event: Event = TimerTick(tag: "poll", timestamp: 100)
  case event {
    TimerTick(tag: "poll", ..) -> should.be_true(True)
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
