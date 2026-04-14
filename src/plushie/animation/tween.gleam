//// SDK-side frame-based interpolation (manual tween).
////
//// For most use cases, prefer renderer-side descriptors
//// (`plushie/animation/transition`, `plushie/animation/spring`)
//// which animate with zero wire traffic. Use this module when you
//// need frame-by-frame control over interpolation in the app model.
////
//// Drive with `subscription.on_animation_frame()`, create with `new`,
//// start with `start`, then `advance` each frame.

import gleam/int
import gleam/option.{type Option, None, Some}
import plushie/animation/easing.{type Easing}

/// Repeat mode for animations.
pub type Repeat {
  /// Play once and stop.
  Once
  /// Repeat a fixed number of times.
  Times(Int)
  /// Repeat indefinitely.
  Forever
}

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
    repeat: Repeat,
    auto_reverse: Bool,
    /// Track how many complete cycles have been played.
    cycles_completed: Int,
    /// Track whether the current cycle is playing forward or reversed.
    reversed: Bool,
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
    repeat: Once,
    auto_reverse: False,
    cycles_completed: 0,
    reversed: False,
  )
}

/// Create a looping animation that repeats forever with auto-reverse.
///
/// Shorthand for `new` with `repeat: Forever` and `auto_reverse: True`.
/// The animation bounces between `from` and `to` indefinitely.
pub fn looping(
  from: Float,
  to: Float,
  duration_ms: Int,
  easing: Easing,
) -> Animation {
  Animation(
    ..new(from, to, duration_ms, easing),
    repeat: Forever,
    auto_reverse: True,
  )
}

/// Set the repeat mode on an animation.
pub fn set_repeat(anim: Animation, repeat: Repeat) -> Animation {
  Animation(..anim, repeat:)
}

/// Enable or disable auto-reverse. When enabled, the animation plays
/// in reverse on alternate cycles.
pub fn set_auto_reverse(anim: Animation, enabled: Bool) -> Animation {
  Animation(..anim, auto_reverse: enabled)
}

/// Start the animation at the given timestamp (monotonic ms).
pub fn start(anim: Animation, now: Int) -> Animation {
  Animation(
    ..anim,
    started_at: Some(now),
    value: anim.from,
    finished: False,
    cycles_completed: 0,
    reversed: False,
  )
}

/// Advance the animation to the given timestamp. Returns updated animation.
/// Check `finished` field to know when it's done.
pub fn advance(anim: Animation, now: Int) -> Animation {
  case anim.started_at {
    None -> anim
    Some(started) -> {
      let elapsed = int.max(0, now - started)
      let cycle_duration = anim.duration_ms
      case cycle_duration <= 0 {
        True -> Animation(..anim, value: anim.to, finished: True)
        False -> {
          let cycle = elapsed / cycle_duration
          let cycle_elapsed = elapsed % cycle_duration
          let cycle_t =
            int.to_float(cycle_elapsed) /. int.to_float(cycle_duration)

          // Check if we've exhausted our repeat count
          let max_cycles = case anim.repeat {
            Once -> 1
            Times(n) -> n + 1
            Forever -> -1
          }

          case max_cycles >= 0 && cycle >= max_cycles {
            True -> {
              // Animation complete
              let final_value = case anim.auto_reverse && max_cycles % 2 == 0 {
                True -> anim.from
                False -> anim.to
              }
              Animation(..anim, value: final_value, finished: True)
            }
            False -> {
              // Determine if this cycle is reversed
              let is_reversed = anim.auto_reverse && cycle % 2 == 1
              let eased = easing.apply(anim.easing, cycle_t)
              let value = case is_reversed {
                True -> lerp(anim.to, anim.from, eased)
                False -> lerp(anim.from, anim.to, eased)
              }
              Animation(
                ..anim,
                value:,
                cycles_completed: cycle,
                reversed: is_reversed,
              )
            }
          }
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
