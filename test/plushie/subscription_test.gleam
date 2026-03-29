import gleam/option.{None, Some}
import plushie/subscription

pub fn every_constructor_test() {
  assert subscription.every(1000, "tick")
    == subscription.Every(interval_ms: 1000, tag: "tick")
}

pub fn on_key_press_constructor_test() {
  assert subscription.on_key_press("keys")
    == subscription.Renderer(
    kind: subscription.KeyPress,
    tag: "keys",
    max_rate: None,
    window_id: None,
  )
}

pub fn on_key_release_constructor_test() {
  assert subscription.on_key_release("keys")
    == subscription.Renderer(
    kind: subscription.KeyRelease,
    tag: "keys",
    max_rate: None,
    window_id: None,
  )
}

pub fn on_window_close_constructor_test() {
  assert subscription.on_window_close("wc")
    == subscription.Renderer(
    kind: subscription.WindowClose,
    tag: "wc",
    max_rate: None,
    window_id: None,
  )
}

pub fn on_mouse_move_constructor_test() {
  assert subscription.on_mouse_move("mm")
    == subscription.Renderer(
    kind: subscription.MouseMove,
    tag: "mm",
    max_rate: None,
    window_id: None,
  )
}

pub fn on_theme_change_constructor_test() {
  assert subscription.on_theme_change("tc")
    == subscription.Renderer(
    kind: subscription.ThemeChange,
    tag: "tc",
    max_rate: None,
    window_id: None,
  )
}

pub fn on_event_constructor_test() {
  assert subscription.on_event("all")
    == subscription.Renderer(
    kind: subscription.AllEvents,
    tag: "all",
    max_rate: None,
    window_id: None,
  )
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

// --- max_rate ----------------------------------------------------------------

pub fn max_rate_defaults_to_none_test() {
  assert subscription.get_max_rate(subscription.on_mouse_move("mm")) == None
}

pub fn max_rate_none_for_timer_test() {
  assert subscription.get_max_rate(subscription.every(100, "t")) == None
}

pub fn set_max_rate_on_renderer_sub_test() {
  let sub = subscription.on_mouse_move("mm") |> subscription.set_max_rate(30)
  assert subscription.get_max_rate(sub) == Some(30)
}

pub fn set_max_rate_ignored_on_timer_test() {
  let sub = subscription.every(100, "t") |> subscription.set_max_rate(60)
  assert subscription.get_max_rate(sub) == None
}

pub fn set_max_rate_preserves_tag_test() {
  let sub =
    subscription.on_animation_frame("af") |> subscription.set_max_rate(60)
  assert subscription.tag(sub) == "af"
  assert subscription.get_max_rate(sub) == Some(60)
}

pub fn max_rate_does_not_affect_key_test() {
  let k1 = subscription.key(subscription.on_mouse_move("mm"))
  let k2 =
    subscription.key(
      subscription.on_mouse_move("mm") |> subscription.set_max_rate(30),
    )
  assert k1 == k2
}

// --- window_id ---------------------------------------------------------------

pub fn window_id_defaults_to_none_test() {
  assert subscription.get_window_id(subscription.on_key_press("kb")) == None
}

pub fn set_window_scopes_to_window_test() {
  let sub =
    subscription.on_key_press("kb") |> subscription.set_window("editor")
  assert subscription.get_window_id(sub) == Some("editor")
}

pub fn set_window_ignored_on_timer_test() {
  let sub = subscription.every(100, "t") |> subscription.set_window("editor")
  assert subscription.get_window_id(sub) == None
}

pub fn set_window_preserves_tag_and_rate_test() {
  let sub =
    subscription.on_mouse_move("mm")
    |> subscription.set_max_rate(60)
    |> subscription.set_window("main")
  assert subscription.tag(sub) == "mm"
  assert subscription.get_max_rate(sub) == Some(60)
  assert subscription.get_window_id(sub) == Some("main")
}

pub fn for_window_scopes_all_subscriptions_test() {
  let subs =
    subscription.for_window("editor", [
      subscription.on_key_press("keys"),
      subscription.on_mouse_move("mouse"),
    ])
  let assert [first, second] = subs
  assert subscription.get_window_id(first) == Some("editor")
  assert subscription.get_window_id(second) == Some("editor")
}
