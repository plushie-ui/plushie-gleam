//// Tests for the widget view cache (WidgetDef.cache_key).
////
//// When a widget defines cache_key, the normalizer should skip
//// calling `view` on subsequent renders if the dep is unchanged.

import gleam/dict
import gleam/dynamic
import gleam/option.{None, Some}
import plushie/canvas/shape
import plushie/node.{type Node}
import plushie/prop/length
import plushie/tree
import plushie/widget
import plushie/widget/canvas

pub type StaticProps {
  StaticProps(label: String)
}

// A widget that bumps a global counter every time its view is called.
// The counter lives in a process dictionary entry so the test can
// observe whether `view` was actually invoked across renders.
fn counting_def() -> widget.WidgetDef(Nil, StaticProps) {
  widget.WidgetDef(
    init: fn() { Nil },
    view: fn(id, props: StaticProps, _state) {
      bump_render_count()
      canvas.new(id, length.Fixed(10.0), length.Fixed(10.0))
      |> canvas.shapes([
        shape.text(0.0, 0.0, props.label, []),
      ])
      |> canvas.build()
    },
    handle_event: fn(_event, state) { #(widget.Ignored, state) },
    subscriptions: fn(_props, _state) { [] },
    cache_key: Some(fn(props: StaticProps, _state) {
      dynamic.string(props.label)
    }),
  )
}

fn no_cache_def() -> widget.WidgetDef(Nil, StaticProps) {
  widget.WidgetDef(
    init: fn() { Nil },
    view: fn(id, props: StaticProps, _state) {
      bump_render_count()
      canvas.new(id, length.Fixed(10.0), length.Fixed(10.0))
      |> canvas.shapes([
        shape.text(0.0, 0.0, props.label, []),
      ])
      |> canvas.build()
    },
    handle_event: fn(_event, state) { #(widget.Ignored, state) },
    subscriptions: fn(_props, _state) { [] },
    cache_key: None,
  )
}

fn placeholder(
  props: StaticProps,
  def: widget.WidgetDef(Nil, StaticProps),
) -> Node {
  // Wrap in a window so normalize_view's structural check passes.
  node.Node(
    id: "main",
    kind: "window",
    props: dict.new(),
    children: [widget.build(def, "w", props)],
    meta: dict.new(),
  )
}

pub fn cache_hit_skips_view_test() {
  let def = counting_def()
  let raw = placeholder(StaticProps(label: "hello"), def)
  reset_render_count()

  // First render: cold cache, view should be called once.
  let assert Ok(result1) =
    tree.normalize_view(raw, widget.empty_registry(), tree.empty_memo_cache())
  assert read_render_count() == 1

  // Second render with same props: cache hit, view should NOT be called again.
  let assert Ok(_result2) =
    tree.normalize_view(raw, result1.registry, result1.memo_cache)
  assert read_render_count() == 1
}

pub fn cache_miss_on_changed_props_re_renders_test() {
  let def = counting_def()
  let raw1 = placeholder(StaticProps(label: "hello"), def)
  let raw2 = placeholder(StaticProps(label: "world"), def)
  reset_render_count()

  let assert Ok(result1) =
    tree.normalize_view(raw1, widget.empty_registry(), tree.empty_memo_cache())
  assert read_render_count() == 1

  // Different props -> different cache_key -> miss -> view runs again.
  let assert Ok(_result2) =
    tree.normalize_view(raw2, result1.registry, result1.memo_cache)
  assert read_render_count() == 2
}

pub fn no_cache_key_renders_every_cycle_test() {
  let def = no_cache_def()
  let raw = placeholder(StaticProps(label: "hello"), def)
  reset_render_count()

  let assert Ok(result1) =
    tree.normalize_view(raw, widget.empty_registry(), tree.empty_memo_cache())
  assert read_render_count() == 1

  // Same props, but no cache_key opt-in: view always runs.
  let assert Ok(_result2) =
    tree.normalize_view(raw, result1.registry, result1.memo_cache)
  assert read_render_count() == 2
}

// -- Render counter via process dictionary ------------------------------------
//
// We use the BEAM process dictionary to count view invocations
// without threading state through the test. JS-target would need
// an equivalent mechanism; this test file is BEAM-only by virtue
// of the FFI.

@external(erlang, "plushie_test_ffi", "bump_render_count")
fn bump_render_count() -> Nil

@external(erlang, "plushie_test_ffi", "read_render_count")
fn read_render_count() -> Int

@external(erlang, "plushie_test_ffi", "reset_render_count")
fn reset_render_count() -> Nil
