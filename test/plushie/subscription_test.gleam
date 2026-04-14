import gleam/option.{None, Some}
import plushie/subscription

pub fn every_constructor_test() {
  assert subscription.every(1000, "tick")
    == subscription.Every(interval_ms: 1000, tag: "tick")
}

pub fn on_key_press_constructor_test() {
  assert subscription.on_key_press()
    == subscription.Renderer(
      kind: subscription.KeyPress,
      max_rate: None,
      window_id: None,
    )
}

pub fn on_key_release_constructor_test() {
  assert subscription.on_key_release()
    == subscription.Renderer(
      kind: subscription.KeyRelease,
      max_rate: None,
      window_id: None,
    )
}

pub fn on_window_close_constructor_test() {
  assert subscription.on_window_close()
    == subscription.Renderer(
      kind: subscription.WindowClose,
      max_rate: None,
      window_id: None,
    )
}

pub fn on_pointer_move_constructor_test() {
  assert subscription.on_pointer_move()
    == subscription.Renderer(
      kind: subscription.PointerMove,
      max_rate: None,
      window_id: None,
    )
}

pub fn on_theme_change_constructor_test() {
  assert subscription.on_theme_change()
    == subscription.Renderer(
      kind: subscription.ThemeChange,
      max_rate: None,
      window_id: None,
    )
}

pub fn on_event_constructor_test() {
  assert subscription.on_event()
    == subscription.Renderer(
      kind: subscription.AllEvents,
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
  let sub = subscription.on_key_press()
  assert subscription.key(sub)
    == subscription.RendererKey(kind: "on_key_press", window_id: None)
}

pub fn key_returns_renderer_key_with_window_test() {
  let sub = subscription.on_key_press() |> subscription.set_window("editor")
  assert subscription.key(sub)
    == subscription.RendererKey(kind: "on_key_press", window_id: Some("editor"))
}

pub fn different_intervals_produce_different_keys_test() {
  let k1 = subscription.key(subscription.every(100, "t"))
  let k2 = subscription.key(subscription.every(200, "t"))
  assert k1 != k2
}

pub fn same_kind_produce_equal_keys_test() {
  let k1 = subscription.key(subscription.on_key_press())
  let k2 = subscription.key(subscription.on_key_press())
  assert k1 == k2
}

pub fn different_window_scopes_produce_different_keys_test() {
  let k1 = subscription.key(subscription.on_key_press())
  let k2 =
    subscription.key(
      subscription.on_key_press() |> subscription.set_window("main"),
    )
  assert k1 != k2
}

pub fn wire_kind_every_test() {
  assert subscription.wire_kind(subscription.every(1000, "t")) == "every"
}

pub fn wire_kind_on_key_press_test() {
  assert subscription.wire_kind(subscription.on_key_press()) == "on_key_press"
}

pub fn wire_kind_on_window_resize_test() {
  assert subscription.wire_kind(subscription.on_window_resize())
    == "on_window_resize"
}

pub fn wire_kind_on_file_drop_test() {
  assert subscription.wire_kind(subscription.on_file_drop()) == "on_file_drop"
}

pub fn wire_kind_on_animation_frame_test() {
  assert subscription.wire_kind(subscription.on_animation_frame())
    == "on_animation_frame"
}

// --- wire_tag ----------------------------------------------------------------

pub fn wire_tag_timer_uses_tag_test() {
  assert subscription.wire_tag(subscription.every(100, "tick")) == "tick"
}

pub fn wire_tag_renderer_uses_kind_test() {
  assert subscription.wire_tag(subscription.on_key_press()) == "on_key_press"
}

pub fn wire_tag_renderer_with_window_includes_window_test() {
  let sub = subscription.on_key_press() |> subscription.set_window("editor")
  assert subscription.wire_tag(sub) == "on_key_press:editor"
}

pub fn wire_tag_renderer_global_has_no_colon_test() {
  assert subscription.wire_tag(subscription.on_pointer_move())
    == "on_pointer_move"
}

// --- timer_tag ---------------------------------------------------------------

pub fn timer_tag_extracts_from_every_test() {
  assert subscription.timer_tag(subscription.every(100, "tick")) == "tick"
}

// --- max_rate ----------------------------------------------------------------

pub fn max_rate_defaults_to_none_test() {
  assert subscription.get_max_rate(subscription.on_pointer_move()) == None
}

pub fn max_rate_none_for_timer_test() {
  assert subscription.get_max_rate(subscription.every(100, "t")) == None
}

pub fn set_max_rate_on_renderer_sub_test() {
  let sub = subscription.on_pointer_move() |> subscription.set_max_rate(30)
  assert subscription.get_max_rate(sub) == Some(30)
}

pub fn set_max_rate_ignored_on_timer_test() {
  let sub = subscription.every(100, "t") |> subscription.set_max_rate(60)
  assert subscription.get_max_rate(sub) == None
}

pub fn set_max_rate_preserves_kind_test() {
  let sub = subscription.on_animation_frame() |> subscription.set_max_rate(60)
  assert subscription.wire_kind(sub) == "on_animation_frame"
  assert subscription.get_max_rate(sub) == Some(60)
}

pub fn max_rate_does_not_affect_key_test() {
  let k1 = subscription.key(subscription.on_pointer_move())
  let k2 =
    subscription.key(
      subscription.on_pointer_move() |> subscription.set_max_rate(30),
    )
  assert k1 == k2
}

// --- window_id ---------------------------------------------------------------

pub fn window_id_defaults_to_none_test() {
  assert subscription.get_window_id(subscription.on_key_press()) == None
}

pub fn set_window_scopes_to_window_test() {
  let sub = subscription.on_key_press() |> subscription.set_window("editor")
  assert subscription.get_window_id(sub) == Some("editor")
}

pub fn set_window_ignored_on_timer_test() {
  let sub = subscription.every(100, "t") |> subscription.set_window("editor")
  assert subscription.get_window_id(sub) == None
}

pub fn set_window_preserves_rate_test() {
  let sub =
    subscription.on_pointer_move()
    |> subscription.set_max_rate(60)
    |> subscription.set_window("main")
  assert subscription.get_max_rate(sub) == Some(60)
  assert subscription.get_window_id(sub) == Some("main")
}

pub fn for_window_scopes_all_subscriptions_test() {
  let subs =
    subscription.for_window("editor", [
      subscription.on_key_press(),
      subscription.on_pointer_move(),
    ])
  let assert [first, second] = subs
  assert subscription.get_window_id(first) == Some("editor")
  assert subscription.get_window_id(second) == Some("editor")
}
