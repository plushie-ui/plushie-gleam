//// Event types for the toddy wire protocol.
////
//// Events are delivered to the app's `update` function from the Rust
//// binary via the bridge actor. Pattern match on specific constructors
//// and use `_ ->` for unhandled events.
////
//// Widget events carry an `id` (the widget's local ID after scope
//// splitting) and a `scope` (list of ancestor container IDs, nearest
//// first). For example, a button "save" inside container "form" produces
//// `WidgetClick(id: "save", scope: ["form"])`.
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
  Standard
  LeftSide
  RightSide
  Numpad
}

/// Mouse button identifier.
pub type MouseButton {
  LeftButton
  RightButton
  MiddleButton
  BackButton
  ForwardButton
  OtherButton(String)
}

/// Scroll measurement unit.
pub type ScrollUnit {
  Line
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
  EffectOk(Dynamic)
  EffectCancelled
  EffectError(Dynamic)
}

/// All events from the toddy runtime.
pub type Event {
  // --- Widget events ---
  WidgetClick(id: String, scope: List(String))
  WidgetInput(id: String, scope: List(String), value: String)
  WidgetSubmit(id: String, scope: List(String), value: String)
  WidgetToggle(id: String, scope: List(String), value: Bool)
  WidgetSelect(id: String, scope: List(String), value: String)
  WidgetSlide(id: String, scope: List(String), value: Float)
  WidgetSlideRelease(id: String, scope: List(String), value: Float)
  WidgetPaste(id: String, scope: List(String), value: String)
  WidgetScroll(id: String, scope: List(String), data: ScrollData)
  WidgetOpen(id: String, scope: List(String))
  WidgetClose(id: String, scope: List(String))
  WidgetOptionHovered(id: String, scope: List(String), value: String)
  WidgetSort(id: String, scope: List(String), value: String)
  WidgetKeyBinding(id: String, scope: List(String), value: String)
  // Catch-all for uncommon or future widget event types
  WidgetEvent(
    kind: String,
    id: String,
    scope: List(String),
    value: Dynamic,
    data: Dynamic,
  )

  // --- Key events ---
  KeyPress(
    key: String,
    modifiers: Modifiers,
    physical_key: Option(String),
    location: KeyLocation,
    text: Option(String),
    repeat: Bool,
  )
  KeyRelease(
    key: String,
    modifiers: Modifiers,
    physical_key: Option(String),
    location: KeyLocation,
    text: Option(String),
  )

  // --- Window events ---
  WindowOpened(
    window_id: String,
    width: Float,
    height: Float,
    x: Float,
    y: Float,
    scale_factor: Float,
  )
  WindowClosed(window_id: String)
  WindowCloseRequested(window_id: String)
  WindowResized(window_id: String, width: Float, height: Float)
  WindowMoved(window_id: String, x: Float, y: Float)
  WindowFocused(window_id: String)
  WindowUnfocused(window_id: String)
  WindowRescaled(window_id: String, scale_factor: Float)
  WindowFileHovered(window_id: String, path: String)
  WindowFileDropped(window_id: String, path: String)
  WindowFilesHoveredLeft(window_id: String)

  // --- Mouse events (global subscriptions) ---
  MouseMoved(x: Float, y: Float)
  MouseEntered
  MouseLeft
  MouseButtonPressed(button: MouseButton, x: Float, y: Float)
  MouseButtonReleased(button: MouseButton, x: Float, y: Float)
  MouseWheelScrolled(delta_x: Float, delta_y: Float, unit: ScrollUnit)

  // --- Touch events ---
  TouchPressed(finger_id: Int, x: Float, y: Float)
  TouchMoved(finger_id: Int, x: Float, y: Float)
  TouchLifted(finger_id: Int, x: Float, y: Float)
  TouchLost(finger_id: Int, x: Float, y: Float)

  // --- IME events ---
  ImeOpened
  ImePreedit(text: String, cursor: Option(#(Int, Int)))
  ImeCommit(text: String)
  ImeClosed

  // --- Modifier change ---
  ModifiersChanged(modifiers: Modifiers)

  // --- Sensor events ---
  SensorResize(id: String, scope: List(String), width: Float, height: Float)

  // --- MouseArea events ---
  MouseAreaRightPress(id: String, scope: List(String), x: Float, y: Float)
  MouseAreaRightRelease(id: String, scope: List(String), x: Float, y: Float)
  MouseAreaMiddlePress(id: String, scope: List(String), x: Float, y: Float)
  MouseAreaMiddleRelease(id: String, scope: List(String), x: Float, y: Float)
  MouseAreaDoubleClick(id: String, scope: List(String), x: Float, y: Float)
  MouseAreaEnter(id: String, scope: List(String))
  MouseAreaExit(id: String, scope: List(String))
  MouseAreaMove(id: String, scope: List(String), x: Float, y: Float)
  MouseAreaScroll(
    id: String,
    scope: List(String),
    delta_x: Float,
    delta_y: Float,
  )

  // --- Canvas events ---
  CanvasPress(
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
    button: String,
  )
  CanvasRelease(
    id: String,
    scope: List(String),
    x: Float,
    y: Float,
    button: String,
  )
  CanvasMove(id: String, scope: List(String), x: Float, y: Float)
  CanvasScroll(id: String, scope: List(String), delta_x: Float, delta_y: Float)

  // --- Pane events ---
  PaneResized(id: String, scope: List(String), split: Dynamic, ratio: Float)
  PaneDragged(
    id: String,
    scope: List(String),
    pane: Dynamic,
    target: Dynamic,
    action: String,
    region: Option(String),
  )
  PaneClicked(id: String, scope: List(String), pane: Dynamic)
  PaneFocusCycle(id: String, scope: List(String), pane: Dynamic)

  // --- System events ---
  SystemInfo(tag: String, data: Dynamic)
  SystemTheme(tag: String, theme: String)
  ThemeChanged(theme: String)
  AnimationFrame(timestamp: Int)
  AllWindowsClosed
  ImageList(tag: String, handles: List(String))
  TreeHash(tag: String, hash: String)
  FocusedWidget(tag: String, widget_id: Option(String))

  // --- Timer ---
  TimerTick(tag: String, timestamp: Int)

  // --- Async/Stream ---
  AsyncResult(tag: String, result: Result(Dynamic, Dynamic))
  StreamValue(tag: String, value: Dynamic)

  // --- Effect response ---
  EffectResponse(request_id: String, result: EffectResult)
}
