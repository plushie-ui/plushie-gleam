//// Command types returned from update.
////
//// Commands describe side effects that the runtime executes after
//// `update` returns. The lifecycle is: `update` returns
//// `#(model, command)`, the runtime executes the command, and then
//// calls `view` with the new model. Batched commands execute in
//// list order. For no side effects, return `command.none()`.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import toddy/node.{type PropValue}

pub type Command(msg) {
  /// No side effect.
  None
  /// Execute multiple commands in list order.
  Batch(commands: List(Command(msg)))
  /// Deliver an already-resolved value through update via the mapper.
  Done(value: Dynamic, mapper: fn(Dynamic) -> msg)
  /// Run a function on a background process. The result is delivered
  /// as an `AsyncResult` event identified by `tag`.
  Async(work: fn() -> Dynamic, tag: String)
  /// Run a function that can emit multiple values over time. Each
  /// value is delivered as a `StreamValue` event identified by `tag`.
  Stream(work: fn(fn(Dynamic) -> Nil) -> Dynamic, tag: String)
  /// Cancel a running Async or Stream task by tag.
  Cancel(tag: String)
  /// Deliver `msg` back to update after `delay_ms` milliseconds.
  /// Sending another SendAfter with an identical msg cancels the
  /// previous timer (deduplication via stable hashing).
  SendAfter(delay_ms: Int, msg: msg)
  /// Shut down the runtime and close all windows.
  Exit

  /// Move keyboard focus to the given widget.
  Focus(widget_id: String)
  FocusNext
  FocusPrevious

  // Text
  SelectAll(widget_id: String)
  MoveCursorToFront(widget_id: String)
  MoveCursorToEnd(widget_id: String)
  MoveCursorTo(widget_id: String, position: Int)
  SelectRange(widget_id: String, start: Int, end: Int)

  // Scroll
  ScrollTo(widget_id: String, offset: Dynamic)
  SnapTo(widget_id: String, x: Float, y: Float)
  SnapToEnd(widget_id: String)
  ScrollBy(widget_id: String, x: Float, y: Float)

  // Window ops
  CloseWindow(window_id: String)
  ResizeWindow(window_id: String, width: Float, height: Float)
  MoveWindow(window_id: String, x: Float, y: Float)
  MaximizeWindow(window_id: String, maximized: Bool)
  MinimizeWindow(window_id: String, minimized: Bool)
  SetWindowMode(window_id: String, mode: String)
  ToggleMaximize(window_id: String)
  ToggleDecorations(window_id: String)
  GainFocus(window_id: String)
  SetWindowLevel(window_id: String, level: String)
  DragWindow(window_id: String)
  DragResizeWindow(window_id: String, direction: String)
  RequestUserAttention(window_id: String, urgency: Option(String))
  Screenshot(window_id: String, tag: String)
  SetResizable(window_id: String, resizable: Bool)
  SetMinSize(window_id: String, width: Float, height: Float)
  SetMaxSize(window_id: String, width: Float, height: Float)
  EnableMousePassthrough(window_id: String)
  DisableMousePassthrough(window_id: String)
  ShowSystemMenu(window_id: String)
  SetResizeIncrements(
    window_id: String,
    width: Option(Float),
    height: Option(Float),
  )
  AllowAutomaticTabbing(enabled: Bool)
  SetIcon(window_id: String, rgba_data: BitArray, width: Int, height: Int)

  // Window queries
  GetWindowSize(window_id: String, tag: String)
  GetWindowPosition(window_id: String, tag: String)
  IsMaximized(window_id: String, tag: String)
  IsMinimized(window_id: String, tag: String)
  GetMode(window_id: String, tag: String)
  GetScaleFactor(window_id: String, tag: String)
  RawWindowId(window_id: String, tag: String)
  MonitorSize(window_id: String, tag: String)
  GetSystemTheme(tag: String)
  GetSystemInfo(tag: String)

  // Image ops
  CreateImage(handle: String, data: BitArray)
  CreateImageRgba(handle: String, width: Int, height: Int, pixels: BitArray)
  UpdateImage(handle: String, data: BitArray)
  UpdateImageRgba(handle: String, width: Int, height: Int, pixels: BitArray)
  DeleteImage(handle: String)
  ListImages(tag: String)
  ClearImages

  // Accessibility
  Announce(text: String)

  // PaneGrid
  PaneSplit(
    pane_grid_id: String,
    pane_id: Dynamic,
    axis: String,
    new_pane_id: Dynamic,
  )
  PaneClose(pane_grid_id: String, pane_id: Dynamic)
  PaneSwap(pane_grid_id: String, pane_a: Dynamic, pane_b: Dynamic)
  PaneMaximize(pane_grid_id: String, pane_id: Dynamic)
  PaneRestore(pane_grid_id: String)

  // Queries
  TreeHashQuery(tag: String)
  FindFocused(tag: String)
  LoadFont(data: BitArray)

  /// Request a platform effect (file dialog, clipboard, notification).
  /// The result arrives as an `EffectResponse` event matched by `id`.
  Effect(id: String, kind: String, payload: Dict(String, PropValue))

  // Extensions
  ExtensionCommand(
    node_id: String,
    op: String,
    payload: Dict(String, PropValue),
  )
  ExtensionCommands(commands: List(#(String, String, Dict(String, PropValue))))

  // Test/headless
  AdvanceFrame(timestamp: Int)
}

// --- Constructor functions ---------------------------------------------------

pub fn none() -> Command(msg) {
  None
}

pub fn batch(commands: List(Command(msg))) -> Command(msg) {
  Batch(commands:)
}

/// Wrap an already-resolved value and deliver it through update via
/// the mapper function. Useful for lifting pure values into the
/// command pipeline.
pub fn done(value: Dynamic, mapper: fn(Dynamic) -> msg) -> Command(msg) {
  Done(value:, mapper:)
}

pub fn async(work: fn() -> Dynamic, tag: String) -> Command(msg) {
  Async(work:, tag:)
}

pub fn stream(
  work: fn(fn(Dynamic) -> Nil) -> Dynamic,
  tag: String,
) -> Command(msg) {
  Stream(work:, tag:)
}

pub fn cancel(tag: String) -> Command(msg) {
  Cancel(tag:)
}

pub fn send_after(delay_ms: Int, msg: msg) -> Command(msg) {
  SendAfter(delay_ms:, msg:)
}

pub fn exit() -> Command(msg) {
  Exit
}

pub fn focus(widget_id: String) -> Command(msg) {
  Focus(widget_id:)
}

pub fn focus_next() -> Command(msg) {
  FocusNext
}

pub fn focus_previous() -> Command(msg) {
  FocusPrevious
}

pub fn select_all(widget_id: String) -> Command(msg) {
  SelectAll(widget_id:)
}

pub fn close_window(window_id: String) -> Command(msg) {
  CloseWindow(window_id:)
}

pub fn resize_window(
  window_id: String,
  width: Float,
  height: Float,
) -> Command(msg) {
  ResizeWindow(window_id:, width:, height:)
}

pub fn move_window(window_id: String, x: Float, y: Float) -> Command(msg) {
  MoveWindow(window_id:, x:, y:)
}

pub fn maximize_window(window_id: String) -> Command(msg) {
  MaximizeWindow(window_id:, maximized: True)
}

pub fn minimize_window(window_id: String) -> Command(msg) {
  MinimizeWindow(window_id:, minimized: True)
}

pub fn toggle_maximize(window_id: String) -> Command(msg) {
  ToggleMaximize(window_id:)
}

pub fn toggle_decorations(window_id: String) -> Command(msg) {
  ToggleDecorations(window_id:)
}

pub fn gain_focus(window_id: String) -> Command(msg) {
  GainFocus(window_id:)
}

pub fn screenshot(window_id: String, tag: String) -> Command(msg) {
  Screenshot(window_id:, tag:)
}

pub fn announce(text: String) -> Command(msg) {
  Announce(text:)
}

pub fn create_image(handle: String, data: BitArray) -> Command(msg) {
  CreateImage(handle:, data:)
}

pub fn delete_image(handle: String) -> Command(msg) {
  DeleteImage(handle:)
}

pub fn clear_images() -> Command(msg) {
  ClearImages
}

pub fn tree_hash(tag: String) -> Command(msg) {
  TreeHashQuery(tag:)
}

pub fn find_focused(tag: String) -> Command(msg) {
  FindFocused(tag:)
}

pub fn advance_frame(timestamp: Int) -> Command(msg) {
  AdvanceFrame(timestamp:)
}
