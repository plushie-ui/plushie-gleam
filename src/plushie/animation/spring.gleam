//// Renderer-side physics-based spring descriptor.
////
//// Springs animate using a damped harmonic oscillator simulation.
//// Unlike timed transitions, springs have no fixed duration: they
//// settle naturally based on stiffness, damping, and mass. This
//// makes them ideal for interactive animations where the target
//// changes frequently (drag, scroll, hover) because interruption
//// preserves velocity for smooth redirection.
////
//// ## Usage
////
////     import plushie/animation/spring
////
////     // Custom parameters
////     spring.new(to: 1.05, stiffness: 200.0, damping: 20.0)
////
////     // Named presets
////     spring.gentle(1.0)
////     spring.bouncy(1.05) |> spring.from(0.0)
////

import gleam/dict
import gleam/option.{type Option, None, Some}
import plushie/node.{type PropValue, DictVal, FloatVal, StringVal}

/// A physics-based spring descriptor.
pub opaque type Spring {
  Spring(
    to: Float,
    stiffness: Float,
    damping: Float,
    mass: Float,
    velocity: Float,
    from: Option(Float),
    on_complete: Option(String),
  )
}

/// Create a new spring with explicit stiffness and damping.
pub fn new(
  to to: Float,
  stiffness stiffness: Float,
  damping damping: Float,
) -> Spring {
  Spring(
    to:,
    stiffness:,
    damping:,
    mass: 1.0,
    velocity: 0.0,
    from: None,
    on_complete: None,
  )
}

/// Gentle preset: slow, smooth, no overshoot.
/// (stiffness: 120, damping: 14)
pub fn gentle(to: Float) -> Spring {
  new(to:, stiffness: 120.0, damping: 14.0)
}

/// Bouncy preset: quick with visible overshoot.
/// (stiffness: 600, damping: 15)
pub fn bouncy(to: Float) -> Spring {
  new(to:, stiffness: 600.0, damping: 15.0)
}

/// Stiff preset: very quick, crisp stop.
/// (stiffness: 600, damping: 30)
pub fn stiff(to: Float) -> Spring {
  new(to:, stiffness: 600.0, damping: 30.0)
}

/// Snappy preset: quick, minimal overshoot.
/// (stiffness: 400, damping: 25)
pub fn snappy(to: Float) -> Spring {
  new(to:, stiffness: 400.0, damping: 25.0)
}

/// Molasses preset: slow, heavy, deliberate.
/// (stiffness: 60, damping: 18)
pub fn molasses(to: Float) -> Spring {
  new(to:, stiffness: 60.0, damping: 18.0)
}

/// Set the mass (higher = slower, heavier).
pub fn mass(s: Spring, mass: Float) -> Spring {
  Spring(..s, mass:)
}

/// Set the initial velocity.
pub fn velocity(s: Spring, velocity: Float) -> Spring {
  Spring(..s, velocity:)
}

/// Set the explicit start value.
pub fn from(s: Spring, from: Float) -> Spring {
  Spring(..s, from: Some(from))
}

/// Set the completion event tag.
pub fn on_complete(s: Spring, tag: String) -> Spring {
  Spring(..s, on_complete: Some(tag))
}

/// Encode a spring to its wire-format PropValue.
///
/// Only non-default fields are included to keep messages compact.
pub fn encode(s: Spring) -> PropValue {
  let fields = [
    #("type", StringVal("spring")),
    #("to", FloatVal(s.to)),
    #("stiffness", FloatVal(s.stiffness)),
    #("damping", FloatVal(s.damping)),
  ]

  let fields = case s.mass {
    1.0 -> fields
    m -> [#("mass", FloatVal(m)), ..fields]
  }

  let fields = case s.velocity {
    0.0 -> fields
    v -> [#("velocity", FloatVal(v)), ..fields]
  }

  let fields = case s.from {
    None -> fields
    Some(v) -> [#("from", FloatVal(v)), ..fields]
  }

  let fields = case s.on_complete {
    None -> fields
    Some(tag) -> [#("on_complete", StringVal(tag)), ..fields]
  }

  DictVal(dict.from_list(fields))
}
