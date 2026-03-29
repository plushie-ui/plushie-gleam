//// Subscription types for ongoing event sources.
////
//// Return subscriptions from the `subscribe` callback. The runtime
//// diffs the list each cycle using `key/1`: subscriptions with the
//// same key are considered identical and kept alive; new keys trigger
//// a subscribe message to the renderer, and removed keys trigger an
//// unsubscribe. This means a subscription's identity is its
//// (kind, tag) pair -- changing max_rate on an existing key updates
//// the rate without re-subscribing.
////
//// Renderer subscriptions accept an optional `max_rate` that tells the
//// renderer to coalesce events beyond the given rate (events per second).
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
  MouseMove
  MouseButton
  MouseScroll
  Touch
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
    tag: String,
    max_rate: Option(Int),
    window_id: Option(String),
  )
}

/// Unique identity for subscription diffing.
pub type SubscriptionKey {
  TimerKey(interval_ms: Int, tag: String)
  RendererKey(kind: String, tag: String)
}

// --- Constructor functions ---------------------------------------------------

/// Timer that fires every `interval_ms` milliseconds. Delivers a
/// TimerTick event with the given tag to update.
pub fn every(interval_ms: Int, tag: String) -> Subscription {
  Every(interval_ms:, tag:)
}

/// Subscribe to key press events. Delivers KeyPress events to update.
pub fn on_key_press(tag: String) -> Subscription {
  Renderer(kind: KeyPress, tag:, max_rate: None, window_id: None)
}

/// Subscribe to key release events. Delivers KeyRelease events to update.
pub fn on_key_release(tag: String) -> Subscription {
  Renderer(kind: KeyRelease, tag:, max_rate: None, window_id: None)
}

/// Subscribe to keyboard modifier state changes (shift, ctrl, alt, etc.).
pub fn on_modifiers_changed(tag: String) -> Subscription {
  Renderer(kind: ModifiersChanged, tag:, max_rate: None, window_id: None)
}

/// Subscribe to window close request events.
pub fn on_window_close(tag: String) -> Subscription {
  Renderer(kind: WindowClose, tag:, max_rate: None, window_id: None)
}

/// Subscribe to all window events (resize, move, focus, etc.). If both
/// this and a specific subscription (e.g. on_window_resize) are active,
/// matching events are delivered twice.
pub fn on_window_event(tag: String) -> Subscription {
  Renderer(kind: WindowEvent, tag:, max_rate: None, window_id: None)
}

/// Subscribe to window open events.
pub fn on_window_open(tag: String) -> Subscription {
  Renderer(kind: WindowOpen, tag:, max_rate: None, window_id: None)
}

/// Subscribe to window resize events.
pub fn on_window_resize(tag: String) -> Subscription {
  Renderer(kind: WindowResize, tag:, max_rate: None, window_id: None)
}

/// Subscribe to window focus gained events.
pub fn on_window_focus(tag: String) -> Subscription {
  Renderer(kind: WindowFocus, tag:, max_rate: None, window_id: None)
}

/// Subscribe to window focus lost events.
pub fn on_window_unfocus(tag: String) -> Subscription {
  Renderer(kind: WindowUnfocus, tag:, max_rate: None, window_id: None)
}

/// Subscribe to window move events.
pub fn on_window_move(tag: String) -> Subscription {
  Renderer(kind: WindowMove, tag:, max_rate: None, window_id: None)
}

/// Subscribe to mouse movement events. Also delivers mouse entered
/// and mouse left events.
pub fn on_mouse_move(tag: String) -> Subscription {
  Renderer(kind: MouseMove, tag:, max_rate: None, window_id: None)
}

/// Subscribe to mouse button press and release events.
pub fn on_mouse_button(tag: String) -> Subscription {
  Renderer(kind: MouseButton, tag:, max_rate: None, window_id: None)
}

/// Subscribe to mouse scroll (wheel) events.
pub fn on_mouse_scroll(tag: String) -> Subscription {
  Renderer(kind: MouseScroll, tag:, max_rate: None, window_id: None)
}

/// Subscribe to touch events (pressed, moved, lifted, lost).
pub fn on_touch(tag: String) -> Subscription {
  Renderer(kind: Touch, tag:, max_rate: None, window_id: None)
}

/// Subscribe to IME (Input Method Editor) events for international
/// text input.
pub fn on_ime(tag: String) -> Subscription {
  Renderer(kind: Ime, tag:, max_rate: None, window_id: None)
}

/// Subscribe to system theme changes (light/dark mode).
pub fn on_theme_change(tag: String) -> Subscription {
  Renderer(kind: ThemeChange, tag:, max_rate: None, window_id: None)
}

/// Subscribe to animation frame events (vsync ticks).
pub fn on_animation_frame(tag: String) -> Subscription {
  Renderer(kind: AnimationFrame, tag:, max_rate: None, window_id: None)
}

/// Subscribe to file drop events. Also delivers file hovered and
/// hover-left events.
pub fn on_file_drop(tag: String) -> Subscription {
  Renderer(kind: FileDrop, tag:, max_rate: None, window_id: None)
}

/// Subscribe to all renderer events (catch-all).
pub fn on_event(tag: String) -> Subscription {
  Renderer(kind: AllEvents, tag:, max_rate: None, window_id: None)
}

// --- Modifiers ---------------------------------------------------------------

/// Set the max_rate on a renderer subscription. The renderer coalesces
/// events beyond this rate (events per second). Has no effect on timer
/// subscriptions.
pub fn set_max_rate(sub: Subscription, rate: Int) -> Subscription {
  case sub {
    Every(..) -> sub
    Renderer(kind:, tag:, window_id:, ..) ->
      Renderer(kind:, tag:, max_rate: Some(rate), window_id:)
  }
}

/// Scope a subscription to a specific window. The renderer only
/// delivers events from the given window. Without a window scope,
/// events from all windows are delivered.
pub fn set_window(sub: Subscription, window_id: String) -> Subscription {
  case sub {
    Every(..) -> sub
    Renderer(kind:, tag:, max_rate:, ..) ->
      Renderer(kind:, tag:, max_rate:, window_id: Some(window_id))
  }
}

/// Scope a list of subscriptions to a specific window. Convenience
/// for applying `set_window` to each subscription.
///
/// ```gleam
/// subscription.for_window("editor", [
///   subscription.on_key_press("editor_keys"),
///   subscription.on_mouse_move("editor_mouse") |> subscription.set_max_rate(60),
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
    Renderer(kind:, tag:, ..) -> RendererKey(kind: wire_kind_str(kind), tag:)
  }
}

/// Wire format kind string for a subscription.
pub fn wire_kind(sub: Subscription) -> String {
  case sub {
    Every(..) -> "every"
    Renderer(kind:, ..) -> wire_kind_str(kind)
  }
}

/// Get the tag from any subscription.
pub fn tag(sub: Subscription) -> String {
  case sub {
    Every(tag:, ..) -> tag
    Renderer(tag:, ..) -> tag
  }
}

/// Set the tag on any subscription.
pub fn set_tag(sub: Subscription, new_tag: String) -> Subscription {
  case sub {
    Every(interval_ms:, ..) -> Every(interval_ms:, tag: new_tag)
    Renderer(kind:, max_rate:, window_id:, ..) ->
      Renderer(kind:, tag: new_tag, max_rate:, window_id:)
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
    MouseMove -> "on_mouse_move"
    MouseButton -> "on_mouse_button"
    MouseScroll -> "on_mouse_scroll"
    Touch -> "on_touch"
    Ime -> "on_ime"
    ThemeChange -> "on_theme_change"
    AnimationFrame -> "on_animation_frame"
    FileDrop -> "on_file_drop"
    AllEvents -> "on_event"
  }
}
