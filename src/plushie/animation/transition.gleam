//// Renderer-side timed transition descriptor.
////
//// Declares animation intent in the view; the renderer handles
//// interpolation locally with zero wire traffic during animation.
////
//// ## Usage
////
////     import plushie/animation/transition
////
////     // Basic fade out
////     transition.new(to: 0.0, duration: 300)
////
////     // With easing and delay
////     transition.new(to: 0.0, duration: 300)
////     |> transition.easing(easing.EaseOut)
////     |> transition.delay(100)
////
////     // Enter animation (fade in from transparent)
////     transition.new(to: 1.0, duration: 200)
////     |> transition.from(0.0)
////
////     // Infinite loop (pulse)
////     transition.loop(to: 0.4, from: 1.0, duration: 800)
////

import gleam/dict
import gleam/option.{type Option, None, Some}
import plushie/animation/easing.{type Easing, EaseInOut}
import plushie/node.{
  type PropValue, BoolVal, DictVal, FloatVal, IntVal, StringVal,
}

/// How a transition repeats.
pub type Repeat {
  /// Repeat a fixed number of times.
  Times(Int)
  /// Repeat indefinitely.
  Forever
}

/// A timed transition descriptor. All fields except `to` and `duration`
/// have sensible defaults.
pub opaque type Transition {
  Transition(
    to: Float,
    duration: Int,
    easing: Easing,
    delay: Int,
    from: Option(Float),
    repeat: Option(Repeat),
    auto_reverse: Bool,
    on_complete: Option(String),
  )
}

/// Create a new transition targeting `to` over `duration` milliseconds.
pub fn new(to to: Float, duration duration: Int) -> Transition {
  Transition(
    to:,
    duration:,
    easing: EaseInOut,
    delay: 0,
    from: None,
    repeat: None,
    auto_reverse: False,
    on_complete: None,
  )
}

/// Create a looping transition that repeats forever with auto-reverse.
///
/// `from` sets the cycle start value, `to` sets the cycle end value.
pub fn loop(
  to to: Float,
  from from: Float,
  duration duration: Int,
) -> Transition {
  Transition(
    to:,
    duration:,
    easing: EaseInOut,
    delay: 0,
    from: Some(from),
    repeat: Some(Forever),
    auto_reverse: True,
    on_complete: None,
  )
}

/// Set the easing curve.
pub fn easing(t: Transition, easing: Easing) -> Transition {
  Transition(..t, easing:)
}

/// Set the delay before the transition starts (milliseconds).
pub fn delay(t: Transition, delay: Int) -> Transition {
  Transition(..t, delay:)
}

/// Set the explicit start value (for enter animations and loop reset).
pub fn from(t: Transition, from: Float) -> Transition {
  Transition(..t, from: Some(from))
}

/// Set the repeat behavior.
pub fn repeat(t: Transition, repeat: Repeat) -> Transition {
  Transition(..t, repeat: Some(repeat))
}

/// Set whether the animation reverses on each repeat cycle.
pub fn auto_reverse(t: Transition, auto_reverse: Bool) -> Transition {
  Transition(..t, auto_reverse:)
}

/// Set the completion event tag. Fires a `transition_complete` widget
/// event when the animation finishes.
pub fn on_complete(t: Transition, tag: String) -> Transition {
  Transition(..t, on_complete: Some(tag))
}

/// Encode a transition to its wire-format PropValue.
///
/// Only non-default fields are included to keep messages compact.
pub fn encode(t: Transition) -> PropValue {
  let fields = [
    #("type", StringVal("transition")),
    #("to", FloatVal(t.to)),
    #("duration", IntVal(t.duration)),
  ]

  let fields = case t.easing {
    EaseInOut -> fields
    other -> [#("easing", easing.encode(other)), ..fields]
  }

  let fields = case t.delay {
    0 -> fields
    d -> [#("delay", IntVal(d)), ..fields]
  }

  let fields = case t.from {
    None -> fields
    Some(v) -> [#("from", FloatVal(v)), ..fields]
  }

  let fields = case t.repeat {
    None -> fields
    Some(Forever) -> [#("repeat", IntVal(-1)), ..fields]
    Some(Times(n)) -> [#("repeat", IntVal(n)), ..fields]
  }

  let fields = case t.auto_reverse {
    False -> fields
    True -> [#("auto_reverse", BoolVal(True)), ..fields]
  }

  let fields = case t.on_complete {
    None -> fields
    Some(tag) -> [#("on_complete", StringVal(tag)), ..fields]
  }

  DictVal(dict.from_list(fields))
}
