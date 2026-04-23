import gleam/dict
import gleam/list
import gleeunit/should
import plushie/animation/easing.{
  EaseIn, EaseInOut, EaseOut, EaseOutElastic, Linear,
}
import plushie/animation/spring
import plushie/animation/tween
import plushie/node.{DictVal, FloatVal, StringVal}

pub fn new_creates_unstarted_animation_test() {
  let anim = tween.new(0.0, 100.0, 1000, Linear)
  should.equal(tween.value(anim), 0.0)
  should.equal(tween.is_finished(anim), False)
}

pub fn start_sets_initial_value_test() {
  let anim =
    tween.new(10.0, 50.0, 500, Linear)
    |> tween.start(0)
  should.equal(tween.value(anim), 10.0)
  should.equal(tween.is_finished(anim), False)
}

pub fn advance_unstarted_is_noop_test() {
  let anim = tween.new(0.0, 100.0, 1000, Linear)
  let advanced = tween.advance(anim, 500)
  should.equal(tween.value(advanced), 0.0)
}

pub fn advance_linear_midpoint_test() {
  let anim =
    tween.new(0.0, 100.0, 1000, Linear)
    |> tween.start(0)
    |> tween.advance(500)
  should.equal(tween.value(anim), 50.0)
  should.equal(tween.is_finished(anim), False)
}

pub fn advance_past_duration_finishes_test() {
  let anim =
    tween.new(0.0, 100.0, 1000, Linear)
    |> tween.start(0)
    |> tween.advance(1500)
  should.equal(tween.value(anim), 100.0)
  should.equal(tween.is_finished(anim), True)
}

pub fn advance_exact_duration_finishes_test() {
  let anim =
    tween.new(0.0, 100.0, 1000, Linear)
    |> tween.start(0)
    |> tween.advance(1000)
  should.equal(tween.value(anim), 100.0)
  should.equal(tween.is_finished(anim), True)
}

pub fn lerp_basic_test() {
  should.equal(tween.lerp(0.0, 10.0, 0.5), 5.0)
  should.equal(tween.lerp(0.0, 10.0, 0.0), 0.0)
  should.equal(tween.lerp(0.0, 10.0, 1.0), 10.0)
}

pub fn easing_boundaries_test() {
  // All easing functions should return ~0.0 at t=0 and ~1.0 at t=1
  let easings = [Linear, EaseIn, EaseOut, EaseInOut]
  use e <- list.each(easings)
  should.equal(easing.apply(e, 0.0), 0.0)
  should.equal(easing.apply(e, 1.0), 1.0)
}

pub fn ease_in_slower_at_start_test() {
  // EaseIn (sine-based) at t=0.5 should be less than 0.5
  let v = easing.apply(EaseIn, 0.5)
  assert v <. 0.5
}

pub fn ease_out_faster_at_start_test() {
  // EaseOut (sine-based) at t=0.5 should be greater than 0.5
  let v = easing.apply(EaseOut, 0.5)
  assert v >. 0.5
}

pub fn elastic_easing_basic_test() {
  // Elastic should produce a value at midpoint without crashing
  let v = easing.apply(EaseOutElastic, 0.5)
  assert v >. 0.0
}

pub fn spring_presets_match_cross_sdk_contract_test() {
  let presets = [
    #(spring.gentle(1.0), 120.0, 14.0),
    #(spring.bouncy(1.0), 300.0, 10.0),
    #(spring.stiff(1.0), 400.0, 30.0),
    #(spring.snappy(1.0), 200.0, 20.0),
    #(spring.molasses(1.0), 60.0, 12.0),
  ]

  use #(encoded, stiffness, damping) <- list.each(presets)
  let assert DictVal(fields) = spring.encode(encoded)
  should.equal(dict.get(fields, "type"), Ok(StringVal("spring")))
  should.equal(dict.get(fields, "stiffness"), Ok(FloatVal(stiffness)))
  should.equal(dict.get(fields, "damping"), Ok(FloatVal(damping)))
}
