//// Animation helpers for frame-based interpolation.
////
//// Use with `subscription.on_animation_frame` to drive updates.
//// Create an animation with `new`, start it, then `advance` each frame.

import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}

/// An animation interpolating between two values over time.
pub type Animation {
  Animation(
    from: Float,
    to: Float,
    duration_ms: Int,
    started_at: Option(Int),
    easing: Easing,
    value: Float,
    finished: Bool,
  )
}

/// Easing function type.
pub type Easing {
  Linear
  EaseIn
  EaseOut
  EaseInOut
  EaseInQuad
  EaseOutQuad
  EaseInOutQuad
  Spring
}

/// Create a new animation (not yet started).
pub fn new(
  from: Float,
  to: Float,
  duration_ms: Int,
  easing: Easing,
) -> Animation {
  Animation(
    from:,
    to:,
    duration_ms:,
    started_at: None,
    easing:,
    value: from,
    finished: False,
  )
}

/// Start the animation at the given timestamp (monotonic ms).
pub fn start(anim: Animation, now: Int) -> Animation {
  Animation(..anim, started_at: Some(now), value: anim.from, finished: False)
}

/// Advance the animation to the given timestamp. Returns updated animation.
/// Check `finished` field to know when it's done.
pub fn advance(anim: Animation, now: Int) -> Animation {
  case anim.started_at {
    None -> anim
    Some(started) -> {
      let elapsed = now - started
      case elapsed >= anim.duration_ms {
        True -> Animation(..anim, value: anim.to, finished: True)
        False -> {
          let t = int.to_float(elapsed) /. int.to_float(anim.duration_ms)
          let eased = apply_easing(anim.easing, t)
          let value = lerp(anim.from, anim.to, eased)
          Animation(..anim, value:)
        }
      }
    }
  }
}

/// Get the current value.
pub fn value(anim: Animation) -> Float {
  anim.value
}

/// Check if the animation has finished.
pub fn is_finished(anim: Animation) -> Bool {
  anim.finished
}

/// Linear interpolation between two values.
pub fn lerp(from: Float, to: Float, t: Float) -> Float {
  from +. { { to -. from } *. t }
}

/// Apply an easing function to a progress value (0.0 to 1.0).
pub fn apply_easing(easing: Easing, t: Float) -> Float {
  case easing {
    Linear -> t
    EaseIn -> t *. t *. t
    EaseOut -> {
      let inv = 1.0 -. t
      1.0 -. { inv *. inv *. inv }
    }
    EaseInOut ->
      case t <. 0.5 {
        True -> 4.0 *. t *. t *. t
        False -> {
          let p = { 2.0 *. t } -. 2.0
          0.5 *. p *. p *. p +. 1.0
        }
      }
    EaseInQuad -> t *. t
    EaseOutQuad -> t *. { 2.0 -. t }
    EaseInOutQuad ->
      case t <. 0.5 {
        True -> 2.0 *. t *. t
        False -> {
          let p = { -2.0 *. t } +. 2.0
          1.0 -. { p *. p /. 2.0 }
        }
      }
    Spring -> {
      // Damped spring approximation
      let w = 6.283185
      // 2*pi
      let d = 0.7
      // damping ratio
      let envelope = float.power(2.71828, of: float.negate(d *. t *. 8.0))
      case envelope {
        Ok(env) -> {
          let oscillation = sin(w *. t *. 2.0)
          1.0 -. env *. oscillation
        }
        Error(_) -> t
      }
    }
  }
}

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float
