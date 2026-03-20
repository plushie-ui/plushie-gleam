import toddy/command

pub fn none_returns_none_variant_test() {
  assert command.none() == command.None
}

pub fn batch_wraps_commands_test() {
  let cmds = [command.focus("a"), command.exit()]
  assert command.batch(cmds) == command.Batch(commands: cmds)
}

pub fn focus_creates_focus_variant_test() {
  assert command.focus("search") == command.Focus(widget_id: "search")
}

pub fn focus_next_test() {
  assert command.focus_next() == command.FocusNext
}

pub fn focus_previous_test() {
  assert command.focus_previous() == command.FocusPrevious
}

pub fn exit_creates_exit_variant_test() {
  assert command.exit() == command.Exit
}

pub fn select_all_test() {
  assert command.select_all("editor") == command.SelectAll(widget_id: "editor")
}

pub fn close_window_test() {
  assert command.close_window("main") == command.CloseWindow(window_id: "main")
}

pub fn resize_window_test() {
  assert command.resize_window("main", 800.0, 600.0)
    == command.ResizeWindow(window_id: "main", width: 800.0, height: 600.0)
}

pub fn move_window_test() {
  assert command.move_window("main", 100.0, 200.0)
    == command.MoveWindow(window_id: "main", x: 100.0, y: 200.0)
}

pub fn maximize_window_defaults_to_true_test() {
  assert command.maximize_window("main")
    == command.MaximizeWindow(window_id: "main", maximized: True)
}

pub fn minimize_window_defaults_to_true_test() {
  assert command.minimize_window("main")
    == command.MinimizeWindow(window_id: "main", minimized: True)
}

pub fn toggle_maximize_test() {
  assert command.toggle_maximize("main")
    == command.ToggleMaximize(window_id: "main")
}

pub fn toggle_decorations_test() {
  assert command.toggle_decorations("main")
    == command.ToggleDecorations(window_id: "main")
}

pub fn gain_focus_test() {
  assert command.gain_focus("main") == command.GainFocus(window_id: "main")
}

pub fn screenshot_test() {
  assert command.screenshot("main", "snap")
    == command.Screenshot(window_id: "main", tag: "snap")
}

pub fn announce_test() {
  assert command.announce("hello") == command.Announce(text: "hello")
}

pub fn create_image_test() {
  assert command.create_image("img1", <<1, 2, 3>>)
    == command.CreateImage(handle: "img1", data: <<1, 2, 3>>)
}

pub fn delete_image_test() {
  assert command.delete_image("img1") == command.DeleteImage(handle: "img1")
}

pub fn clear_images_test() {
  assert command.clear_images() == command.ClearImages
}

pub fn tree_hash_test() {
  assert command.tree_hash("h1") == command.TreeHashQuery(tag: "h1")
}

pub fn find_focused_test() {
  assert command.find_focused("f1") == command.FindFocused(tag: "f1")
}

pub fn advance_frame_test() {
  assert command.advance_frame(42) == command.AdvanceFrame(timestamp: 42)
}

pub fn cancel_test() {
  assert command.cancel("job1") == command.Cancel(tag: "job1")
}

pub fn send_after_test() {
  assert command.send_after(1000, "tick")
    == command.SendAfter(delay_ms: 1000, msg: "tick")
}
