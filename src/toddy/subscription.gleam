//// Subscription types for ongoing event sources.
////
//// Return subscriptions from the `subscribe` callback. The runtime
//// diffs the list each cycle, starting new and stopping removed subs.

pub type Subscription {
  Every(interval_ms: Int, tag: String)
  OnKeyPress(tag: String)
  OnKeyRelease(tag: String)
  OnModifiersChanged(tag: String)
  OnWindowClose(tag: String)
  OnWindowEvent(tag: String)
  OnWindowOpen(tag: String)
  OnWindowResize(tag: String)
  OnWindowFocus(tag: String)
  OnWindowUnfocus(tag: String)
  OnWindowMove(tag: String)
  OnMouseMove(tag: String)
  OnMouseButton(tag: String)
  OnMouseScroll(tag: String)
  OnTouch(tag: String)
  OnIme(tag: String)
  OnThemeChange(tag: String)
  OnAnimationFrame(tag: String)
  OnFileDrop(tag: String)
  OnEvent(tag: String)
}

/// Unique identity for subscription diffing.
pub type SubscriptionKey {
  TimerKey(interval_ms: Int, tag: String)
  RendererKey(kind: String, tag: String)
}

// --- Constructor functions ---------------------------------------------------

pub fn every(interval_ms: Int, tag: String) -> Subscription {
  Every(interval_ms:, tag:)
}

pub fn on_key_press(tag: String) -> Subscription {
  OnKeyPress(tag:)
}

pub fn on_key_release(tag: String) -> Subscription {
  OnKeyRelease(tag:)
}

pub fn on_modifiers_changed(tag: String) -> Subscription {
  OnModifiersChanged(tag:)
}

pub fn on_window_close(tag: String) -> Subscription {
  OnWindowClose(tag:)
}

pub fn on_window_event(tag: String) -> Subscription {
  OnWindowEvent(tag:)
}

pub fn on_window_open(tag: String) -> Subscription {
  OnWindowOpen(tag:)
}

pub fn on_window_resize(tag: String) -> Subscription {
  OnWindowResize(tag:)
}

pub fn on_window_focus(tag: String) -> Subscription {
  OnWindowFocus(tag:)
}

pub fn on_window_unfocus(tag: String) -> Subscription {
  OnWindowUnfocus(tag:)
}

pub fn on_window_move(tag: String) -> Subscription {
  OnWindowMove(tag:)
}

pub fn on_mouse_move(tag: String) -> Subscription {
  OnMouseMove(tag:)
}

pub fn on_mouse_button(tag: String) -> Subscription {
  OnMouseButton(tag:)
}

pub fn on_mouse_scroll(tag: String) -> Subscription {
  OnMouseScroll(tag:)
}

pub fn on_touch(tag: String) -> Subscription {
  OnTouch(tag:)
}

pub fn on_ime(tag: String) -> Subscription {
  OnIme(tag:)
}

pub fn on_theme_change(tag: String) -> Subscription {
  OnThemeChange(tag:)
}

pub fn on_animation_frame(tag: String) -> Subscription {
  OnAnimationFrame(tag:)
}

pub fn on_file_drop(tag: String) -> Subscription {
  OnFileDrop(tag:)
}

pub fn on_event(tag: String) -> Subscription {
  OnEvent(tag:)
}

// --- Key, wire_kind, tag -----------------------------------------------------

/// Compute the unique key for a subscription (used for diffing).
pub fn key(sub: Subscription) -> SubscriptionKey {
  case sub {
    Every(interval_ms:, tag:) -> TimerKey(interval_ms:, tag:)
    OnKeyPress(tag:) -> RendererKey(kind: "on_key_press", tag:)
    OnKeyRelease(tag:) -> RendererKey(kind: "on_key_release", tag:)
    OnModifiersChanged(tag:) -> RendererKey(kind: "on_modifiers_changed", tag:)
    OnWindowClose(tag:) -> RendererKey(kind: "on_window_close", tag:)
    OnWindowEvent(tag:) -> RendererKey(kind: "on_window_event", tag:)
    OnWindowOpen(tag:) -> RendererKey(kind: "on_window_open", tag:)
    OnWindowResize(tag:) -> RendererKey(kind: "on_window_resize", tag:)
    OnWindowFocus(tag:) -> RendererKey(kind: "on_window_focus", tag:)
    OnWindowUnfocus(tag:) -> RendererKey(kind: "on_window_unfocus", tag:)
    OnWindowMove(tag:) -> RendererKey(kind: "on_window_move", tag:)
    OnMouseMove(tag:) -> RendererKey(kind: "on_mouse_move", tag:)
    OnMouseButton(tag:) -> RendererKey(kind: "on_mouse_button", tag:)
    OnMouseScroll(tag:) -> RendererKey(kind: "on_mouse_scroll", tag:)
    OnTouch(tag:) -> RendererKey(kind: "on_touch", tag:)
    OnIme(tag:) -> RendererKey(kind: "on_ime", tag:)
    OnThemeChange(tag:) -> RendererKey(kind: "on_theme_change", tag:)
    OnAnimationFrame(tag:) -> RendererKey(kind: "on_animation_frame", tag:)
    OnFileDrop(tag:) -> RendererKey(kind: "on_file_drop", tag:)
    OnEvent(tag:) -> RendererKey(kind: "on_event", tag:)
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
    OnKeyPress(tag:) -> tag
    OnKeyRelease(tag:) -> tag
    OnModifiersChanged(tag:) -> tag
    OnWindowClose(tag:) -> tag
    OnWindowEvent(tag:) -> tag
    OnWindowOpen(tag:) -> tag
    OnWindowResize(tag:) -> tag
    OnWindowFocus(tag:) -> tag
    OnWindowUnfocus(tag:) -> tag
    OnWindowMove(tag:) -> tag
    OnMouseMove(tag:) -> tag
    OnMouseButton(tag:) -> tag
    OnMouseScroll(tag:) -> tag
    OnTouch(tag:) -> tag
    OnIme(tag:) -> tag
    OnThemeChange(tag:) -> tag
    OnAnimationFrame(tag:) -> tag
    OnFileDrop(tag:) -> tag
    OnEvent(tag:) -> tag
  }
}
