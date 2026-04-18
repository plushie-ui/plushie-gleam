//// Event types for the plushie wire protocol.
////
//// Events are delivered to the app's `update` function from the
//// renderer. The top-level `Event` type categorizes events into
//// families (Widget, Key, Window, etc.), each wrapping a dedicated
//// sub-type with typed fields.
////
//// ```gleam
//// case event {
////   Widget(Click(target: EventTarget(id: "inc", ..))) ->
////     #(Model(..model, count: model.count + 1), command.none())
////   Widget(Input(target: EventTarget(id: "name", ..), value: text)) ->
////     #(Model(..model, name: text), command.none())
////   Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) ->
////     #(Model(..model, menu_open: False), command.none())
////   _ -> #(model, command.none())
//// }
//// ```

import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option}
import gleam/string
import plushie/renderer_exit.{type RendererExit}

// ============================================================================
// Top-level Event
// ============================================================================

/// All events from the plushie runtime, grouped by category.
pub type Event {
  /// Widget interaction events (clicks, input, focus, pointer, etc.)
  Widget(WidgetEvent)
  /// Keyboard events from subscriptions.
  Key(KeyEvent)
  /// Window lifecycle events.
  Window(WindowEvent)
  /// Timer tick events.
  Timer(TimerEvent)
  /// Async task results.
  Async(AsyncEvent)
  /// Stream intermediate values.
  Stream(StreamEvent)
  /// Platform effect responses (file dialogs, clipboard, etc.)
  Effect(EffectEvent)
  /// System queries, theme changes, animation frames, etc.
  System(SystemEvent)
  /// IME (Input Method Editor) events.
  Ime(ImeEvent)
  /// Modifier key state changes.
  ModifiersChanged(ModifiersEvent)
  /// Errors from the renderer or runtime.
  Error(ErrorEvent)
}

// ============================================================================
// Widget events
// ============================================================================

/// Widget interaction events. Each variant carries an `EventTarget`
/// identifying which widget, in which scope, in which window.
pub type WidgetEvent {
  /// A widget was clicked.
  Click(target: EventTarget)
  /// Text was entered into a text_input or text_editor.
  Input(target: EventTarget, value: String)
  /// A text input was submitted (e.g. Enter pressed).
  Submit(target: EventTarget, value: String)
  /// A toggler or checkbox changed state.
  Toggle(target: EventTarget, value: Bool)
  /// An option was selected in a pick_list or combo_box.
  Select(target: EventTarget, value: String)
  /// A slider value changed during dragging.
  Slide(target: EventTarget, value: Float)
  /// A slider was released at its final value.
  SlideRelease(target: EventTarget, value: Float)
  /// Text was pasted into a text input or editor.
  Paste(target: EventTarget, value: String)
  /// A scrollable widget's viewport position changed.
  Scrolled(target: EventTarget, data: ScrollData)
  /// A collapsible widget was opened (e.g. combo_box dropdown).
  Open(target: EventTarget)
  /// A collapsible widget was closed.
  Close(target: EventTarget)
  /// An option in a pick_list or combo_box was hovered.
  OptionHovered(target: EventTarget, value: String)
  /// A sortable column header was clicked.
  Sort(target: EventTarget, value: String)
  /// A registered key binding was triggered on a widget.
  KeyBinding(target: EventTarget, value: String)
  /// A pointer button was pressed (mouse click, touch start).
  Press(
    target: EventTarget,
    x: Float,
    y: Float,
    button: MouseButton,
    pointer: PointerType,
    finger: Option(Int),
    modifiers: Modifiers,
    captured: Bool,
  )
  /// A pointer button was released.
  Release(
    target: EventTarget,
    x: Float,
    y: Float,
    button: MouseButton,
    pointer: PointerType,
    finger: Option(Int),
    modifiers: Modifiers,
    captured: Bool,
  )
  /// A pointer moved.
  Move(
    target: EventTarget,
    x: Float,
    y: Float,
    pointer: PointerType,
    finger: Option(Int),
    modifiers: Modifiers,
    captured: Bool,
  )
  /// A pointer wheel/scroll event.
  Scroll(
    target: EventTarget,
    x: Float,
    y: Float,
    delta_x: Float,
    delta_y: Float,
    pointer: PointerType,
    modifiers: Modifiers,
    unit: Option(ScrollUnit),
    captured: Bool,
  )
  /// A pointer entered a widget's bounds. Canvas elements include
  /// x/y coordinates; widget-level events leave them as None.
  Enter(target: EventTarget, x: Option(Float), y: Option(Float))
  /// A pointer exited a widget's bounds. Canvas elements may include
  /// x/y coordinates; widget-level events leave them as None.
  Exit(target: EventTarget, x: Option(Float), y: Option(Float))
  /// A double-click was detected.
  DoubleClick(
    target: EventTarget,
    x: Float,
    y: Float,
    pointer: PointerType,
    modifiers: Modifiers,
  )
  /// A widget was resized (e.g. sensor detecting layout changes).
  Resize(target: EventTarget, width: Float, height: Float)
  /// A focusable element gained focus.
  Focused(target: EventTarget)
  /// A focusable element lost focus.
  Blurred(target: EventTarget)
  /// A draggable element is being dragged.
  Drag(target: EventTarget, x: Float, y: Float, delta_x: Float, delta_y: Float)
  /// A drag ended on a draggable element.
  DragEnd(target: EventTarget, x: Float, y: Float)
  /// A renderer-side transition completed.
  TransitionComplete(target: EventTarget, tag: String, prop: String)
  /// A widget status event (used internally for focus tracking).
  Status(target: EventTarget, value: Dynamic)
  /// A pane grid split was resized.
  PaneResized(target: EventTarget, split: Dynamic, ratio: Float)
  /// A pane was dragged (drag-and-drop reorder).
  PaneDragged(
    target: EventTarget,
    pane: Dynamic,
    drop_target: Dynamic,
    action: String,
    region: Option(String),
    edge: Option(String),
  )
  /// A pane was clicked.
  PaneClicked(target: EventTarget, pane: Dynamic)
  /// A pane focus cycle was triggered (Tab navigation).
  PaneFocusCycle(target: EventTarget, pane: Dynamic)
  /// Catch-all for custom or future widget event families.
  CustomWidget(kind: String, target: EventTarget, value: Dynamic, data: Dynamic)
}

// ============================================================================
// Key events
// ============================================================================

/// Keyboard event type.
pub type KeyEventType {
  KeyPressed
  KeyReleased
}

/// A keyboard event from a subscription.
pub type KeyEvent {
  KeyEvent(
    event_type: KeyEventType,
    window_id: String,
    key: String,
    /// Key value after modifier transforms (e.g. Shift+a -> "A").
    modified_key: String,
    modifiers: Modifiers,
    physical_key: Option(String),
    location: KeyLocation,
    text: Option(String),
    repeat: Bool,
    /// Whether a widget already consumed this event.
    captured: Bool,
  )
}

// ============================================================================
// Window events
// ============================================================================

/// Window lifecycle event type.
pub type WindowEventType {
  Opened
  Closed
  CloseRequested
  Resized
  Moved
  WindowFocused
  WindowUnfocused
  Rescaled
  FileHovered
  FileDropped
  FilesHoveredLeft
}

/// A window lifecycle event. Optional fields carry data relevant to
/// the specific event type (e.g. width/height for Resized).
pub type WindowEvent {
  WindowEvent(
    event_type: WindowEventType,
    window_id: String,
    width: Option(Float),
    height: Option(Float),
    x: Option(Float),
    y: Option(Float),
    scale_factor: Option(Float),
    path: Option(String),
  )
}

// ============================================================================
// Timer / Async / Stream / Effect events
// ============================================================================

/// A timer subscription fired.
pub type TimerEvent {
  TimerEvent(tag: String, timestamp: Int)
}

/// An async task completed.
pub type AsyncEvent {
  AsyncEvent(tag: String, result: Result(Dynamic, Dynamic))
}

/// A stream emitted an intermediate value.
pub type StreamEvent {
  StreamEvent(tag: String, value: Dynamic)
}

/// A platform effect responded.
pub type EffectEvent {
  EffectEvent(tag: String, result: EffectResult)
}

// ============================================================================
// IME events
// ============================================================================

/// IME event type. Lifecycle: Opened -> Preedit* -> Commit -> Closed.
pub type ImeEventType {
  ImeOpened
  ImePreedit
  ImeCommit
  ImeClosed
}

/// An Input Method Editor event for CJK and complex text input.
pub type ImeEvent {
  ImeEvent(
    event_type: ImeEventType,
    window_id: String,
    text: Option(String),
    cursor: Option(#(Int, Int)),
    captured: Bool,
  )
}

// ============================================================================
// Modifier events
// ============================================================================

/// The set of held modifier keys changed.
pub type ModifiersEvent {
  ModifiersEvent(window_id: String, modifiers: Modifiers, captured: Bool)
}

// ============================================================================
// System events
// ============================================================================

/// System queries, theme changes, and runtime events.
pub type SystemEvent {
  /// Response to a GetSystemInfo query.
  SystemInfo(tag: String, value: Dynamic)
  /// Response to a GetSystemTheme query.
  SystemTheme(tag: String, theme: String)
  /// The OS theme preference changed at runtime.
  ThemeChanged(theme: String)
  /// An animation frame tick (monotonic ms).
  AnimationFrame(timestamp: Int)
  /// All windows have been closed.
  AllWindowsClosed
  /// Response to a ListImages query.
  ImageList(tag: String, handles: List(String))
  /// Response to a TreeHashQuery.
  TreeHash(tag: String, hash: String)
  /// Response to a FindFocused query.
  FocusedWidget(tag: String, widget_id: Option(String))
  /// Response to a Screenshot command with decoded pixel data.
  ScreenshotData(
    tag: String,
    hash: String,
    width: Int,
    height: Int,
    pixels: BitArray,
  )
  /// Screen reader announcement (headless/mock mode).
  Announce(text: String)
  /// The renderer recovery callback (on_renderer_exit) crashed.
  /// The app can use this to reset to a safe state or show an error.
  RecoveryFailed(kind: String, error: String, renderer_exit: RendererExit)
}

// ============================================================================
// Error events
// ============================================================================

/// Runtime and renderer errors.
pub type ErrorEvent {
  /// A widget command failed.
  CommandError(
    reason: String,
    id: Option(String),
    family: Option(String),
    widget_type: Option(String),
    message: Option(String),
  )
  /// A generic renderer error.
  RendererError(id: String, data: Dynamic)
  /// The tree contains duplicate node IDs after normalization.
  DuplicateNodeIds(details: Dynamic)
  /// A renderer diagnostic message (warnings, errors).
  ///
  /// `level` is `"info"`, `"warn"`, or `"error"`. `kind` identifies
  /// the typed diagnostic variant emitted by the renderer (e.g.
  /// `"font_family_not_found"`, `"duplicate_id"`). `data` carries the
  /// variant-specific payload fields as a dynamic value the app can
  /// decode when it wants richer context.
  Diagnostic(level: String, kind: String, data: Dynamic)
  /// Prop validation warning from the renderer.
  PropValidation(node_id: String, node_type: String, warnings: List(String))
}

// ============================================================================
// Shared types (merged from event/types)
// ============================================================================

// -- Event identity -----------------------------------------------------------

/// Widget identity: which widget, in which scope, in which window.
///
/// - `id`: the widget's local ID (last segment after scope splitting)
/// - `scope`: ancestor chain (nearest first, window_id last)
/// - `window_id`: the originating window
/// - `full`: the canonical wire ID (e.g. "main#form/email")
pub type EventTarget {
  EventTarget(window_id: String, id: String, scope: List(String), full: String)
}

/// Parse a wire-format scoped ID into (local_id, scope_list, window_id).
///
/// Handles the canonical `window#scope/path/id` format.
pub fn split_scoped_id(wire_id: String) -> #(String, List(String), String) {
  let #(window, path) = case string.split_once(wire_id, "#") {
    Ok(#(win, rest)) if win != "" -> #(win, rest)
    _ -> #("", wire_id)
  }
  let #(local, scope) = case string.split(path, "/") {
    [single] -> #(single, [])
    parts ->
      case list.reverse(parts) {
        [local, ..scope] -> #(local, scope)
        [] -> #("", [])
      }
  }
  #(local, scope, window)
}

/// Build an EventTarget from a wire-format scoped ID and explicit window ID.
///
/// Prefers the window extracted from the `#` in the ID. Falls back to the
/// explicit window_id parameter for backwards compatibility.
pub fn make_target(wire_id: String, window_id: String) -> EventTarget {
  let #(local, scope, window_from_id) = split_scoped_id(wire_id)
  let window = case window_from_id {
    "" -> window_id
    _ -> window_from_id
  }
  let scope = case window {
    "" -> scope
    _ -> list.append(scope, [window])
  }
  EventTarget(window_id: window, id: local, scope:, full: wire_id)
}

// -- Modifier state -----------------------------------------------------------

/// Keyboard modifier state.
pub type Modifiers {
  Modifiers(shift: Bool, ctrl: Bool, alt: Bool, logo: Bool, command: Bool)
}

/// No modifiers pressed.
pub fn modifiers_none() -> Modifiers {
  Modifiers(shift: False, ctrl: False, alt: False, logo: False, command: False)
}

// -- Key location -------------------------------------------------------------

/// Key location on the keyboard.
pub type KeyLocation {
  Standard
  LeftSide
  RightSide
  Numpad
}

// -- Pointer types ------------------------------------------------------------

/// Input device type for pointer events.
pub type PointerType {
  Mouse
  Touch
  Pen
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

// -- Scroll types -------------------------------------------------------------

/// Scroll measurement unit.
pub type ScrollUnit {
  Line
  Pixel
}

/// Widget scroll viewport data.
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

// -- Effect result ------------------------------------------------------------

/// Platform effect result.
pub type EffectResult {
  EffectOk(Dynamic)
  EffectCancelled
  EffectError(Dynamic)
  EffectUnsupported
}
