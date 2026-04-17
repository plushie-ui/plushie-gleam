//// Command types returned from update.
////
//// Commands describe side effects that the runtime executes after
//// `update` returns. The lifecycle is: `update` returns
//// `#(model, command)`, the runtime executes the command, and then
//// calls `view` with the new model. Batched commands execute in
//// list order. For no side effects, return `command.none()`.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/option.{type Option}
import plushie/node.{type PropValue}

pub type Command(msg) {
  /// No side effect.
  None
  /// Execute multiple commands in list order.
  Batch(commands: List(Command(msg)))
  /// Deliver an already-resolved value through update via the mapper.
  ///
  /// Note: the mapper function runs when the event is processed, which
  /// may be after further state changes. Do not capture the current
  /// model in the closure; use the model available in your update
  /// function instead.
  Done(value: Dynamic, mapper: fn(Dynamic) -> msg)
  /// Run a function on a background process. The result is delivered
  /// as an `AsyncResult` event identified by `tag`. Starting a new
  /// task with the same tag cancels the running one (single-instance
  /// per tag). Use unique tags for concurrent tasks.
  Async(work: fn() -> Dynamic, tag: String)
  /// Run a function that can emit multiple values over time. Each
  /// value is delivered as a `StreamValue` event identified by `tag`.
  /// Starting a new stream with the same tag cancels the running one.
  Stream(work: fn(fn(Dynamic) -> Nil) -> Dynamic, tag: String)
  /// Cancel a running Async or Stream task by tag.
  Cancel(tag: String)
  /// Deliver `msg` back to update after `delay_ms` milliseconds.
  /// Sending another SendAfter with an identical msg cancels the
  /// previous timer (deduplication via stable hashing).
  SendAfter(delay_ms: Int, msg: msg)
  /// Shut down the runtime and close all windows.
  Exit
  /// A command that targets the renderer (widget ops, window ops,
  /// system queries, image management, effects, etc.).
  Renderer(RendererCommand)
}

/// Commands sent to the renderer process. Organized into sub-types
/// for window operations, system operations, and image management.
pub type RendererCommand {
  /// Move keyboard focus to the given widget. For canvas elements,
  /// use the scoped path (e.g. "canvas/element").
  Focus(widget_id: String)
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
  /// Select a range of text between start_pos and end_pos character positions.
  SelectRange(widget_id: String, start_pos: Int, end_pos: Int)

  /// Scroll a scrollable widget to an absolute offset.
  ScrollTo(widget_id: String, x: Float, y: Float)
  /// Snap a scrollable widget to an absolute x/y offset instantly
  /// (no smooth scrolling).
  SnapTo(widget_id: String, x: Float, y: Float)
  /// Snap a scrollable widget to the end of its content.
  SnapToEnd(widget_id: String)
  /// Scroll a scrollable widget by a relative x/y delta.
  ScrollBy(widget_id: String, x: Float, y: Float)

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

  /// Window operation.
  Window(WindowCommand)
  /// System operation.
  System(SystemCommand)
  /// Image operation.
  Image(ImageCommand)

  /// Send a command directly to a native widget, bypassing the
  /// normal tree diff/patch cycle.
  NativeCommand(node_id: String, op: String, payload: Dict(String, PropValue))
  /// Send a batch of widget commands processed in one cycle.
  NativeCommands(commands: List(#(String, String, Dict(String, PropValue))))

  /// Request a platform effect (file dialog, clipboard, notification).
  /// The `tag` identifies this effect in the `EffectResponse` event.
  /// The `id` is an opaque wire correlation ID, never exposed to app code.
  Effect(
    id: String,
    tag: String,
    kind: String,
    payload: Dict(String, PropValue),
  )

  /// Announce text to screen readers via the accessibility system.
  Announce(text: String)
  /// Load a font at runtime from raw TrueType or OpenType binary data.
  /// Once loaded, the font can be referenced by name in widget props.
  LoadFont(data: BitArray)

  /// Compute a SHA-256 hash of the renderer's current tree state.
  /// Result arrives as a TreeHash event.
  TreeHashQuery(tag: String)
  /// Query which widget currently has keyboard focus. Result arrives
  /// as a FocusedWidget event.
  FindFocused(tag: String)
  /// Advance the renderer by one frame in test/headless mode. The
  /// timestamp is monotonic milliseconds. In normal mode the renderer
  /// drives frames from display vsync.
  AdvanceFrame(timestamp: Int)
}

/// Window lifecycle and query commands.
pub type WindowCommand {
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
  FocusWindow(window_id: String)
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
}

/// System-wide commands not tied to a specific window.
pub type SystemCommand {
  /// Set whether the system can automatically organize windows into
  /// tabs. macOS-specific; no-op on other platforms.
  AllowAutomaticTabbing(enabled: Bool)
  /// Query the OS light/dark theme preference. Result arrives as a
  /// SystemTheme event with "light", "dark", or "none".
  GetSystemTheme(tag: String)
  /// Query system information (OS, CPU, memory, graphics). Result
  /// arrives as a SystemInfo event with a map of system fields.
  GetSystemInfo(tag: String)
}

/// Image registration and management commands.
pub type ImageCommand {
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
///
/// Note: the mapper function runs when the event is processed, which
/// may be after further state changes. Do not capture the current
/// model in the closure; use the model available in your update
/// function instead.
pub fn done(value: Dynamic, mapper: fn(Dynamic) -> msg) -> Command(msg) {
  Done(value:, mapper:)
}

/// Run a function asynchronously on a background process. The result
/// is delivered as an AsyncResult event identified by the tag.
/// Starting a new task with the same tag cancels the running one.
pub fn async(work: fn() -> Dynamic, tag: String) -> Command(msg) {
  Async(work:, tag:)
}

/// Run a function that can emit multiple values over time. Each value
/// is delivered as a StreamValue event identified by the tag.
/// Starting a new stream with the same tag cancels the running one.
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
  Renderer(Focus(widget_id:))
}

/// Move focus to the next focusable widget.
pub fn focus_next() -> Command(msg) {
  Renderer(FocusNext)
}

/// Move focus to the previous focusable widget.
pub fn focus_previous() -> Command(msg) {
  Renderer(FocusPrevious)
}

/// Select all text in the given text input widget.
pub fn select_all(widget_id: String) -> Command(msg) {
  Renderer(SelectAll(widget_id:))
}

/// Close the window with the given ID.
pub fn close_window(window_id: String) -> Command(msg) {
  Renderer(Window(CloseWindow(window_id:)))
}

/// Resize a window to the given dimensions in logical pixels.
pub fn resize_window(
  window_id: String,
  width: Float,
  height: Float,
) -> Command(msg) {
  Renderer(Window(ResizeWindow(window_id:, width:, height:)))
}

/// Move a window to the given screen position.
pub fn move_window(window_id: String, x: Float, y: Float) -> Command(msg) {
  Renderer(Window(MoveWindow(window_id:, x:, y:)))
}

/// Maximize a window.
pub fn maximize_window(window_id: String) -> Command(msg) {
  Renderer(Window(MaximizeWindow(window_id:, maximized: True)))
}

/// Minimize a window.
pub fn minimize_window(window_id: String) -> Command(msg) {
  Renderer(Window(MinimizeWindow(window_id:, minimized: True)))
}

/// Toggle a window between maximized and restored state.
pub fn toggle_maximize(window_id: String) -> Command(msg) {
  Renderer(Window(ToggleMaximize(window_id:)))
}

/// Toggle window decorations (title bar, borders).
pub fn toggle_decorations(window_id: String) -> Command(msg) {
  Renderer(Window(ToggleDecorations(window_id:)))
}

/// Give focus to a window, bringing it to the front.
pub fn focus_window(window_id: String) -> Command(msg) {
  Renderer(Window(FocusWindow(window_id:)))
}

/// Take a screenshot of a window. The result arrives as a tagged event.
pub fn screenshot(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(Screenshot(window_id:, tag:)))
}

/// Announce text to screen readers via the accessibility system.
pub fn announce(text: String) -> Command(msg) {
  Renderer(Announce(text:))
}

/// Register an image from encoded data (PNG, JPEG, etc.) under the
/// given handle for use in image widgets.
pub fn create_image(handle: String, data: BitArray) -> Command(msg) {
  Renderer(Image(CreateImage(handle:, data:)))
}

/// Register an image from raw RGBA pixel data under the given handle.
/// The pixel buffer must be exactly `width * height * 4` bytes
/// (R, G, B, A per pixel, row-major).
pub fn create_image_rgba(
  handle: String,
  width: Int,
  height: Int,
  pixels: BitArray,
) -> Command(msg) {
  validate_rgba_buffer(pixels, width, height)
  Renderer(Image(CreateImageRgba(handle:, width:, height:, pixels:)))
}

/// Update an existing image handle with new raw RGBA pixel data.
/// The pixel buffer must be exactly `width * height * 4` bytes
/// (R, G, B, A per pixel, row-major).
pub fn update_image_rgba(
  handle: String,
  width: Int,
  height: Int,
  pixels: BitArray,
) -> Command(msg) {
  validate_rgba_buffer(pixels, width, height)
  Renderer(Image(UpdateImageRgba(handle:, width:, height:, pixels:)))
}

fn validate_rgba_buffer(pixels: BitArray, width: Int, height: Int) -> Nil {
  let expected = width * height * 4
  let actual = bit_array.byte_size(pixels)
  case actual == expected {
    True -> Nil
    False ->
      panic as {
        "RGBA pixel buffer size mismatch: expected "
        <> int.to_string(expected)
        <> " bytes ("
        <> int.to_string(width)
        <> "x"
        <> int.to_string(height)
        <> "x4) but got "
        <> int.to_string(actual)
      }
  }
}

/// Delete a previously registered image by its handle.
pub fn delete_image(handle: String) -> Command(msg) {
  Renderer(Image(DeleteImage(handle:)))
}

/// Delete all registered images.
pub fn clear_images() -> Command(msg) {
  Renderer(Image(ClearImages))
}

/// Query the current tree hash from the renderer. The result arrives
/// as a tagged event.
pub fn tree_hash(tag: String) -> Command(msg) {
  Renderer(TreeHashQuery(tag:))
}

/// Query which widget currently has focus. The result arrives as a
/// tagged event.
pub fn find_focused(tag: String) -> Command(msg) {
  Renderer(FindFocused(tag:))
}

/// Advance the renderer by one frame in test/headless mode.
pub fn advance_frame(timestamp: Int) -> Command(msg) {
  Renderer(AdvanceFrame(timestamp:))
}

// --- Text cursor commands ----------------------------------------------------

/// Move the text cursor to the beginning of the input.
pub fn move_cursor_to_front(widget_id: String) -> Command(msg) {
  Renderer(MoveCursorToFront(widget_id:))
}

/// Move the text cursor to the end of the input.
pub fn move_cursor_to_end(widget_id: String) -> Command(msg) {
  Renderer(MoveCursorToEnd(widget_id:))
}

/// Move the text cursor to a specific character position.
pub fn move_cursor_to(widget_id: String, position: Int) -> Command(msg) {
  Renderer(MoveCursorTo(widget_id:, position:))
}

/// Select a range of text between start_pos and end_pos character positions.
pub fn select_range(
  widget_id: String,
  start_pos: Int,
  end_pos: Int,
) -> Command(msg) {
  Renderer(SelectRange(widget_id:, start_pos:, end_pos:))
}

// --- Scroll commands ---------------------------------------------------------

/// Scroll a scrollable widget to an absolute x/y offset.
pub fn scroll_to(widget_id: String, x: Float, y: Float) -> Command(msg) {
  Renderer(ScrollTo(widget_id:, x:, y:))
}

/// Snap a scrollable widget to an absolute x/y offset instantly
/// (no smooth scrolling).
pub fn snap_to(widget_id: String, x: Float, y: Float) -> Command(msg) {
  Renderer(SnapTo(widget_id:, x:, y:))
}

/// Snap a scrollable widget to the end of its content.
pub fn snap_to_end(widget_id: String) -> Command(msg) {
  Renderer(SnapToEnd(widget_id:))
}

/// Scroll a scrollable widget by a relative x/y delta.
pub fn scroll_by(widget_id: String, x: Float, y: Float) -> Command(msg) {
  Renderer(ScrollBy(widget_id:, x:, y:))
}

// --- Pane grid commands ------------------------------------------------------

/// Split a pane in a pane_grid widget along the given axis
/// ("horizontal" or "vertical"), creating a new pane.
pub fn pane_split(
  pane_grid_id: String,
  pane_id: String,
  axis: String,
  new_pane_id: String,
) -> Command(msg) {
  Renderer(PaneSplit(pane_grid_id:, pane_id:, axis:, new_pane_id:))
}

/// Close a pane in a pane_grid widget.
pub fn pane_close(pane_grid_id: String, pane_id: String) -> Command(msg) {
  Renderer(PaneClose(pane_grid_id:, pane_id:))
}

/// Swap two panes in a pane_grid widget.
pub fn pane_swap(
  pane_grid_id: String,
  pane_a: String,
  pane_b: String,
) -> Command(msg) {
  Renderer(PaneSwap(pane_grid_id:, pane_a:, pane_b:))
}

/// Maximize a single pane to fill the entire pane_grid.
pub fn pane_maximize(pane_grid_id: String, pane_id: String) -> Command(msg) {
  Renderer(PaneMaximize(pane_grid_id:, pane_id:))
}

/// Restore all panes from maximized state in a pane_grid.
pub fn pane_restore(pane_grid_id: String) -> Command(msg) {
  Renderer(PaneRestore(pane_grid_id:))
}

// --- Window operation commands -----------------------------------------------

/// Set the window mode (e.g. "windowed", "fullscreen").
pub fn set_window_mode(window_id: String, mode: String) -> Command(msg) {
  Renderer(Window(SetWindowMode(window_id:, mode:)))
}

/// Set window stacking level ("normal", "always_on_top",
/// "always_on_bottom"). May be ignored on Wayland.
pub fn set_window_level(window_id: String, level: String) -> Command(msg) {
  Renderer(Window(SetWindowLevel(window_id:, level:)))
}

/// Initiate a window drag operation (user moves the window).
pub fn drag_window(window_id: String) -> Command(msg) {
  Renderer(Window(DragWindow(window_id:)))
}

/// Initiate a drag-resize from the given edge/corner direction.
pub fn drag_resize_window(window_id: String, direction: String) -> Command(msg) {
  Renderer(Window(DragResizeWindow(window_id:, direction:)))
}

/// Flash the taskbar/dock icon to request user attention. Urgency
/// is "informational" or "critical"; None clears the request.
pub fn request_attention(
  window_id: String,
  urgency: Option(String),
) -> Command(msg) {
  Renderer(Window(RequestUserAttention(window_id:, urgency:)))
}

/// Set whether a window can be resized by the user.
pub fn set_resizable(window_id: String, resizable: Bool) -> Command(msg) {
  Renderer(Window(SetResizable(window_id:, resizable:)))
}

/// Set the minimum allowed size for a window in logical pixels.
pub fn set_min_size(
  window_id: String,
  width: Float,
  height: Float,
) -> Command(msg) {
  Renderer(Window(SetMinSize(window_id:, width:, height:)))
}

/// Set the maximum allowed size for a window in logical pixels.
pub fn set_max_size(
  window_id: String,
  width: Float,
  height: Float,
) -> Command(msg) {
  Renderer(Window(SetMaxSize(window_id:, width:, height:)))
}

/// Enable mouse passthrough so clicks pass through to windows below.
pub fn enable_mouse_passthrough(window_id: String) -> Command(msg) {
  Renderer(Window(EnableMousePassthrough(window_id:)))
}

/// Disable mouse passthrough, restoring normal click handling.
pub fn disable_mouse_passthrough(window_id: String) -> Command(msg) {
  Renderer(Window(DisableMousePassthrough(window_id:)))
}

/// Show the native system menu (window controls) for a window.
pub fn show_system_menu(window_id: String) -> Command(msg) {
  Renderer(Window(ShowSystemMenu(window_id:)))
}

/// Set the resize increment size. The window will only resize in
/// multiples of the given width/height. Pass None to clear.
pub fn set_resize_increments(
  window_id: String,
  width: Option(Float),
  height: Option(Float),
) -> Command(msg) {
  Renderer(Window(SetResizeIncrements(window_id:, width:, height:)))
}

/// Set the window icon from raw RGBA pixel data. The BitArray must
/// be width * height * 4 bytes (R, G, B, A per pixel, row-major).
pub fn set_icon(
  window_id: String,
  rgba_data: BitArray,
  width: Int,
  height: Int,
) -> Command(msg) {
  validate_rgba_buffer(rgba_data, width, height)
  Renderer(Window(SetIcon(window_id:, rgba_data:, width:, height:)))
}

// --- Window query commands ---------------------------------------------------

/// Query the size of a window. Result arrives as a SystemInfo event.
pub fn get_window_size(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(GetWindowSize(window_id:, tag:)))
}

/// Query the position of a window. Result arrives as a SystemInfo event.
pub fn get_window_position(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(GetWindowPosition(window_id:, tag:)))
}

/// Query whether a window is maximized. Result arrives as a SystemInfo event.
pub fn is_maximized(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(IsMaximized(window_id:, tag:)))
}

/// Query whether a window is minimized. Result arrives as a SystemInfo event.
pub fn is_minimized(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(IsMinimized(window_id:, tag:)))
}

/// Query the current window mode (windowed, fullscreen, hidden).
/// Result arrives as a SystemInfo event.
pub fn get_mode(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(GetMode(window_id:, tag:)))
}

/// Query the window's DPI scale factor. Result arrives as a SystemInfo event.
pub fn get_scale_factor(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(GetScaleFactor(window_id:, tag:)))
}

/// Query the raw platform window ID (e.g. X11 window ID, HWND).
/// Result arrives as a SystemInfo event.
pub fn raw_window_id(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(RawWindowId(window_id:, tag:)))
}

/// Query the monitor size for the display containing a window.
/// Result arrives as a SystemInfo event.
pub fn monitor_size(window_id: String, tag: String) -> Command(msg) {
  Renderer(Window(MonitorSize(window_id:, tag:)))
}

// --- System commands ---------------------------------------------------------

/// Set whether the system can automatically organize windows into
/// tabs. macOS-specific; no-op on other platforms.
pub fn allow_automatic_tabbing(enabled: Bool) -> Command(msg) {
  Renderer(System(AllowAutomaticTabbing(enabled:)))
}

/// Query the OS light/dark theme preference. Result arrives as a
/// SystemTheme event with "light", "dark", or "none".
pub fn get_system_theme(tag: String) -> Command(msg) {
  Renderer(System(GetSystemTheme(tag:)))
}

/// Query system information (OS, CPU, memory, graphics). Result
/// arrives as a SystemInfo event with a map of system fields.
pub fn get_system_info(tag: String) -> Command(msg) {
  Renderer(System(GetSystemInfo(tag:)))
}

// --- Image commands ----------------------------------------------------------

/// Update an existing image handle with new encoded data.
pub fn update_image(handle: String, data: BitArray) -> Command(msg) {
  Renderer(Image(UpdateImage(handle:, data:)))
}

/// List all registered image handles. Result arrives as an
/// ImageList event.
pub fn list_images(tag: String) -> Command(msg) {
  Renderer(Image(ListImages(tag:)))
}

// --- Font and native commands ------------------------------------------------

/// Load a font at runtime from raw TrueType or OpenType binary data.
/// Once loaded, the font can be referenced by name in widget props.
pub fn load_font(data: BitArray) -> Command(msg) {
  Renderer(LoadFont(data:))
}

/// Send a command directly to a native widget, bypassing the
/// normal tree diff/patch cycle.
pub fn native_command(
  node_id: String,
  op: String,
  payload: Dict(String, PropValue),
) -> Command(msg) {
  Renderer(NativeCommand(node_id:, op:, payload:))
}

/// Send a batch of native widget commands processed in one cycle.
/// Each tuple is `#(node_id, op, payload)`.
pub fn native_commands(
  commands: List(#(String, String, Dict(String, PropValue))),
) -> Command(msg) {
  Renderer(NativeCommands(commands:))
}
