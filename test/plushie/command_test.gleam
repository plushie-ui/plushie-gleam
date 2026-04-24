import gleam/dict
import plushie/command
import plushie/command_encode

pub fn none_returns_none_variant_test() {
  assert command.none() == command.None
}

pub fn batch_wraps_commands_test() {
  let cmds = [command.focus("a"), command.exit()]
  assert command.batch(cmds) == command.Batch(commands: cmds)
}

pub fn focus_creates_focus_variant_test() {
  assert command.focus("search")
    == command.Renderer(command.Focus(widget_id: "search"))
}

pub fn focus_canvas_element_via_scoped_path_test() {
  // Canvas element focus uses scoped path: "canvas/element"
  assert command.focus("my_canvas/input-0")
    == command.Renderer(command.Focus(widget_id: "my_canvas/input-0"))
}

pub fn focus_next_test() {
  assert command.focus_next() == command.Renderer(command.FocusNext)
}

pub fn native_command_with_invalid_op_classifies_as_noop_test() {
  let cmd = command.native_command("g1", "../../clipboard_read", dict.new())
  assert command_encode.classify(cmd) == command_encode.NoOp
}

pub fn widget_batch_with_invalid_op_classifies_as_noop_test() {
  let cmd =
    command.widget_batch([
      #("g1", "set_value", dict.new()),
      #("g2", "../../clipboard_read", dict.new()),
    ])
  assert command_encode.classify(cmd) == command_encode.NoOp
}

pub fn focus_previous_test() {
  assert command.focus_previous() == command.Renderer(command.FocusPrevious)
}

pub fn exit_creates_exit_variant_test() {
  assert command.exit() == command.Exit
}

pub fn select_all_test() {
  assert command.select_all("editor")
    == command.Renderer(command.SelectAll(widget_id: "editor"))
}

pub fn close_window_test() {
  assert command.close_window("main")
    == command.Renderer(command.Window(command.CloseWindow(window_id: "main")))
}

pub fn resize_window_test() {
  assert command.resize_window("main", 800.0, 600.0)
    == command.Renderer(
      command.Window(command.ResizeWindow(
        window_id: "main",
        width: 800.0,
        height: 600.0,
      )),
    )
}

pub fn move_window_test() {
  assert command.move_window("main", 100.0, 200.0)
    == command.Renderer(
      command.Window(command.MoveWindow(window_id: "main", x: 100.0, y: 200.0)),
    )
}

pub fn maximize_window_defaults_to_true_test() {
  assert command.maximize_window("main")
    == command.Renderer(
      command.Window(command.MaximizeWindow(window_id: "main", maximized: True)),
    )
}

pub fn minimize_window_defaults_to_true_test() {
  assert command.minimize_window("main")
    == command.Renderer(
      command.Window(command.MinimizeWindow(window_id: "main", minimized: True)),
    )
}

pub fn toggle_maximize_test() {
  assert command.toggle_maximize("main")
    == command.Renderer(
      command.Window(command.ToggleMaximize(window_id: "main")),
    )
}

pub fn toggle_decorations_test() {
  assert command.toggle_decorations("main")
    == command.Renderer(
      command.Window(command.ToggleDecorations(window_id: "main")),
    )
}

pub fn focus_window_test() {
  assert command.focus_window("main")
    == command.Renderer(command.Window(command.FocusWindow(window_id: "main")))
}

pub fn screenshot_test() {
  assert command.screenshot("main", "snap")
    == command.Renderer(
      command.Window(command.Screenshot(window_id: "main", tag: "snap")),
    )
}

pub fn announce_test() {
  assert command.announce("hello")
    == command.Renderer(command.Announce(
      text: "hello",
      politeness: command.Polite,
    ))
}

pub fn announce_assertive_test() {
  assert command.announce_assertive("Connection lost")
    == command.Renderer(command.Announce(
      text: "Connection lost",
      politeness: command.Assertive,
    ))
}

pub fn announce_with_polite_test() {
  assert command.announce_with("saved", command.Polite)
    == command.Renderer(command.Announce(
      text: "saved",
      politeness: command.Polite,
    ))
}

pub fn focus_next_within_test() {
  assert command.focus_next_within("main#menu")
    == command.Renderer(command.FocusNextWithin(scope: "main#menu"))
}

pub fn focus_previous_within_test() {
  assert command.focus_previous_within("main#menu")
    == command.Renderer(command.FocusPreviousWithin(scope: "main#menu"))
}

pub fn create_image_test() {
  assert command.create_image("img1", <<1, 2, 3>>)
    == command.Renderer(
      command.Image(command.CreateImage(handle: "img1", data: <<1, 2, 3>>)),
    )
}

pub fn delete_image_test() {
  assert command.delete_image("img1")
    == command.Renderer(command.Image(command.DeleteImage(handle: "img1")))
}

pub fn clear_images_test() {
  assert command.clear_images()
    == command.Renderer(command.Image(command.ClearImages))
}

pub fn tree_hash_test() {
  assert command.tree_hash("h1")
    == command.Renderer(command.TreeHashQuery(tag: "h1"))
}

pub fn find_focused_test() {
  assert command.find_focused("f1")
    == command.Renderer(command.FindFocused(tag: "f1"))
}

pub fn advance_frame_test() {
  assert command.advance_frame(42)
    == command.Renderer(command.AdvanceFrame(timestamp: 42))
}

pub fn cancel_test() {
  assert command.cancel("job1") == command.Cancel(tag: "job1")
}

pub fn send_after_test() {
  assert command.send_after(1000, "tick")
    == command.SendAfter(delay_ms: 1000, msg: "tick")
}
