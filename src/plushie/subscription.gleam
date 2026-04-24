//// Subscription types for ongoing event sources.
////
//// Return subscriptions from the `subscribe` callback. The runtime
//// diffs the list each cycle using `key/1`: subscriptions with the
//// same key are considered identical and kept alive; new keys trigger
//// a subscribe message to the renderer, and removed keys trigger an
//// unsubscribe.
////
//// Timer subscriptions have a tag that appears in the TimerTick event,
//// giving each timer a stable identity.
////
//// Renderer subscriptions use a tag for internal management only; this
//// tag never appears in delivered events. Their identity is derived from
//// (kind, window_id).
////
//// Subscriptions can be scoped to a specific window using `set_window`
//// or `for_window`. Window-scoped subscriptions only receive events
//// from the given window; unscoped subscriptions receive events from
//// all windows.

import gleam/list
import gleam/option.{type Option, None, Some}

/// Event source kinds for renderer subscriptions.
pub type RendererSubKind {
  KeyPress
  KeyRelease
  ModifiersChanged
  WindowClose
  WindowEvent
  WindowOpen
  WindowResize
  WindowFocus
  WindowUnfocus
  WindowMove
  PointerMove
  PointerButton
  PointerScroll
  PointerTouch
  Ime
  ThemeChange
  AnimationFrame
  FileDrop
  /// Catch-all: receives all renderer events.
  AllEvents
}

pub type Subscription {
  /// Timer that fires every `interval_ms` milliseconds. Delivers a
  /// TimerTick event with the given tag to update.
  Every(interval_ms: Int, tag: String)
  /// A renderer event subscription. The renderer filters and delivers
  /// matching events to the runtime.
  Renderer(
    kind: RendererSubKind,
    max_rate: Option(Int),
    window_id: Option(String),
  )
}

/// Unique identity for subscription diffing.
pub type SubscriptionKey {
  TimerKey(interval_ms: Int, tag: String)
  /// Renderer sub identity is (kind, window_id). Two renderer subs
  /// of the same kind and window scope are the same subscription.
  RendererKey(kind: String, window_id: Option(String))
}

// --- Constructor functions ---------------------------------------------------

/// Timer that fires every `interval_ms` milliseconds. Delivers a
/// TimerTick event with the given tag to update.
pub fn every(interval_ms: Int, tag: String) -> Subscription {
  Every(interval_ms:, tag:)
}

/// Subscribe to key press events.
pub fn on_key_press() -> Subscription {
  Renderer(kind: KeyPress, max_rate: None, window_id: None)
}

/// Subscribe to key release events.
pub fn on_key_release() -> Subscription {
  Renderer(kind: KeyRelease, max_rate: None, window_id: None)
}

/// Subscribe to keyboard modifier state changes (shift, ctrl, alt, etc.).
pub fn on_modifiers_changed() -> Subscription {
  Renderer(kind: ModifiersChanged, max_rate: None, window_id: None)
}

/// Subscribe to window close request events.
pub fn on_window_close() -> Subscription {
  Renderer(kind: WindowClose, max_rate: None, window_id: None)
}

/// Subscribe to all window events (resize, move, focus, etc.). If both
/// this and a specific subscription (e.g. on_window_resize) are active,
/// matching events are delivered twice.
pub fn on_window_event() -> Subscription {
  Renderer(kind: WindowEvent, max_rate: None, window_id: None)
}

/// Subscribe to window open events.
pub fn on_window_open() -> Subscription {
  Renderer(kind: WindowOpen, max_rate: None, window_id: None)
}

/// Subscribe to window resize events.
pub fn on_window_resize() -> Subscription {
  Renderer(kind: WindowResize, max_rate: None, window_id: None)
}

/// Subscribe to window focus gained events.
pub fn on_window_focus() -> Subscription {
  Renderer(kind: WindowFocus, max_rate: None, window_id: None)
}

/// Subscribe to window focus lost events.
pub fn on_window_unfocus() -> Subscription {
  Renderer(kind: WindowUnfocus, max_rate: None, window_id: None)
}

/// Subscribe to window move events.
pub fn on_window_move() -> Subscription {
  Renderer(kind: WindowMove, max_rate: None, window_id: None)
}

/// Subscribe to pointer movement events (mouse or touch). Also delivers
/// enter and exit events for cursor enter/leave.
pub fn on_pointer_move() -> Subscription {
  Renderer(kind: PointerMove, max_rate: None, window_id: None)
}

/// Subscribe to pointer button press and release events (mouse or touch).
pub fn on_pointer_button() -> Subscription {
  Renderer(kind: PointerButton, max_rate: None, window_id: None)
}

/// Subscribe to pointer scroll events.
pub fn on_pointer_scroll() -> Subscription {
  Renderer(kind: PointerScroll, max_rate: None, window_id: None)
}

/// Subscribe to touch events (pressed, moved, lifted, lost).
pub fn on_pointer_touch() -> Subscription {
  Renderer(kind: PointerTouch, max_rate: None, window_id: None)
}

/// Subscribe to IME (Input Method Editor) events for international
/// text input.
pub fn on_ime() -> Subscription {
  Renderer(kind: Ime, max_rate: None, window_id: None)
}

/// Subscribe to system theme changes (light/dark mode).
pub fn on_theme_change() -> Subscription {
  Renderer(kind: ThemeChange, max_rate: None, window_id: None)
}

/// Subscribe to animation frame events (vsync ticks).
pub fn on_animation_frame() -> Subscription {
  Renderer(kind: AnimationFrame, max_rate: None, window_id: None)
}

/// Subscribe to file drop events. Also delivers file hovered and
/// hover-left events.
pub fn on_file_drop() -> Subscription {
  Renderer(kind: FileDrop, max_rate: None, window_id: None)
}

/// Subscribe to all renderer events (catch-all).
pub fn on_event() -> Subscription {
  Renderer(kind: AllEvents, max_rate: None, window_id: None)
}

// --- Modifiers ---------------------------------------------------------------

/// Set the max_rate on a renderer subscription. The renderer coalesces
/// events beyond this rate (events per second). Has no effect on timer
/// subscriptions.
///
/// A rate of zero means "track only, never emit": the renderer
/// tracks the event source but suppresses delivery entirely.
pub fn set_max_rate(sub: Subscription, rate: Int) -> Subscription {
  case sub {
    Every(..) -> sub
    Renderer(kind:, window_id:, ..) ->
      Renderer(kind:, max_rate: Some(rate), window_id:)
  }
}

/// Scope a subscription to a specific window. The renderer only
/// delivers events from the given window. Without a window scope,
/// events from all windows are delivered.
pub fn set_window(sub: Subscription, window_id: String) -> Subscription {
  case sub {
    Every(..) -> sub
    Renderer(kind:, max_rate:, ..) ->
      Renderer(kind:, max_rate:, window_id: Some(window_id))
  }
}

/// Scope a list of subscriptions to a specific window. Convenience
/// for applying `set_window` to each subscription.
///
/// ```gleam
/// subscription.for_window("editor", [
///   subscription.on_key_press(),
///   subscription.on_pointer_move() |> subscription.set_max_rate(60),
/// ])
/// ```
pub fn for_window(
  window_id: String,
  subscriptions: List(Subscription),
) -> List(Subscription) {
  list.map(subscriptions, set_window(_, window_id))
}

// --- Accessors ---------------------------------------------------------------

/// Compute the unique key for a subscription (used for diffing).
pub fn key(sub: Subscription) -> SubscriptionKey {
  case sub {
    Every(interval_ms:, tag:) -> TimerKey(interval_ms:, tag:)
    Renderer(kind:, window_id:, ..) ->
      RendererKey(kind: wire_kind_str(kind), window_id:)
  }
}

/// Wire format kind string for a subscription.
pub fn wire_kind(sub: Subscription) -> String {
  case sub {
    Every(..) -> "every"
    Renderer(kind:, ..) -> wire_kind_str(kind)
  }
}

/// Derive the wire tag sent to the renderer. The tag is the stable
/// identity for this subscription entry in the renderer's storage.
/// Window-scoped subscriptions include the window_id so they don't
/// collide with global subscriptions of the same kind.
pub fn wire_tag(sub: Subscription) -> String {
  case sub {
    Every(tag:, ..) -> tag
    Renderer(kind:, window_id: None, ..) -> wire_kind_str(kind)
    Renderer(kind:, window_id: Some(wid), ..) ->
      wire_kind_str(kind) <> ":" <> wid
  }
}

/// Get the tag from a timer subscription. Returns the tag that
/// appears in TimerTick events.
pub fn timer_tag(sub: Subscription) -> String {
  case sub {
    Every(tag:, ..) -> tag
    Renderer(..) ->
      panic as "timer_tag called on a renderer subscription (renderer subs have no user tag)"
  }
}

/// Get the max_rate from any subscription.
/// Returns None for timer subscriptions and renderer subs without a rate.
pub fn get_max_rate(sub: Subscription) -> Option(Int) {
  case sub {
    Every(..) -> None
    Renderer(max_rate:, ..) -> max_rate
  }
}

/// Get the window_id scope from a subscription.
/// Returns None for timer subscriptions and unscoped renderer subs.
pub fn get_window_id(sub: Subscription) -> Option(String) {
  case sub {
    Every(..) -> None
    Renderer(window_id:, ..) -> window_id
  }
}

// --- Internal ----------------------------------------------------------------

fn wire_kind_str(kind: RendererSubKind) -> String {
  case kind {
    KeyPress -> "on_key_press"
    KeyRelease -> "on_key_release"
    ModifiersChanged -> "on_modifiers_changed"
    WindowClose -> "on_window_close"
    WindowEvent -> "on_window_event"
    WindowOpen -> "on_window_open"
    WindowResize -> "on_window_resize"
    WindowFocus -> "on_window_focus"
    WindowUnfocus -> "on_window_unfocus"
    WindowMove -> "on_window_move"
    PointerMove -> "on_pointer_move"
    PointerButton -> "on_pointer_button"
    PointerScroll -> "on_pointer_scroll"
    PointerTouch -> "on_pointer_touch"
    Ime -> "on_ime"
    ThemeChange -> "on_theme_change"
    AnimationFrame -> "on_animation_frame"
    FileDrop -> "on_file_drop"
    AllEvents -> "on_event"
  }
}
