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
import plushie/node.{type PropValue}

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
  /// Focus a specific element within a canvas widget.
  FocusElement(canvas_id: String, element_id: String)
  /// Move focus to the next focusable widget in tab order.
  FocusNext
  /// Move focus to the previous focusable widget in tab order.
  FocusPrevious

  /// Select all text in a text input or text editor widget.
  SelectAll(widget_id: String)
  /// Move the text cursor to the beginning of the input.
  MoveCursorToFront(widget_id: String)
  /// Move the text cursor to the end of the input.
  MoveCursorToEnd(widget_id: String)
  /// Move the text cursor to a specific character position.
  MoveCursorTo(widget_id: String, position: Int)
  /// Select a range of text between `start` and `end` character positions.
  SelectRange(widget_id: String, start: Int, end: Int)

  /// Scroll a scrollable widget to an absolute offset.
  /// Both axes are optional and default to 0.0.
  ScrollTo(widget_id: String, offset_x: Option(Float), offset_y: Option(Float))
  /// Snap a scrollable widget to an absolute x/y offset instantly
  /// (no smooth scrolling).
  SnapTo(widget_id: String, x: Float, y: Float)
  /// Snap a scrollable widget to the end of its content.
  SnapToEnd(widget_id: String)
  /// Scroll a scrollable widget by a relative x/y delta.
  ScrollBy(widget_id: String, x: Float, y: Float)

  /// Close the window with the given ID.
  CloseWindow(window_id: String)
  /// Resize a window to the given dimensions in logical pixels.
  ResizeWindow(window_id: String, width: Float, height: Float)
  /// Move a window to the given screen position in logical pixels.
  MoveWindow(window_id: String, x: Float, y: Float)
  /// Set whether a window is maximized or restored.
  MaximizeWindow(window_id: String, maximized: Bool)
  /// Set whether a window is minimized or restored.
  MinimizeWindow(window_id: String, minimized: Bool)
  /// Set window mode (e.g. "windowed", "fullscreen").
  SetWindowMode(window_id: String, mode: String)
  /// Toggle a window between maximized and restored state.
  ToggleMaximize(window_id: String)
  /// Toggle window decorations (title bar, borders).
  ToggleDecorations(window_id: String)
  /// Give keyboard/input focus to a window, bringing it to the front.
  GainFocus(window_id: String)
  /// Set window stacking level ("normal", "always_on_top",
  /// "always_on_bottom"). May be ignored on Wayland.
  SetWindowLevel(window_id: String, level: String)
  /// Initiate a window drag operation (user moves the window).
  DragWindow(window_id: String)
  /// Initiate a drag-resize from the given edge/corner direction.
  DragResizeWindow(window_id: String, direction: String)
  /// Flash the taskbar/dock icon to request user attention. Urgency
  /// is "informational" or "critical"; None clears the request.
  RequestUserAttention(window_id: String, urgency: Option(String))
  /// Capture a screenshot of a window. The result arrives as a
  /// tagged system event.
  Screenshot(window_id: String, tag: String)
  /// Set whether a window can be resized by the user.
  SetResizable(window_id: String, resizable: Bool)
  /// Set the minimum allowed size for a window in logical pixels.
  SetMinSize(window_id: String, width: Float, height: Float)
  /// Set the maximum allowed size for a window in logical pixels.
  SetMaxSize(window_id: String, width: Float, height: Float)
  /// Enable mouse passthrough so clicks pass through to windows below.
  EnableMousePassthrough(window_id: String)
  /// Disable mouse passthrough, restoring normal click handling.
  DisableMousePassthrough(window_id: String)
  /// Show the native system menu (window controls) for a window.
  ShowSystemMenu(window_id: String)
  /// Set the resize increment size. The window will only resize in
  /// multiples of the given width/height. Pass None to clear.
  SetResizeIncrements(
    window_id: String,
    width: Option(Float),
    height: Option(Float),
  )
  /// Set whether the system can automatically organize windows into
  /// tabs. macOS-specific; no-op on other platforms.
  AllowAutomaticTabbing(enabled: Bool)
  /// Set the window icon from raw RGBA pixel data. The BitArray must
  /// be width * height * 4 bytes (R, G, B, A per pixel, row-major).
  SetIcon(window_id: String, rgba_data: BitArray, width: Int, height: Int)

  /// Query the size of a window. Result arrives as a SystemInfo event.
  GetWindowSize(window_id: String, tag: String)
  /// Query the position of a window. Result arrives as a SystemInfo event.
  GetWindowPosition(window_id: String, tag: String)
  /// Query whether a window is maximized. Result arrives as a SystemInfo event.
  IsMaximized(window_id: String, tag: String)
  /// Query whether a window is minimized. Result arrives as a SystemInfo event.
  IsMinimized(window_id: String, tag: String)
  /// Query the current window mode (windowed, fullscreen, hidden).
  /// Result arrives as a SystemInfo event.
  GetMode(window_id: String, tag: String)
  /// Query the window's DPI scale factor. Result arrives as a SystemInfo event.
  GetScaleFactor(window_id: String, tag: String)
  /// Query the raw platform window ID (e.g. X11 window ID, HWND).
  /// Result arrives as a SystemInfo event.
  RawWindowId(window_id: String, tag: String)
  /// Query the monitor size for the display containing a window.
  /// Result arrives as a SystemInfo event. Data is None if the
  /// monitor cannot be determined.
  MonitorSize(window_id: String, tag: String)
  /// Query the OS light/dark theme preference. Result arrives as a
  /// SystemTheme event with "light", "dark", or "none".
  GetSystemTheme(tag: String)
  /// Query system information (OS, CPU, memory, graphics). Result
  /// arrives as a SystemInfo event with a map of system fields.
  GetSystemInfo(tag: String)

  /// Register an image from encoded data (PNG, JPEG, etc.) under the
  /// given handle for use in image widgets.
  CreateImage(handle: String, data: BitArray)
  /// Register an image from raw RGBA pixel data (width * height * 4
  /// bytes) under the given handle.
  CreateImageRgba(handle: String, width: Int, height: Int, pixels: BitArray)
  /// Update an existing image handle with new encoded data.
  UpdateImage(handle: String, data: BitArray)
  /// Update an existing image handle with new raw RGBA pixel data.
  UpdateImageRgba(handle: String, width: Int, height: Int, pixels: BitArray)
  /// Delete a previously registered image by its handle.
  DeleteImage(handle: String)
  /// List all registered image handles. Result arrives as an
  /// ImageList event.
  ListImages(tag: String)
  /// Delete all registered images.
  ClearImages

  /// Announce text to screen readers via the accessibility system.
  Announce(text: String)

  /// Split a pane in a pane_grid widget along the given axis
  /// ("horizontal" or "vertical"), creating a new pane.
  PaneSplit(
    pane_grid_id: String,
    pane_id: String,
    axis: String,
    new_pane_id: String,
  )
  /// Close a pane in a pane_grid widget.
  PaneClose(pane_grid_id: String, pane_id: String)
  /// Swap two panes in a pane_grid widget.
  PaneSwap(pane_grid_id: String, pane_a: String, pane_b: String)
  /// Maximize a single pane to fill the entire pane_grid.
  PaneMaximize(pane_grid_id: String, pane_id: String)
  /// Restore all panes from maximized state in a pane_grid.
  PaneRestore(pane_grid_id: String)

  /// Compute a SHA-256 hash of the renderer's current tree state.
  /// Result arrives as a TreeHash event.
  TreeHashQuery(tag: String)
  /// Query which widget currently has keyboard focus. Result arrives
  /// as a FocusedWidget event.
  FindFocused(tag: String)
  /// Load a font at runtime from raw TrueType or OpenType binary data.
  /// Once loaded, the font can be referenced by name in widget props.
  LoadFont(data: BitArray)

  /// Request a platform effect (file dialog, clipboard, notification).
  /// The result arrives as an `EffectResponse` event matched by `id`.
  Effect(id: String, kind: String, payload: Dict(String, PropValue))

  /// Send a command directly to a native extension widget, bypassing
  /// the normal tree diff/patch cycle.
  ExtensionCommand(
    node_id: String,
    op: String,
    payload: Dict(String, PropValue),
  )
  /// Send a batch of extension commands processed in one cycle.
  ExtensionCommands(commands: List(#(String, String, Dict(String, PropValue))))

  /// Advance the renderer by one frame in test/headless mode. The
  /// timestamp is monotonic milliseconds. In normal mode the renderer
  /// drives frames from display vsync.
  AdvanceFrame(timestamp: Int)
}

// --- Constructor functions ---------------------------------------------------

/// No side effect. Return this from update when no command is needed.
pub fn none() -> Command(msg) {
  None
}

/// Execute multiple commands in list order.
pub fn batch(commands: List(Command(msg))) -> Command(msg) {
  Batch(commands:)
}

/// Wrap an already-resolved value and deliver it through update via
/// the mapper function. Useful for lifting pure values into the
/// command pipeline.
pub fn done(value: Dynamic, mapper: fn(Dynamic) -> msg) -> Command(msg) {
  Done(value:, mapper:)
}

/// Run a function asynchronously on a background process. The result
/// is delivered as an AsyncResult event identified by the tag.
pub fn async(work: fn() -> Dynamic, tag: String) -> Command(msg) {
  Async(work:, tag:)
}

/// Run a function that can emit multiple values over time. Each value
/// is delivered as a StreamValue event identified by the tag.
pub fn stream(
  work: fn(fn(Dynamic) -> Nil) -> Dynamic,
  tag: String,
) -> Command(msg) {
  Stream(work:, tag:)
}

/// Cancel a running async or stream task by its tag.
pub fn cancel(tag: String) -> Command(msg) {
  Cancel(tag:)
}

/// Deliver a message back to update after a delay in milliseconds.
/// Sending another SendAfter with an identical msg replaces the
/// previous timer.
pub fn send_after(delay_ms: Int, msg: msg) -> Command(msg) {
  SendAfter(delay_ms:, msg:)
}

/// Shut down the runtime and close all windows.
pub fn exit() -> Command(msg) {
  Exit
}

/// Move keyboard focus to the given widget.
pub fn focus(widget_id: String) -> Command(msg) {
  Focus(widget_id:)
}

/// Focus a specific element within a canvas widget.
pub fn focus_element(canvas_id: String, element_id: String) -> Command(msg) {
  FocusElement(canvas_id:, element_id:)
}

/// Move focus to the next focusable widget.
pub fn focus_next() -> Command(msg) {
  FocusNext
}

/// Move focus to the previous focusable widget.
pub fn focus_previous() -> Command(msg) {
  FocusPrevious
}

/// Select all text in the given text input widget.
pub fn select_all(widget_id: String) -> Command(msg) {
  SelectAll(widget_id:)
}

/// Close the window with the given ID.
pub fn close_window(window_id: String) -> Command(msg) {
  CloseWindow(window_id:)
}

/// Resize a window to the given dimensions in logical pixels.
pub fn resize_window(
  window_id: String,
  width: Float,
  height: Float,
) -> Command(msg) {
  ResizeWindow(window_id:, width:, height:)
}

/// Move a window to the given screen position.
pub fn move_window(window_id: String, x: Float, y: Float) -> Command(msg) {
  MoveWindow(window_id:, x:, y:)
}

/// Maximize a window.
pub fn maximize_window(window_id: String) -> Command(msg) {
  MaximizeWindow(window_id:, maximized: True)
}

/// Minimize a window.
pub fn minimize_window(window_id: String) -> Command(msg) {
  MinimizeWindow(window_id:, minimized: True)
}

/// Toggle a window between maximized and restored state.
pub fn toggle_maximize(window_id: String) -> Command(msg) {
  ToggleMaximize(window_id:)
}

/// Toggle window decorations (title bar, borders).
pub fn toggle_decorations(window_id: String) -> Command(msg) {
  ToggleDecorations(window_id:)
}

/// Give focus to a window, bringing it to the front.
pub fn gain_focus(window_id: String) -> Command(msg) {
  GainFocus(window_id:)
}

/// Take a screenshot of a window. The result arrives as a tagged event.
pub fn screenshot(window_id: String, tag: String) -> Command(msg) {
  Screenshot(window_id:, tag:)
}

/// Announce text to screen readers via the accessibility system.
pub fn announce(text: String) -> Command(msg) {
  Announce(text:)
}

/// Register an image from encoded data (PNG, JPEG, etc.) under the
/// given handle for use in image widgets.
pub fn create_image(handle: String, data: BitArray) -> Command(msg) {
  CreateImage(handle:, data:)
}

/// Delete a previously registered image by its handle.
pub fn delete_image(handle: String) -> Command(msg) {
  DeleteImage(handle:)
}

/// Delete all registered images.
pub fn clear_images() -> Command(msg) {
  ClearImages
}

/// Query the current tree hash from the renderer. The result arrives
/// as a tagged event.
pub fn tree_hash(tag: String) -> Command(msg) {
  TreeHashQuery(tag:)
}

/// Query which widget currently has focus. The result arrives as a
/// tagged event.
pub fn find_focused(tag: String) -> Command(msg) {
  FindFocused(tag:)
}

/// Advance the renderer by one frame in test/headless mode.
pub fn advance_frame(timestamp: Int) -> Command(msg) {
  AdvanceFrame(timestamp:)
}
