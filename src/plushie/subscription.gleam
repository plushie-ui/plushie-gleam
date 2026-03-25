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

import gleam/option.{type Option, None}

pub type Subscription {
  Every(interval_ms: Int, tag: String)
  OnKeyPress(tag: String, max_rate: Option(Int))
  OnKeyRelease(tag: String, max_rate: Option(Int))
  OnModifiersChanged(tag: String, max_rate: Option(Int))
  OnWindowClose(tag: String, max_rate: Option(Int))
  OnWindowEvent(tag: String, max_rate: Option(Int))
  OnWindowOpen(tag: String, max_rate: Option(Int))
  OnWindowResize(tag: String, max_rate: Option(Int))
  OnWindowFocus(tag: String, max_rate: Option(Int))
  OnWindowUnfocus(tag: String, max_rate: Option(Int))
  OnWindowMove(tag: String, max_rate: Option(Int))
  OnMouseMove(tag: String, max_rate: Option(Int))
  OnMouseButton(tag: String, max_rate: Option(Int))
  OnMouseScroll(tag: String, max_rate: Option(Int))
  OnTouch(tag: String, max_rate: Option(Int))
  OnIme(tag: String, max_rate: Option(Int))
  OnThemeChange(tag: String, max_rate: Option(Int))
  OnAnimationFrame(tag: String, max_rate: Option(Int))
  OnFileDrop(tag: String, max_rate: Option(Int))
  OnEvent(tag: String, max_rate: Option(Int))
}

/// Unique identity for subscription diffing.
pub type SubscriptionKey {
  TimerKey(interval_ms: Int, tag: String)
  RendererKey(kind: String, tag: String)
}

// --- Constructor functions ---------------------------------------------------

/// Timer that fires every `interval_ms` milliseconds. Delivers a
/// Timer event with the given tag to update.
pub fn every(interval_ms: Int, tag: String) -> Subscription {
  Every(interval_ms:, tag:)
}

/// Subscribe to key press events. Delivers KeyPress events to update.
/// The tag is for subscription management only.
pub fn on_key_press(tag: String) -> Subscription {
  OnKeyPress(tag:, max_rate: None)
}

/// Subscribe to key release events. Delivers KeyRelease events to update.
/// The tag is for subscription management only.
pub fn on_key_release(tag: String) -> Subscription {
  OnKeyRelease(tag:, max_rate: None)
}

/// Subscribe to keyboard modifier state changes (shift, ctrl, alt, etc.).
/// The tag is for subscription management only.
pub fn on_modifiers_changed(tag: String) -> Subscription {
  OnModifiersChanged(tag:, max_rate: None)
}

/// Subscribe to window close request events. The tag is for
/// subscription management only.
pub fn on_window_close(tag: String) -> Subscription {
  OnWindowClose(tag:, max_rate: None)
}

/// Subscribe to all window events (resize, move, focus, etc.). If both
/// this and a specific subscription (e.g. on_window_resize) are active,
/// matching events are delivered twice. The tag is for subscription
/// management only.
pub fn on_window_event(tag: String) -> Subscription {
  OnWindowEvent(tag:, max_rate: None)
}

/// Subscribe to window open events. The tag is for subscription
/// management only.
pub fn on_window_open(tag: String) -> Subscription {
  OnWindowOpen(tag:, max_rate: None)
}

/// Subscribe to window resize events. The tag is for subscription
/// management only.
pub fn on_window_resize(tag: String) -> Subscription {
  OnWindowResize(tag:, max_rate: None)
}

/// Subscribe to window focus gained events. The tag is for subscription
/// management only.
pub fn on_window_focus(tag: String) -> Subscription {
  OnWindowFocus(tag:, max_rate: None)
}

/// Subscribe to window focus lost events. The tag is for subscription
/// management only.
pub fn on_window_unfocus(tag: String) -> Subscription {
  OnWindowUnfocus(tag:, max_rate: None)
}

/// Subscribe to window move events. The tag is for subscription
/// management only.
pub fn on_window_move(tag: String) -> Subscription {
  OnWindowMove(tag:, max_rate: None)
}

/// Subscribe to mouse movement events. Also delivers mouse entered
/// and mouse left events. The tag is for subscription management only.
pub fn on_mouse_move(tag: String) -> Subscription {
  OnMouseMove(tag:, max_rate: None)
}

/// Subscribe to mouse button press and release events. The tag is for
/// subscription management only.
pub fn on_mouse_button(tag: String) -> Subscription {
  OnMouseButton(tag:, max_rate: None)
}

/// Subscribe to mouse scroll (wheel) events. The tag is for
/// subscription management only.
pub fn on_mouse_scroll(tag: String) -> Subscription {
  OnMouseScroll(tag:, max_rate: None)
}

/// Subscribe to touch events (pressed, moved, lifted, lost). The tag
/// is for subscription management only.
pub fn on_touch(tag: String) -> Subscription {
  OnTouch(tag:, max_rate: None)
}

/// Subscribe to IME (Input Method Editor) events for international
/// text input. The tag is for subscription management only.
pub fn on_ime(tag: String) -> Subscription {
  OnIme(tag:, max_rate: None)
}

/// Subscribe to system theme changes (light/dark mode). The tag is
/// for subscription management only.
pub fn on_theme_change(tag: String) -> Subscription {
  OnThemeChange(tag:, max_rate: None)
}

/// Subscribe to animation frame events (vsync ticks). The tag is for
/// subscription management only.
pub fn on_animation_frame(tag: String) -> Subscription {
  OnAnimationFrame(tag:, max_rate: None)
}

/// Subscribe to file drop events. Also delivers file hovered and
/// hover-left events. The tag is for subscription management only.
pub fn on_file_drop(tag: String) -> Subscription {
  OnFileDrop(tag:, max_rate: None)
}

/// Subscribe to all renderer events (catch-all). The tag is for
/// subscription management only.
pub fn on_event(tag: String) -> Subscription {
  OnEvent(tag:, max_rate: None)
}

/// Set the max_rate on a renderer subscription. The renderer coalesces
/// events beyond this rate. A rate of 0 means subscribe but never emit.
/// Has no effect on timer subscriptions.
pub fn set_max_rate(sub: Subscription, rate: Int) -> Subscription {
  case sub {
    Every(..) -> sub
    OnKeyPress(tag:, ..) -> OnKeyPress(tag:, max_rate: option.Some(rate))
    OnKeyRelease(tag:, ..) -> OnKeyRelease(tag:, max_rate: option.Some(rate))
    OnModifiersChanged(tag:, ..) ->
      OnModifiersChanged(tag:, max_rate: option.Some(rate))
    OnWindowClose(tag:, ..) -> OnWindowClose(tag:, max_rate: option.Some(rate))
    OnWindowEvent(tag:, ..) -> OnWindowEvent(tag:, max_rate: option.Some(rate))
    OnWindowOpen(tag:, ..) -> OnWindowOpen(tag:, max_rate: option.Some(rate))
    OnWindowResize(tag:, ..) ->
      OnWindowResize(tag:, max_rate: option.Some(rate))
    OnWindowFocus(tag:, ..) -> OnWindowFocus(tag:, max_rate: option.Some(rate))
    OnWindowUnfocus(tag:, ..) ->
      OnWindowUnfocus(tag:, max_rate: option.Some(rate))
    OnWindowMove(tag:, ..) -> OnWindowMove(tag:, max_rate: option.Some(rate))
    OnMouseMove(tag:, ..) -> OnMouseMove(tag:, max_rate: option.Some(rate))
    OnMouseButton(tag:, ..) -> OnMouseButton(tag:, max_rate: option.Some(rate))
    OnMouseScroll(tag:, ..) -> OnMouseScroll(tag:, max_rate: option.Some(rate))
    OnTouch(tag:, ..) -> OnTouch(tag:, max_rate: option.Some(rate))
    OnIme(tag:, ..) -> OnIme(tag:, max_rate: option.Some(rate))
    OnThemeChange(tag:, ..) -> OnThemeChange(tag:, max_rate: option.Some(rate))
    OnAnimationFrame(tag:, ..) ->
      OnAnimationFrame(tag:, max_rate: option.Some(rate))
    OnFileDrop(tag:, ..) -> OnFileDrop(tag:, max_rate: option.Some(rate))
    OnEvent(tag:, ..) -> OnEvent(tag:, max_rate: option.Some(rate))
  }
}

// --- Key, wire_kind, tag, max_rate -------------------------------------------

/// Compute the unique key for a subscription (used for diffing).
pub fn key(sub: Subscription) -> SubscriptionKey {
  case sub {
    Every(interval_ms:, tag:) -> TimerKey(interval_ms:, tag:)
    OnKeyPress(tag:, ..) -> RendererKey(kind: "on_key_press", tag:)
    OnKeyRelease(tag:, ..) -> RendererKey(kind: "on_key_release", tag:)
    OnModifiersChanged(tag:, ..) ->
      RendererKey(kind: "on_modifiers_changed", tag:)
    OnWindowClose(tag:, ..) -> RendererKey(kind: "on_window_close", tag:)
    OnWindowEvent(tag:, ..) -> RendererKey(kind: "on_window_event", tag:)
    OnWindowOpen(tag:, ..) -> RendererKey(kind: "on_window_open", tag:)
    OnWindowResize(tag:, ..) -> RendererKey(kind: "on_window_resize", tag:)
    OnWindowFocus(tag:, ..) -> RendererKey(kind: "on_window_focus", tag:)
    OnWindowUnfocus(tag:, ..) -> RendererKey(kind: "on_window_unfocus", tag:)
    OnWindowMove(tag:, ..) -> RendererKey(kind: "on_window_move", tag:)
    OnMouseMove(tag:, ..) -> RendererKey(kind: "on_mouse_move", tag:)
    OnMouseButton(tag:, ..) -> RendererKey(kind: "on_mouse_button", tag:)
    OnMouseScroll(tag:, ..) -> RendererKey(kind: "on_mouse_scroll", tag:)
    OnTouch(tag:, ..) -> RendererKey(kind: "on_touch", tag:)
    OnIme(tag:, ..) -> RendererKey(kind: "on_ime", tag:)
    OnThemeChange(tag:, ..) -> RendererKey(kind: "on_theme_change", tag:)
    OnAnimationFrame(tag:, ..) -> RendererKey(kind: "on_animation_frame", tag:)
    OnFileDrop(tag:, ..) -> RendererKey(kind: "on_file_drop", tag:)
    OnEvent(tag:, ..) -> RendererKey(kind: "on_event", tag:)
  }
}

/// Wire format kind string for a subscription.
pub fn wire_kind(sub: Subscription) -> String {
  case sub {
    Every(..) -> "every"
    OnKeyPress(..) -> "on_key_press"
    OnKeyRelease(..) -> "on_key_release"
    OnModifiersChanged(..) -> "on_modifiers_changed"
    OnWindowClose(..) -> "on_window_close"
    OnWindowEvent(..) -> "on_window_event"
    OnWindowOpen(..) -> "on_window_open"
    OnWindowResize(..) -> "on_window_resize"
    OnWindowFocus(..) -> "on_window_focus"
    OnWindowUnfocus(..) -> "on_window_unfocus"
    OnWindowMove(..) -> "on_window_move"
    OnMouseMove(..) -> "on_mouse_move"
    OnMouseButton(..) -> "on_mouse_button"
    OnMouseScroll(..) -> "on_mouse_scroll"
    OnTouch(..) -> "on_touch"
    OnIme(..) -> "on_ime"
    OnThemeChange(..) -> "on_theme_change"
    OnAnimationFrame(..) -> "on_animation_frame"
    OnFileDrop(..) -> "on_file_drop"
    OnEvent(..) -> "on_event"
  }
}

/// Get the tag from any subscription.
pub fn tag(sub: Subscription) -> String {
  case sub {
    Every(tag:, ..) -> tag
    OnKeyPress(tag:, ..) -> tag
    OnKeyRelease(tag:, ..) -> tag
    OnModifiersChanged(tag:, ..) -> tag
    OnWindowClose(tag:, ..) -> tag
    OnWindowEvent(tag:, ..) -> tag
    OnWindowOpen(tag:, ..) -> tag
    OnWindowResize(tag:, ..) -> tag
    OnWindowFocus(tag:, ..) -> tag
    OnWindowUnfocus(tag:, ..) -> tag
    OnWindowMove(tag:, ..) -> tag
    OnMouseMove(tag:, ..) -> tag
    OnMouseButton(tag:, ..) -> tag
    OnMouseScroll(tag:, ..) -> tag
    OnTouch(tag:, ..) -> tag
    OnIme(tag:, ..) -> tag
    OnThemeChange(tag:, ..) -> tag
    OnAnimationFrame(tag:, ..) -> tag
    OnFileDrop(tag:, ..) -> tag
    OnEvent(tag:, ..) -> tag
  }
}

/// Set the tag on any subscription.
pub fn set_tag(sub: Subscription, new_tag: String) -> Subscription {
  case sub {
    Every(interval_ms:, ..) -> Every(interval_ms:, tag: new_tag)
    OnKeyPress(max_rate:, ..) -> OnKeyPress(tag: new_tag, max_rate:)
    OnKeyRelease(max_rate:, ..) -> OnKeyRelease(tag: new_tag, max_rate:)
    OnModifiersChanged(max_rate:, ..) ->
      OnModifiersChanged(tag: new_tag, max_rate:)
    OnWindowClose(max_rate:, ..) -> OnWindowClose(tag: new_tag, max_rate:)
    OnWindowEvent(max_rate:, ..) -> OnWindowEvent(tag: new_tag, max_rate:)
    OnWindowOpen(max_rate:, ..) -> OnWindowOpen(tag: new_tag, max_rate:)
    OnWindowResize(max_rate:, ..) -> OnWindowResize(tag: new_tag, max_rate:)
    OnWindowFocus(max_rate:, ..) -> OnWindowFocus(tag: new_tag, max_rate:)
    OnWindowUnfocus(max_rate:, ..) -> OnWindowUnfocus(tag: new_tag, max_rate:)
    OnWindowMove(max_rate:, ..) -> OnWindowMove(tag: new_tag, max_rate:)
    OnMouseMove(max_rate:, ..) -> OnMouseMove(tag: new_tag, max_rate:)
    OnMouseButton(max_rate:, ..) -> OnMouseButton(tag: new_tag, max_rate:)
    OnMouseScroll(max_rate:, ..) -> OnMouseScroll(tag: new_tag, max_rate:)
    OnTouch(max_rate:, ..) -> OnTouch(tag: new_tag, max_rate:)
    OnIme(max_rate:, ..) -> OnIme(tag: new_tag, max_rate:)
    OnThemeChange(max_rate:, ..) -> OnThemeChange(tag: new_tag, max_rate:)
    OnAnimationFrame(max_rate:, ..) -> OnAnimationFrame(tag: new_tag, max_rate:)
    OnFileDrop(max_rate:, ..) -> OnFileDrop(tag: new_tag, max_rate:)
    OnEvent(max_rate:, ..) -> OnEvent(tag: new_tag, max_rate:)
  }
}

/// Get the max_rate from any subscription.
/// Returns None for timer subscriptions and renderer subs without a rate.
pub fn get_max_rate(sub: Subscription) -> Option(Int) {
  case sub {
    Every(..) -> None
    OnKeyPress(max_rate:, ..) -> max_rate
    OnKeyRelease(max_rate:, ..) -> max_rate
    OnModifiersChanged(max_rate:, ..) -> max_rate
    OnWindowClose(max_rate:, ..) -> max_rate
    OnWindowEvent(max_rate:, ..) -> max_rate
    OnWindowOpen(max_rate:, ..) -> max_rate
    OnWindowResize(max_rate:, ..) -> max_rate
    OnWindowFocus(max_rate:, ..) -> max_rate
    OnWindowUnfocus(max_rate:, ..) -> max_rate
    OnWindowMove(max_rate:, ..) -> max_rate
    OnMouseMove(max_rate:, ..) -> max_rate
    OnMouseButton(max_rate:, ..) -> max_rate
    OnMouseScroll(max_rate:, ..) -> max_rate
    OnTouch(max_rate:, ..) -> max_rate
    OnIme(max_rate:, ..) -> max_rate
    OnThemeChange(max_rate:, ..) -> max_rate
    OnAnimationFrame(max_rate:, ..) -> max_rate
    OnFileDrop(max_rate:, ..) -> max_rate
    OnEvent(max_rate:, ..) -> max_rate
  }
}
