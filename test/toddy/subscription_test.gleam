import toddy/subscription

pub fn every_constructor_test() {
  assert subscription.every(1000, "tick")
    == subscription.Every(interval_ms: 1000, tag: "tick")
}

pub fn on_key_press_constructor_test() {
  assert subscription.on_key_press("keys")
    == subscription.OnKeyPress(tag: "keys")
}

pub fn on_key_release_constructor_test() {
  assert subscription.on_key_release("keys")
    == subscription.OnKeyRelease(tag: "keys")
}

pub fn on_window_close_constructor_test() {
  assert subscription.on_window_close("wc")
    == subscription.OnWindowClose(tag: "wc")
}

pub fn on_mouse_move_constructor_test() {
  assert subscription.on_mouse_move("mm") == subscription.OnMouseMove(tag: "mm")
}

pub fn on_theme_change_constructor_test() {
  assert subscription.on_theme_change("tc")
    == subscription.OnThemeChange(tag: "tc")
}

pub fn on_event_constructor_test() {
  assert subscription.on_event("all") == subscription.OnEvent(tag: "all")
}

pub fn key_returns_timer_key_for_every_test() {
  let sub = subscription.every(500, "fast")
  assert subscription.key(sub)
    == subscription.TimerKey(interval_ms: 500, tag: "fast")
}

pub fn key_returns_renderer_key_for_on_key_press_test() {
  let sub = subscription.on_key_press("kb")
  assert subscription.key(sub)
    == subscription.RendererKey(kind: "on_key_press", tag: "kb")
}

pub fn key_returns_renderer_key_for_on_mouse_scroll_test() {
  let sub = subscription.on_mouse_scroll("scroll")
  assert subscription.key(sub)
    == subscription.RendererKey(kind: "on_mouse_scroll", tag: "scroll")
}

pub fn different_intervals_produce_different_keys_test() {
  let k1 = subscription.key(subscription.every(100, "t"))
  let k2 = subscription.key(subscription.every(200, "t"))
  assert k1 != k2
}

pub fn same_kind_and_tag_produce_equal_keys_test() {
  let k1 = subscription.key(subscription.on_key_press("kb"))
  let k2 = subscription.key(subscription.on_key_press("kb"))
  assert k1 == k2
}

pub fn wire_kind_every_test() {
  assert subscription.wire_kind(subscription.every(1000, "t")) == "every"
}

pub fn wire_kind_on_key_press_test() {
  assert subscription.wire_kind(subscription.on_key_press("k"))
    == "on_key_press"
}

pub fn wire_kind_on_window_resize_test() {
  assert subscription.wire_kind(subscription.on_window_resize("wr"))
    == "on_window_resize"
}

pub fn wire_kind_on_file_drop_test() {
  assert subscription.wire_kind(subscription.on_file_drop("fd"))
    == "on_file_drop"
}

pub fn wire_kind_on_animation_frame_test() {
  assert subscription.wire_kind(subscription.on_animation_frame("af"))
    == "on_animation_frame"
}

pub fn tag_extracts_from_every_test() {
  assert subscription.tag(subscription.every(100, "tick")) == "tick"
}

pub fn tag_extracts_from_on_key_press_test() {
  assert subscription.tag(subscription.on_key_press("kb")) == "kb"
}

pub fn tag_extracts_from_on_window_event_test() {
  assert subscription.tag(subscription.on_window_event("we")) == "we"
}

pub fn tag_extracts_from_on_touch_test() {
  assert subscription.tag(subscription.on_touch("tp")) == "tp"
}

pub fn tag_extracts_from_on_ime_test() {
  assert subscription.tag(subscription.on_ime("ime")) == "ime"
}
