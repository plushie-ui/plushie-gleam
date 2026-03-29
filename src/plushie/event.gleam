//// Event types for the plushie wire protocol.
////
//// Events are delivered to the app's `update` function from the Rust
//// binary via the bridge actor. Pattern match on specific constructors
//// and use `_ ->` for unhandled events.
////
//// Window-bound widget events carry a `window_id`, an `id` (the
//// widget's local ID after scope splitting), and a `scope`
//// (list of ancestor container IDs, nearest first). For example,
//// a button "save" inside container "form" in window "main"
//// produces `WidgetClick(window_id: "main", id: "save", scope: ["form"])`.
////
//// Fields typed as `Dynamic` carry wire-originated values whose shape
//// varies by context. Use `gleam/dynamic/decode` to extract typed data.
//// These appear in catch-all events, pane identifiers, async results,
//// and effect responses.

import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

/// Keyboard modifier state. Fields match the Rust binary's modifier
/// report. `logo` is the Super/Windows key; `command` is the macOS
/// Command key. Both are sent by the binary -- on macOS they typically
/// track together.
pub type Modifiers {
  Modifiers(shift: Bool, ctrl: Bool, alt: Bool, logo: Bool, command: Bool)
}

/// No modifiers pressed.
pub fn modifiers_none() -> Modifiers {
  Modifiers(shift: False, ctrl: False, alt: False, logo: False, command: False)
}

/// Key location on the keyboard.
pub type KeyLocation {
  /// Default key position (main keyboard area).
  Standard
  /// Left-side modifier key (e.g. left Shift, left Ctrl).
  LeftSide
  /// Right-side modifier key (e.g. right Shift, right Ctrl).
  RightSide
  /// Key on the numeric keypad.
  Numpad
}

/// Mouse button identifier.
pub type MouseButton {
  /// Primary mouse button (usually left).
  LeftButton
  /// Secondary mouse button (usually right).
  RightButton
  /// Middle mouse button (scroll wheel click).
  MiddleButton
  /// Browser/mouse back button.
  BackButton
  /// Browser/mouse forward button.
  ForwardButton
  /// Any other mouse button, identified by name.
  OtherButton(String)
}

/// Scroll measurement unit.
pub type ScrollUnit {
  /// Scroll delta measured in lines (e.g. mouse wheel notches).
  Line
  /// Scroll delta measured in pixels (e.g. trackpad smooth scrolling).
  Pixel
}

/// Widget scroll viewport data. All measurements in logical pixels.
///
/// - `absolute_x/y`: current scroll offset from content origin
/// - `relative_x/y`: fractional position (0.0 = start, 1.0 = end)
/// - `bounds_width/height`: visible viewport dimensions
/// - `content_width/height`: total scrollable content dimensions
pub type ScrollData {
  ScrollData(
    absolute_x: Float,
    absolute_y: Float,
    relative_x: Float,
    relative_y: Float,
    bounds_width: Float,
    bounds_height: Float,
    content_width: Float,
    content_height: Float,
  )
}

/// Platform effect result from file dialogs, clipboard, notifications.
///
/// - `EffectOk(data)`: success; data shape depends on the effect kind
///   (e.g., file dialogs return a map with `"path"` or `"paths"` keys)
/// - `EffectCancelled`: user dismissed the dialog
/// - `EffectError(reason)`: operation failed (timeout, permission, etc.)
///
/// Use `gleam/dynamic/decode` to extract typed values from the Dynamic.
pub type EffectResult {
  /// The effect succeeded. Data shape depends on the effect kind.
  EffectOk(Dynamic)
  /// The user dismissed a dialog without making a selection.
  EffectCancelled
  /// The effect failed (timeout, permission denied, etc.).
  EffectError(Dynamic)
  /// The renderer backend doesn't support this effect kind.
  /// Distinct from cancelled (user action) and error (execution
  /// failure). The SDK checks for registered effect stubs when
  /// this is received.
  EffectUnsupported
}

/// All events from the plushie runtime.
pub type Event {

  // --- Widget events ---
  /// A widget was clicked. Fired by buttons and other clickable widgets.
  WidgetClick(window_id: String, id: String, scope: List(String))
  /// Text was entered into a text_input or text_editor widget.
  WidgetInput(window_id: String, id: String, scope: List(String), value: String)
  /// A text input was submitted (e.g. user pressed Enter).
  WidgetSubmit(
    window_id: String,
    id: String,
    scope: List(String),
    value: String,
  )
  /// A toggler or checkbox widget changed state.
  WidgetToggle(window_id: String, id: String, scope: List(String), value: Bool)
  /// An option was selected in a pick_list or combo_box widget.
  WidgetSelect(
    window_id: String,
    id: String,
    scope: List(String),
    value: String,
  )
  /// A slider value changed during dragging.
  WidgetSlide(window_id: String, id: String, scope: List(String), value: Float)
  /// A slider was released at its final value.
  WidgetSlideRelease(
    window_id: String,
    id: String,
    scope: List(String),
    value: Float,
  )
  /// Text was pasted into a text input or text editor.
  WidgetPaste(window_id: String, id: String, scope: List(String), value: String)
  /// A scrollable widget's viewport changed position.
  WidgetScroll(
    window_id: String,
    id: String,
    scope: List(String),
    data: ScrollData,
  )
  /// A collapsible or expandable widget was opened (e.g. combo_box
  /// dropdown, disclosure).
  WidgetOpen(window_id: String, id: String, scope: List(String))
  /// A collapsible or expandable widget was closed.
  WidgetClose(window_id: String, id: String, scope: List(String))
  /// An option in a pick_list or combo_box was hovered.
  WidgetOptionHovered(
    window_id: String,
    id: String,
    scope: List(String),
    value: String,
  )
  /// A sortable column header was clicked. The value is the column key.
  WidgetSort(window_id: String, id: String, scope: List(String), value: String)
  /// A registered key binding was triggered on a widget.
  WidgetKeyBinding(
    window_id: String,
    id: String,
    scope: List(String),
    value: String,
  )
  /// Catch-all for uncommon or future widget event types not covered
  /// by the typed constructors above.
  WidgetEvent(
    kind: String,
    window_id: String,
    id: String,
    scope: List(String),
    value: Dynamic,
    data: Dynamic,
  )

  // --- Key events ---
  /// A key was pressed. Includes modifier state, physical key info,
  /// and whether the event was already captured by a subscription.
  /// In multi-window apps, `window_id` identifies which window had
  /// focus when the key was pressed.
  KeyPress(
    window_id: String,
    key: String,
    /// The key value after applying modifier transforms. For example,
    /// Shift+a produces modified_key "A". Falls back to the unmodified
    /// key when no transform applies.
    modified_key: String,
    modifiers: Modifiers,
    physical_key: Option(String),
    location: KeyLocation,
    text: Option(String),
    repeat: Bool,
    /// Whether a subscription already consumed this event. Apps can
    /// check this to skip captured events and avoid double-processing.
    captured: Bool,
  )
  /// A key was released.
  KeyRelease(
    window_id: String,
    key: String,
    /// The key value after applying modifier transforms.
    modified_key: String,
    modifiers: Modifiers,
    physical_key: Option(String),
    location: KeyLocation,
    text: Option(String),
    /// Whether a subscription already consumed this event.
    captured: Bool,
  )

  // --- Window events ---
  // Window lifecycle events track the full lifecycle of a window from
  // creation through close. WindowCloseRequested gives the app a chance
  // to confirm or cancel; WindowClosed fires after the window is gone.
  /// A window finished opening. Includes initial size, position, and
  /// DPI scale factor.
  WindowOpened(
    window_id: String,
    width: Float,
    height: Float,
    position_x: Option(Float),
    position_y: Option(Float),
    scale_factor: Float,
  )
  /// A window was closed and destroyed.
  WindowClosed(window_id: String)
  /// The user requested to close a window (e.g. clicked the X button).
  /// The app can handle this to show a confirmation dialog or ignore it.
  WindowCloseRequested(window_id: String)
  /// A window was resized to new dimensions in logical pixels.
  WindowResized(window_id: String, width: Float, height: Float)
  /// A window was moved to a new screen position in logical pixels.
  WindowMoved(window_id: String, x: Float, y: Float)
  /// A window gained keyboard/input focus.
  WindowFocused(window_id: String)
  /// A window lost keyboard/input focus.
  WindowUnfocused(window_id: String)
  /// A window's DPI scale factor changed (e.g. moved between monitors).
  WindowRescaled(window_id: String, scale_factor: Float)
  /// A file is being dragged over a window (not yet dropped).
  WindowFileHovered(window_id: String, path: String)
  /// A file was dropped onto a window.
  WindowFileDropped(window_id: String, path: String)
  /// A previously hovered file drag left the window without dropping.
  WindowFilesHoveredLeft(window_id: String)

  // --- Mouse events (global subscriptions) ---
  // These fire from global mouse subscriptions, not from specific widgets.
  // The `captured` flag indicates whether a subscription already consumed
  // the event. In multi-window apps, `window_id` identifies which window
  // the cursor was over or interacting with.
  /// The mouse cursor moved to a new position.
  MouseMoved(window_id: String, x: Float, y: Float, captured: Bool)
  /// The mouse cursor entered the application window.
  MouseEntered(window_id: String, captured: Bool)
  /// The mouse cursor left the application window.
  MouseLeft(window_id: String, captured: Bool)
  /// A mouse button was pressed.
  MouseButtonPressed(window_id: String, button: MouseButton, captured: Bool)
  /// A mouse button was released.
  MouseButtonReleased(window_id: String, button: MouseButton, captured: Bool)
  /// The mouse wheel was scrolled. Unit indicates whether deltas are
  /// in lines (wheel notches) or pixels (trackpad).
  MouseWheelScrolled(
    window_id: String,
    delta_x: Float,
    delta_y: Float,
    unit: ScrollUnit,
    captured: Bool,
  )

  // --- Touch events ---
  // Touch events track individual fingers across their lifecycle:
  // pressed -> moved -> lifted. A `lost` event means the OS
  // interrupted tracking (e.g. a system gesture took over).
  /// A finger touched the screen.
  TouchPressed(window_id: String, finger_id: Int, x: Float, y: Float, captured: Bool)
  /// A finger moved on the screen.
  TouchMoved(window_id: String, finger_id: Int, x: Float, y: Float, captured: Bool)
  /// A finger was lifted from the screen.
  TouchLifted(window_id: String, finger_id: Int, x: Float, y: Float, captured: Bool)
  /// Touch tracking was interrupted by the OS.
  TouchLost(window_id: String, finger_id: Int, x: Float, y: Float, captured: Bool)

  // --- IME events ---
  // Input Method Editor events for CJK and other complex text input.
  // Lifecycle: opened -> preedit (one or more) -> commit -> closed.
  /// The IME composition session started.
  ImeOpened(window_id: String, captured: Bool)
  /// The IME is composing text. The cursor tuple is the selection
  /// range within the preedit string (byte offsets).
  ImePreedit(window_id: String, text: String, cursor: Option(#(Int, Int)), captured: Bool)
  /// The IME committed final text to the input.
  ImeCommit(window_id: String, text: String, captured: Bool)
  /// The IME composition session ended.
  ImeClosed(window_id: String, captured: Bool)

  // --- Modifier change ---
  /// The set of held modifier keys changed (Shift, Ctrl, Alt, etc.).
  /// Useful for updating UI hints without waiting for a key event.
  ModifiersChanged(window_id: String, modifiers: Modifiers, captured: Bool)

  // --- Sensor events ---
  /// A sensor widget detected that its rendered dimensions changed.
  /// Useful for responsive layouts that need to know actual size.
  SensorResize(
    window_id: String,
    id: String,
    scope: List(String),
    width: Float,
    height: Float,
  )

  // --- MouseArea events ---
  // Events from mouse_area wrapper widgets covering interactions that
  // standard button click handling does not (right/middle clicks,
  // hover, cursor movement, scroll).
  /// Right mouse button pressed inside a mouse_area widget.
  MouseAreaRightPress(window_id: String, id: String, scope: List(String))
  /// Right mouse button released inside a mouse_area widget.
  MouseAreaRightRelease(window_id: String, id: String, scope: List(String))
  /// Middle mouse button pressed inside a mouse_area widget.
  MouseAreaMiddlePress(window_id: String, id: String, scope: List(String))
  /// Middle mouse button released inside a mouse_area widget.
  MouseAreaMiddleRelease(window_id: String, id: String, scope: List(String))
  /// Double-click detected inside a mouse_area widget.
  MouseAreaDoubleClick(window_id: String, id: String, scope: List(String))
  /// Mouse cursor entered a mouse_area widget's bounds.
  MouseAreaEnter(window_id: String, id: String, scope: List(String))
  /// Mouse cursor exited a mouse_area widget's bounds.
  MouseAreaExit(window_id: String, id: String, scope: List(String))
  /// Mouse cursor moved within a mouse_area widget. Coordinates
  /// are in the widget's local space.
  MouseAreaMove(
    window_id: String,
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
  )
  /// Mouse wheel scrolled inside a mouse_area widget.
  MouseAreaScroll(
    window_id: String,
    id: String,
    scope: List(String),
    delta_x: Float,
    delta_y: Float,
  )

  // --- Canvas events ---
  // Canvas interaction events. Coordinates are in the canvas's local
  // coordinate space.
  /// A mouse button was pressed on a canvas widget.
  CanvasPress(
    window_id: String,
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
    button: String,
  )
  /// A mouse button was released on a canvas widget.
  CanvasRelease(
    window_id: String,
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
    button: String,
  )
  /// The mouse cursor moved within a canvas widget.
  CanvasMove(
    window_id: String,
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
  )
  /// The mouse wheel was scrolled within a canvas widget.
  CanvasScroll(
    window_id: String,
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
    delta_x: Float,
    delta_y: Float,
  )

  // --- Canvas shape events ---
  // Interactive shape events. These fire from shapes with an "interactive"
  // field inside a canvas widget. The id is the canvas widget's ID;
  // element_id identifies which interactive shape.
  /// Mouse entered an interactive canvas shape's bounds.
  CanvasElementEnter(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    x: Float,
    y: Float,
    captured: Bool,
  )
  /// Mouse left an interactive canvas shape's bounds.
  CanvasElementLeave(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    captured: Bool,
  )
  /// An interactive canvas shape was clicked.
  CanvasElementClick(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    x: Float,
    y: Float,
    button: String,
    captured: Bool,
  )
  /// An interactive canvas shape is being dragged.
  CanvasElementDrag(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    x: Float,
    y: Float,
    delta_x: Float,
    delta_y: Float,
    captured: Bool,
  )
  /// Drag ended on an interactive canvas shape.
  CanvasElementDragEnd(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    x: Float,
    y: Float,
    captured: Bool,
  )
  /// An interactive canvas shape received keyboard focus.
  CanvasElementFocused(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    captured: Bool,
  )
  /// An interactive element lost keyboard focus.
  CanvasElementBlurred(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
  )
  /// A focused canvas element received a key press (arrow_mode "none").
  CanvasElementKeyPress(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    key: String,
    modifiers: Modifiers,
    captured: Bool,
  )
  /// A focused canvas element received a key release (arrow_mode "none").
  CanvasElementKeyRelease(
    window_id: String,
    id: String,
    scope: List(String),
    element_id: String,
    key: String,
    modifiers: Modifiers,
    captured: Bool,
  )
  /// The canvas widget gained iced-level focus.
  CanvasFocused(window_id: String, id: String, scope: List(String))
  /// The canvas widget lost iced-level focus.
  CanvasBlurred(window_id: String, id: String, scope: List(String))
  /// A focusable group gained group-level focus.
  CanvasGroupFocused(
    window_id: String,
    id: String,
    scope: List(String),
    group_id: String,
  )
  /// A focusable group lost group-level focus.
  CanvasGroupBlurred(
    window_id: String,
    id: String,
    scope: List(String),
    group_id: String,
  )

  // --- Pane events ---
  // Events from pane_grid widgets when panes are resized, dragged,
  // or clicked.
  /// A pane_grid split divider was resized. The ratio is the new
  /// split position (0.0 to 1.0).
  PaneResized(
    window_id: String,
    id: String,
    scope: List(String),
    split: Dynamic,
    ratio: Float,
  )
  /// A pane was dragged in a pane_grid. The action is "picked",
  /// "dropped", or "canceled". Region and edge describe the drop target.
  PaneDragged(
    window_id: String,
    id: String,
    scope: List(String),
    pane: Dynamic,
    target: Dynamic,
    action: String,
    region: Option(String),
    edge: Option(String),
  )
  /// A pane was clicked in a pane_grid, making it the active pane.
  PaneClicked(window_id: String, id: String, scope: List(String), pane: Dynamic)
  /// Focus cycled to the next pane in a pane_grid (e.g. via Tab).
  PaneFocusCycle(
    window_id: String,
    id: String,
    scope: List(String),
    pane: Dynamic,
  )

  // --- System events ---
  /// Response to a GetSystemInfo query. The data Dynamic contains a
  /// map with keys like "system_name", "cpu_brand", "memory_total", etc.
  SystemInfo(tag: String, data: Dynamic)
  /// Response to a GetSystemTheme query. The theme is "light", "dark",
  /// or "none".
  SystemTheme(tag: String, theme: String)
  /// The OS theme preference changed at runtime.
  ThemeChanged(theme: String)
  /// An animation frame tick with a monotonic timestamp in milliseconds.
  /// Only fires when on_animation_frame is subscribed.
  AnimationFrame(timestamp: Int)
  /// All windows have been closed. Typically used to trigger app exit.
  AllWindowsClosed
  /// Response to a ListImages query with all registered image handles.
  ImageList(tag: String, handles: List(String))
  /// Response to a TreeHashQuery with the SHA-256 hash of the current
  /// renderer tree state.
  TreeHash(tag: String, hash: String)
  /// Response to a FindFocused query. The widget_id is None if no
  /// widget currently has focus.
  FocusedWidget(tag: String, widget_id: Option(String))

  // --- Timer ---
  /// A timer subscription fired. The tag identifies which subscription,
  /// and timestamp is monotonic milliseconds.
  TimerTick(tag: String, timestamp: Int)

  // --- Async/Stream ---
  /// Result from an Async command. Ok on success, Error on failure.
  /// The tag matches the tag passed to the originating Async command.
  AsyncResult(tag: String, result: Result(Dynamic, Dynamic))
  /// An intermediate value emitted by a Stream command. The tag
  /// matches the tag passed to the originating Stream command.
  StreamValue(tag: String, value: Dynamic)

  // --- Accessibility ---
  /// Request the system screen reader to announce the given text.
  Announce(text: String)

  // --- Error events ---
  /// Emitted when the tree contains duplicate node IDs after
  /// normalization. The details Dynamic contains a list of the
  /// offending IDs. Usually indicates a bug in the view function.
  DuplicateNodeIds(details: Dynamic)

  /// Renderer error for a widget command (wire key: "extension_command").
  WidgetCommandError(
    reason: String,
    node_id: Option(String),
    op: Option(String),
    extension: Option(String),
    message: Option(String),
  )

  /// Generic renderer error event.
  RendererError(id: String, data: Dynamic)

  /// Diagnostic message from the renderer (warnings, errors).
  Diagnostic(level: String, element_id: String, code: String, message: String)

  // --- Prop validation ---
  /// Emitted by the renderer when validate_props is enabled and a
  /// node has unexpected or mistyped properties. Indicates an SDK
  /// or extension bug -- app code cannot produce these through the
  /// typed builder API.
  PropValidation(node_id: String, node_type: String, warnings: List(String))

  // --- Effect response ---
  /// Response to a platform Effect command (file dialog, clipboard,
  /// notification). The request_id correlates with the originating
  /// Effect command's id field.
  EffectResponse(request_id: String, result: EffectResult)
}
