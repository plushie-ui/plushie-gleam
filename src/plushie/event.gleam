//// Event types for the plushie wire protocol.
////
//// Events are delivered to the app's `update` function from the Rust
//// binary via the bridge actor. Pattern match on specific constructors
//// and use `_ ->` for unhandled events.
////
//// Window-bound widget events carry an `EventTarget` with a `window_id`,
//// an `id` (the widget's local ID after scope splitting), and a `scope`
//// (list of ancestor container IDs, nearest first). For example,
//// a button "save" inside container "form" in window "main"
//// produces `WidgetClick(target: EventTarget(window_id: "main", id: "save", scope: ["form", "main"]))`.
//// The window_id appears at the end of scope for global addressability;
//// use `| _` at the end of scope patterns to ignore it in single-window apps.
////
//// Subscription events (Key, Pointer, IME, Modifiers) also carry
//// a `window_id` identifying which window had focus when the event
//// fired. Pointer subscription events are delivered as Widget*
//// constructors with `id` set to the window_id and `scope` set to `[]`.
////
//// Fields typed as `Dynamic` carry wire-originated values whose shape
//// varies by context. Use `gleam/dynamic/decode` to extract typed data.
//// These appear in catch-all events, pane identifiers, async results,
//// and effect responses.

import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import plushie/event/types.{
  type EffectResult, type EventTarget, type KeyLocation, type Modifiers,
  type MouseButton, type PointerType, type ScrollData, type ScrollUnit,
}

/// All events from the plushie runtime.
pub type Event {

  // --- Widget events ---
  /// A widget was clicked. Fired by buttons and other clickable widgets.
  WidgetClick(target: EventTarget)
  /// Text was entered into a text_input or text_editor widget.
  WidgetInput(target: EventTarget, value: String)
  /// A text input was submitted (e.g. user pressed Enter).
  WidgetSubmit(target: EventTarget, value: String)
  /// A toggler or checkbox widget changed state.
  WidgetToggle(target: EventTarget, value: Bool)
  /// An option was selected in a pick_list or combo_box widget.
  WidgetSelect(target: EventTarget, value: String)
  /// A slider value changed during dragging.
  WidgetSlide(target: EventTarget, value: Float)
  /// A slider was released at its final value.
  WidgetSlideRelease(target: EventTarget, value: Float)
  /// Text was pasted into a text input or text editor.
  WidgetPaste(target: EventTarget, value: String)
  /// A scrollable widget's viewport changed position. The tense
  /// distinction captures semantics: "scrolled" is state ("content
  /// has scrolled"), vs WidgetScroll which is input ("user is scrolling").
  WidgetScrolled(target: EventTarget, data: ScrollData)
  /// A collapsible or expandable widget was opened (e.g. combo_box
  /// dropdown, disclosure).
  WidgetOpen(target: EventTarget)
  /// A collapsible or expandable widget was closed.
  WidgetClose(target: EventTarget)
  /// An option in a pick_list or combo_box was hovered.
  WidgetOptionHovered(target: EventTarget, value: String)
  /// A sortable column header was clicked. The value is the column key.
  WidgetSort(target: EventTarget, value: String)
  /// A registered key binding was triggered on a widget.
  WidgetKeyBinding(target: EventTarget, value: String)
  /// Catch-all for uncommon or future widget event types not covered
  /// by the typed constructors above.
  WidgetEvent(kind: String, target: EventTarget, value: Dynamic, data: Dynamic)

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

  // --- Unified pointer events ---
  // These replace the old canvas_*, mouse_area_*, sensor_*, mouse_*, and
  // touch_* events with a device-agnostic model. All pointer interactions
  // use the same event types regardless of source (widget, canvas, or
  // subscription). For subscription events: id = window_id, scope = [].
  // For widget events: id = widget id, scope = ancestor chain.
  /// A pointer button was pressed (mouse click, touch start, pen down).
  WidgetPress(
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
  WidgetRelease(
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
  WidgetMove(
    target: EventTarget,
    x: Float,
    y: Float,
    pointer: PointerType,
    finger: Option(Int),
    modifiers: Modifiers,
    captured: Bool,
  )
  /// A pointer wheel/scroll event. For subscription events, `unit`
  /// indicates line vs pixel granularity. For widget events, `unit`
  /// is None.
  WidgetScroll(
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
  /// A pointer entered a widget's bounds.
  WidgetEnter(target: EventTarget)
  /// A pointer exited a widget's bounds.
  WidgetExit(target: EventTarget)
  /// A double-click was detected.
  WidgetDoubleClick(
    target: EventTarget,
    x: Float,
    y: Float,
    pointer: PointerType,
    modifiers: Modifiers,
  )
  /// A widget was resized (e.g. sensor detecting layout changes).
  WidgetResize(target: EventTarget, width: Float, height: Float)

  // --- Generic element events ---
  // Focus, blur, drag, and key events. Apply to any focusable or
  // draggable element (canvas interactive groups, widgets, etc.).
  // Distinguished from global key events by having an id and scope.
  /// A focusable element gained focus.
  WidgetFocused(target: EventTarget)
  /// A focusable element lost focus.
  WidgetBlurred(target: EventTarget)
  /// A draggable element is being dragged.
  WidgetDrag(
    target: EventTarget,
    x: Float,
    y: Float,
    delta_x: Float,
    delta_y: Float,
  )
  /// A drag ended on a draggable element.
  WidgetDragEnd(target: EventTarget, x: Float, y: Float)
  /// A key was pressed on a focused element (widget-scoped).
  WidgetElementKeyPress(
    target: EventTarget,
    key: String,
    modifiers: Modifiers,
    text: Option(String),
  )
  /// A key was released on a focused element (widget-scoped).
  WidgetElementKeyRelease(
    target: EventTarget,
    key: String,
    modifiers: Modifiers,
  )
  /// A renderer-side transition completed on a widget.
  WidgetTransitionComplete(target: EventTarget, tag: String, prop: String)

  // --- IME events ---
  // Input Method Editor events for CJK and other complex text input.
  // Lifecycle: opened -> preedit (one or more) -> commit -> closed.
  /// The IME composition session started.
  ImeOpened(window_id: String, captured: Bool)
  /// The IME is composing text. The cursor tuple is the selection
  /// range within the preedit string (byte offsets).
  ImePreedit(
    window_id: String,
    text: String,
    cursor: Option(#(Int, Int)),
    captured: Bool,
  )
  /// The IME committed final text to the input.
  ImeCommit(window_id: String, text: String, captured: Bool)
  /// The IME composition session ended.
  ImeClosed(window_id: String, captured: Bool)

  // --- Modifier change ---
  /// The set of held modifier keys changed (Shift, Ctrl, Alt, etc.).
  /// Useful for updating UI hints without waiting for a key event.
  ModifiersChanged(window_id: String, modifiers: Modifiers, captured: Bool)

  // --- Pane events ---
  // Events from pane_grid widgets when panes are resized, dragged,
  // or clicked.
  /// A pane_grid split divider was resized. The ratio is the new
  /// split position (0.0 to 1.0).
  PaneResized(target: EventTarget, split: Dynamic, ratio: Float)
  /// A pane was dragged in a pane_grid. The action is "picked",
  /// "dropped", or "canceled". Region and edge describe the drop target.
  PaneDragged(
    target: EventTarget,
    pane: Dynamic,
    /// Note: `target` field name is taken by EventTarget, so the
    /// pane drag target is `drop_target`.
    drop_target: Dynamic,
    action: String,
    region: Option(String),
    edge: Option(String),
  )
  /// A pane was clicked in a pane_grid, making it the active pane.
  PaneClicked(target: EventTarget, pane: Dynamic)
  /// Focus cycled to the next pane in a pane_grid (e.g. via Tab).
  PaneFocusCycle(target: EventTarget, pane: Dynamic)

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
  /// Response to a Screenshot command with decoded pixel data.
  /// The hash is a SHA-256 digest of the pixel buffer. Width and
  /// height are in physical pixels. Pixels is raw RGBA bytes
  /// (base64 is decoded at the wire boundary).
  ScreenshotData(
    tag: String,
    hash: String,
    width: Int,
    height: Int,
    pixels: BitArray,
  )

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

  /// Renderer error for a widget command.
  CommandError(
    reason: String,
    id: Option(String),
    family: Option(String),
    widget_type: Option(String),
    message: Option(String),
  )

  /// Generic renderer error event.
  RendererError(id: String, data: Dynamic)

  /// Dispatched when the app's renderer restart callback crashes.
  /// Allows the app to react (show an error banner, reset to a safe
  /// state) instead of the failure being silently absorbed.
  RecoveryFailed(reason: Dynamic)

  /// Diagnostic message from the renderer (warnings, errors).
  Diagnostic(level: String, element_id: String, code: String, message: String)

  // --- Prop validation ---
  /// Emitted by the renderer when validate_props is enabled and a
  /// node has unexpected or mistyped properties. Indicates an SDK
  /// or native widget bug; app code cannot produce these through the
  /// typed builder API.
  PropValidation(node_id: String, node_type: String, warnings: List(String))

  // --- Effect response ---
  /// Response to a platform Effect command (file dialog, clipboard,
  /// notification). The tag matches the tag passed to the originating
  /// effect function for clean pattern matching.
  EffectResponse(tag: String, result: EffectResult)
}
