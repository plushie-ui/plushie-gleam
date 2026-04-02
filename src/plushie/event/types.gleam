//// Shared types for the event system.
////
//// These types are used by event constructors, decoders, and other modules
//// that need to reference event field types without importing the full
//// Event union. Defined here to avoid import cycles between event.gleam
//// and modules like prop/pointer.gleam.

import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/string

// -- Event identity -----------------------------------------------------------

/// Common identity for scoped widget events: which widget, in which
/// container chain, in which window.
///
/// All widget-bound events carry a target. The `id` is the widget's local
/// ID after scope splitting, `scope` is the ancestor chain (nearest first,
/// window_id last), and `window_id` is the originating window.
///
/// Pattern matching:
/// ```gleam
/// WidgetClick(target: EventTarget(id: "save", ..), ..) -> ...
/// WidgetPress(target: EventTarget(id: "canvas", scope: ["editor", ..], ..), ..) -> ...
/// ```
pub type EventTarget {
  EventTarget(window_id: String, id: String, scope: List(String))
}

/// Split a wire-format scoped ID into (local_id, scope_list).
///
/// The wire ID uses `/` as the scope separator: `"form/save"` becomes
/// `("save", ["form"])`. The scope list is reversed (nearest ancestor
/// first).
pub fn split_scoped_id(wire_id: String) -> #(String, List(String)) {
  case string.split(wire_id, "/") {
    [local] -> #(local, [])
    parts ->
      case list.reverse(parts) {
        [local, ..scope] -> #(local, scope)
        [] -> #("", [])
      }
  }
}

/// Build an EventTarget from a wire-format scoped ID and window ID.
///
/// Splits the wire ID into local ID and scope, then appends the window_id
/// to the scope chain as the outermost ancestor (when non-empty).
pub fn make_target(wire_id: String, window_id: String) -> EventTarget {
  let #(local, scope) = split_scoped_id(wire_id)
  let scope = case window_id {
    "" -> scope
    _ -> list.append(scope, [window_id])
  }
  EventTarget(window_id:, id: local, scope:)
}

// -- Modifier state -----------------------------------------------------------

/// Keyboard modifier state. Fields match the Rust binary's modifier
/// report. `logo` is the Super/Windows key; `command` is the macOS
/// Command key. Both are sent by the binary (on macOS they typically
/// track together).
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
  /// Default key position (main keyboard area).
  Standard
  /// Left-side modifier key (e.g. left Shift, left Ctrl).
  LeftSide
  /// Right-side modifier key (e.g. right Shift, right Ctrl).
  RightSide
  /// Key on the numeric keypad.
  Numpad
}

// -- Pointer types ------------------------------------------------------------

/// Input device type for pointer events.
pub type PointerType {
  /// Standard mouse input.
  Mouse
  /// Touchscreen finger.
  Touch
  /// Stylus or pen tablet.
  Pen
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

// -- Scroll types -------------------------------------------------------------

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

// -- Effect result ------------------------------------------------------------

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
