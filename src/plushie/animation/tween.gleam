//// SDK-side frame-based interpolation (manual tween).
////
//// For most use cases, prefer renderer-side descriptors
//// (`plushie/animation/transition`, `plushie/animation/spring`)
//// which animate with zero wire traffic. Use this module when you
//// need frame-by-frame control over interpolation in the app model.
////
//// Drive with `subscription.on_animation_frame`, create with `new`,
//// start with `start`, then `advance` each frame.

import gleam/int
import gleam/option.{type Option, None, Some}
import plushie/animation/easing.{type Easing}

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

/// Create a new animation (not yet started).
///
/// Uses the same `Easing` type as renderer-side transitions, so the
/// full set of named curves is available (e.g. `easing.EaseOutBounce`,
/// `easing.CubicBezier(0.25, 0.1, 0.25, 1.0)`).
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
          let eased = easing.apply(anim.easing, t)
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
