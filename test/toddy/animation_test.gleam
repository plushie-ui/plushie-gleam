import gleeunit/should
import toddy/animation.{EaseIn, EaseInOut, EaseOut, Linear, Spring}

pub fn new_creates_unstarted_animation_test() {
  let anim = animation.new(0.0, 100.0, 1000, Linear)
  should.equal(animation.value(anim), 0.0)
  should.equal(animation.is_finished(anim), False)
}

pub fn start_sets_initial_value_test() {
  let anim =
    animation.new(10.0, 50.0, 500, Linear)
    |> animation.start(0)
  should.equal(animation.value(anim), 10.0)
  should.equal(animation.is_finished(anim), False)
}

pub fn advance_unstarted_is_noop_test() {
  let anim = animation.new(0.0, 100.0, 1000, Linear)
  let advanced = animation.advance(anim, 500)
  should.equal(animation.value(advanced), 0.0)
}

pub fn advance_linear_midpoint_test() {
  let anim =
    animation.new(0.0, 100.0, 1000, Linear)
    |> animation.start(0)
    |> animation.advance(500)
  should.equal(animation.value(anim), 50.0)
  should.equal(animation.is_finished(anim), False)
}

pub fn advance_past_duration_finishes_test() {
  let anim =
    animation.new(0.0, 100.0, 1000, Linear)
    |> animation.start(0)
    |> animation.advance(1500)
  should.equal(animation.value(anim), 100.0)
  should.equal(animation.is_finished(anim), True)
}

pub fn advance_exact_duration_finishes_test() {
  let anim =
    animation.new(0.0, 100.0, 1000, Linear)
    |> animation.start(0)
    |> animation.advance(1000)
  should.equal(animation.value(anim), 100.0)
  should.equal(animation.is_finished(anim), True)
}

pub fn lerp_basic_test() {
  should.equal(animation.lerp(0.0, 10.0, 0.5), 5.0)
  should.equal(animation.lerp(0.0, 10.0, 0.0), 0.0)
  should.equal(animation.lerp(0.0, 10.0, 1.0), 10.0)
}

pub fn easing_boundaries_test() {
  // All easing functions should return ~0.0 at t=0 and ~1.0 at t=1
  let easings = [Linear, EaseIn, EaseOut, EaseInOut]
  use easing <- list.each(easings)
  should.equal(animation.apply_easing(easing, 0.0), 0.0)
  should.equal(animation.apply_easing(easing, 1.0), 1.0)
}

pub fn ease_in_slower_at_start_test() {
  // EaseIn (cubic) at t=0.5 should be less than 0.5
  let v = animation.apply_easing(EaseIn, 0.5)
  assert v <. 0.5
}

pub fn ease_out_faster_at_start_test() {
  // EaseOut (cubic) at t=0.5 should be greater than 0.5
  let v = animation.apply_easing(EaseOut, 0.5)
  assert v >. 0.5
}

pub fn spring_easing_basic_test() {
  // Spring should produce a value at midpoint -- just ensure no crash
  let v = animation.apply_easing(Spring, 0.5)
  assert v >. 0.0
}

import gleam/list
