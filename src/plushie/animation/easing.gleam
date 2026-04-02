//// Named easing curves for animations and transitions.
////
//// Provides named easing curves (matching the standard set from
//// CSS/lilt) plus custom cubic bezier support. Used by transitions
//// (as wire-format PropValues) and SDK-side interpolation (as pure
//// functions via `apply`).
////
//// Named curves: Linear, EaseIn/Out/InOut (sine), Quad, Cubic,
//// Quart, Quint, Expo, Circ, Back, Elastic, Bounce.
//// CubicBezier allows custom curves matching CSS `cubic-bezier()`.

import gleam/dict
import gleam/float
import plushie/node.{type PropValue, DictVal, FloatVal, ListVal, StringVal}
import plushie/platform

// Pi constant
const pi = 3.14159265358979323846

// Back constants (standard CSS values)
const c1 = 1.70158

const c3 = 2.70158

// c1 * 1.525
const c2 = 2.5949095

// Elastic constants: 2 * pi / 3
const c4 = 2.0943951023932

// 2 * pi / 4.5
const c5 = 1.3962634015955

// Bounce constants
const n1 = 7.5625

const d1 = 2.75

/// Easing curve specification.
///
/// Named variants correspond to the standard CSS easing functions.
/// EaseIn/EaseOut/EaseInOut are sine-based (identical to the
/// EaseInSine/EaseOutSine/EaseInOutSine variants).
/// CubicBezier allows custom curves with control points matching
/// the CSS `cubic-bezier()` function.
pub type Easing {
  Linear
  EaseIn
  EaseOut
  EaseInOut
  EaseInQuad
  EaseOutQuad
  EaseInOutQuad
  EaseInCubic
  EaseOutCubic
  EaseInOutCubic
  EaseInQuart
  EaseOutQuart
  EaseInOutQuart
  EaseInQuint
  EaseOutQuint
  EaseInOutQuint
  EaseInSine
  EaseOutSine
  EaseInOutSine
  EaseInExpo
  EaseOutExpo
  EaseInOutExpo
  EaseInCirc
  EaseOutCirc
  EaseInOutCirc
  EaseInBack
  EaseOutBack
  EaseInOutBack
  EaseInElastic
  EaseOutElastic
  EaseInOutElastic
  EaseInBounce
  EaseOutBounce
  EaseInOutBounce
  CubicBezier(x1: Float, y1: Float, x2: Float, y2: Float)
}

/// Returns the wire-format name for an easing (snake_case string).
///
/// CubicBezier returns "cubic_bezier".
pub fn name(easing: Easing) -> String {
  case easing {
    Linear -> "linear"
    EaseIn -> "ease_in"
    EaseOut -> "ease_out"
    EaseInOut -> "ease_in_out"
    EaseInQuad -> "ease_in_quad"
    EaseOutQuad -> "ease_out_quad"
    EaseInOutQuad -> "ease_in_out_quad"
    EaseInCubic -> "ease_in_cubic"
    EaseOutCubic -> "ease_out_cubic"
    EaseInOutCubic -> "ease_in_out_cubic"
    EaseInQuart -> "ease_in_quart"
    EaseOutQuart -> "ease_out_quart"
    EaseInOutQuart -> "ease_in_out_quart"
    EaseInQuint -> "ease_in_quint"
    EaseOutQuint -> "ease_out_quint"
    EaseInOutQuint -> "ease_in_out_quint"
    EaseInSine -> "ease_in_sine"
    EaseOutSine -> "ease_out_sine"
    EaseInOutSine -> "ease_in_out_sine"
    EaseInExpo -> "ease_in_expo"
    EaseOutExpo -> "ease_out_expo"
    EaseInOutExpo -> "ease_in_out_expo"
    EaseInCirc -> "ease_in_circ"
    EaseOutCirc -> "ease_out_circ"
    EaseInOutCirc -> "ease_in_out_circ"
    EaseInBack -> "ease_in_back"
    EaseOutBack -> "ease_out_back"
    EaseInOutBack -> "ease_in_out_back"
    EaseInElastic -> "ease_in_elastic"
    EaseOutElastic -> "ease_out_elastic"
    EaseInOutElastic -> "ease_in_out_elastic"
    EaseInBounce -> "ease_in_bounce"
    EaseOutBounce -> "ease_out_bounce"
    EaseInOutBounce -> "ease_in_out_bounce"
    CubicBezier(..) -> "cubic_bezier"
  }
}

/// Encode an easing to its wire-format PropValue.
///
/// Named easings become a StringVal. CubicBezier becomes a DictVal
/// with a `"cubic_bezier"` key holding `[x1, y1, x2, y2]`.
pub fn encode(easing: Easing) -> PropValue {
  case easing {
    CubicBezier(x1, y1, x2, y2) ->
      DictVal(
        dict.from_list([
          #(
            "cubic_bezier",
            ListVal([FloatVal(x1), FloatVal(y1), FloatVal(x2), FloatVal(y2)]),
          ),
        ]),
      )
    _ -> StringVal(name(easing))
  }
}

/// Returns True if the easing value is valid.
///
/// Named easings are always valid. CubicBezier requires control
/// point x-coordinates in the 0.0 to 1.0 range (y-coordinates
/// are unconstrained, matching CSS behavior).
pub fn valid(easing: Easing) -> Bool {
  case easing {
    CubicBezier(x1, _y1, x2, _y2) ->
      x1 >=. 0.0 && x1 <=. 1.0 && x2 >=. 0.0 && x2 <=. 1.0
    _ -> True
  }
}

/// Evaluate the easing curve at progress `t` (0.0 to 1.0).
///
/// Some curves (back, elastic, bounce) can produce values outside
/// the 0.0 to 1.0 range (overshoot).
pub fn apply(easing: Easing, t: Float) -> Float {
  case easing {
    Linear -> t
    EaseIn | EaseInSine -> ease_in_sine(t)
    EaseOut | EaseOutSine -> ease_out_sine(t)
    EaseInOut | EaseInOutSine -> ease_in_out_sine(t)
    EaseInQuad -> t *. t
    EaseOutQuad -> 1.0 -. { { 1.0 -. t } *. { 1.0 -. t } }
    EaseInOutQuad -> apply_ease_in_out_quad(t)
    EaseInCubic -> t *. t *. t
    EaseOutCubic -> 1.0 -. platform.math_pow(1.0 -. t, 3.0)
    EaseInOutCubic -> apply_ease_in_out_cubic(t)
    EaseInQuart -> t *. t *. t *. t
    EaseOutQuart -> 1.0 -. platform.math_pow(1.0 -. t, 4.0)
    EaseInOutQuart -> apply_ease_in_out_quart(t)
    EaseInQuint -> t *. t *. t *. t *. t
    EaseOutQuint -> 1.0 -. platform.math_pow(1.0 -. t, 5.0)
    EaseInOutQuint -> apply_ease_in_out_quint(t)
    EaseInExpo -> apply_ease_in_expo(t)
    EaseOutExpo -> apply_ease_out_expo(t)
    EaseInOutExpo -> apply_ease_in_out_expo(t)
    EaseInCirc -> apply_ease_in_circ(t)
    EaseOutCirc -> apply_ease_out_circ(t)
    EaseInOutCirc -> apply_ease_in_out_circ(t)
    EaseInBack -> apply_ease_in_back(t)
    EaseOutBack -> apply_ease_out_back(t)
    EaseInOutBack -> apply_ease_in_out_back(t)
    EaseInElastic -> apply_ease_in_elastic(t)
    EaseOutElastic -> apply_ease_out_elastic(t)
    EaseInOutElastic -> apply_ease_in_out_elastic(t)
    EaseInBounce -> 1.0 -. apply_ease_out_bounce(1.0 -. t)
    EaseOutBounce -> apply_ease_out_bounce(t)
    EaseInOutBounce -> apply_ease_in_out_bounce(t)
    CubicBezier(x1, y1, x2, y2) -> cubic_bezier(t, x1, y1, x2, y2)
  }
}

// -- Math helpers -------------------------------------------------------------

/// cos(x) derived from sin: cos(x) = sin(pi/2 - x)
fn cos(x: Float) -> Float {
  platform.math_sin(pi /. 2.0 -. x)
}

/// sqrt(x) via pow(x, 0.5)
fn sqrt(x: Float) -> Float {
  platform.math_pow(x, 0.5)
}

// -- Sine ---------------------------------------------------------------------

fn ease_in_sine(t: Float) -> Float {
  1.0 -. cos(t *. pi /. 2.0)
}

fn ease_out_sine(t: Float) -> Float {
  platform.math_sin(t *. pi /. 2.0)
}

fn ease_in_out_sine(t: Float) -> Float {
  { 0.0 -. { cos(pi *. t) -. 1.0 } } /. 2.0
}

// -- Quadratic ----------------------------------------------------------------

fn apply_ease_in_out_quad(t: Float) -> Float {
  case t <. 0.5 {
    True -> 2.0 *. t *. t
    False -> 1.0 -. platform.math_pow(-2.0 *. t +. 2.0, 2.0) /. 2.0
  }
}

// -- Cubic --------------------------------------------------------------------

fn apply_ease_in_out_cubic(t: Float) -> Float {
  case t <. 0.5 {
    True -> 4.0 *. t *. t *. t
    False -> 1.0 -. platform.math_pow(-2.0 *. t +. 2.0, 3.0) /. 2.0
  }
}

// -- Quartic ------------------------------------------------------------------

fn apply_ease_in_out_quart(t: Float) -> Float {
  case t <. 0.5 {
    True -> 8.0 *. t *. t *. t *. t
    False -> 1.0 -. platform.math_pow(-2.0 *. t +. 2.0, 4.0) /. 2.0
  }
}

// -- Quintic ------------------------------------------------------------------

fn apply_ease_in_out_quint(t: Float) -> Float {
  case t <. 0.5 {
    True -> 16.0 *. t *. t *. t *. t *. t
    False -> 1.0 -. platform.math_pow(-2.0 *. t +. 2.0, 5.0) /. 2.0
  }
}

// -- Exponential --------------------------------------------------------------

fn apply_ease_in_expo(t: Float) -> Float {
  case t == 0.0 {
    True -> 0.0
    False -> platform.math_pow(2.0, 10.0 *. t -. 10.0)
  }
}

fn apply_ease_out_expo(t: Float) -> Float {
  case t == 1.0 {
    True -> 1.0
    False -> 1.0 -. platform.math_pow(2.0, -10.0 *. t)
  }
}

fn apply_ease_in_out_expo(t: Float) -> Float {
  case t == 0.0 {
    True -> 0.0
    False ->
      case t == 1.0 {
        True -> 1.0
        False ->
          case t <. 0.5 {
            True -> platform.math_pow(2.0, 20.0 *. t -. 10.0) /. 2.0
            False ->
              { 2.0 -. platform.math_pow(2.0, -20.0 *. t +. 10.0) } /. 2.0
          }
      }
  }
}

// -- Circular -----------------------------------------------------------------

fn apply_ease_in_circ(t: Float) -> Float {
  1.0 -. sqrt(1.0 -. t *. t)
}

fn apply_ease_out_circ(t: Float) -> Float {
  sqrt(1.0 -. { t -. 1.0 } *. { t -. 1.0 })
}

fn apply_ease_in_out_circ(t: Float) -> Float {
  case t <. 0.5 {
    True -> { 1.0 -. sqrt(1.0 -. platform.math_pow(2.0 *. t, 2.0)) } /. 2.0
    False ->
      { 1.0 +. sqrt(1.0 -. platform.math_pow(-2.0 *. t +. 2.0, 2.0)) } /. 2.0
  }
}

// -- Back (overshoots) --------------------------------------------------------

fn apply_ease_in_back(t: Float) -> Float {
  { c3 *. t *. t *. t } -. { c1 *. t *. t }
}

fn apply_ease_out_back(t: Float) -> Float {
  1.0
  +. { c3 *. platform.math_pow(t -. 1.0, 3.0) }
  +. { c1 *. platform.math_pow(t -. 1.0, 2.0) }
}

fn apply_ease_in_out_back(t: Float) -> Float {
  case t <. 0.5 {
    True ->
      platform.math_pow(2.0 *. t, 2.0)
      *. { { c2 +. 1.0 } *. 2.0 *. t -. c2 }
      /. 2.0
    False ->
      {
        platform.math_pow(2.0 *. t -. 2.0, 2.0)
        *. { { c2 +. 1.0 } *. { 2.0 *. t -. 2.0 } +. c2 }
        +. 2.0
      }
      /. 2.0
  }
}

// -- Elastic (oscillating overshoot) ------------------------------------------

fn apply_ease_in_elastic(t: Float) -> Float {
  case t == 0.0 {
    True -> 0.0
    False ->
      case t == 1.0 {
        True -> 1.0
        False -> {
          let pow_val = platform.math_pow(2.0, 10.0 *. t -. 10.0)
          let sin_val = platform.math_sin({ 10.0 *. t -. 10.75 } *. c4)
          0.0 -. pow_val *. sin_val
        }
      }
  }
}

fn apply_ease_out_elastic(t: Float) -> Float {
  case t == 0.0 {
    True -> 0.0
    False ->
      case t == 1.0 {
        True -> 1.0
        False -> {
          let pow_val = platform.math_pow(2.0, -10.0 *. t)
          let sin_val = platform.math_sin({ 10.0 *. t -. 0.75 } *. c4)
          pow_val *. sin_val +. 1.0
        }
      }
  }
}

fn apply_ease_in_out_elastic(t: Float) -> Float {
  case t == 0.0 {
    True -> 0.0
    False ->
      case t == 1.0 {
        True -> 1.0
        False ->
          case t <. 0.5 {
            True -> {
              let pow_val = platform.math_pow(2.0, 20.0 *. t -. 10.0)
              let sin_val = platform.math_sin({ 20.0 *. t -. 11.125 } *. c5)
              0.0 -. { pow_val *. sin_val } /. 2.0
            }
            False -> {
              let pow_val = platform.math_pow(2.0, -20.0 *. t +. 10.0)
              let sin_val = platform.math_sin({ 20.0 *. t -. 11.125 } *. c5)
              pow_val *. sin_val /. 2.0 +. 1.0
            }
          }
      }
  }
}

// -- Bounce -------------------------------------------------------------------

fn apply_ease_out_bounce(t: Float) -> Float {
  case t <. 1.0 /. d1 {
    True -> n1 *. t *. t
    False ->
      case t <. 2.0 /. d1 {
        True -> {
          let t2 = t -. 1.5 /. d1
          n1 *. t2 *. t2 +. 0.75
        }
        False ->
          case t <. 2.5 /. d1 {
            True -> {
              let t2 = t -. 2.25 /. d1
              n1 *. t2 *. t2 +. 0.9375
            }
            False -> {
              let t2 = t -. 2.625 /. d1
              n1 *. t2 *. t2 +. 0.984375
            }
          }
      }
  }
}

fn apply_ease_in_out_bounce(t: Float) -> Float {
  case t <. 0.5 {
    True -> { 1.0 -. apply_ease_out_bounce(1.0 -. 2.0 *. t) } /. 2.0
    False -> { 1.0 +. apply_ease_out_bounce(2.0 *. t -. 1.0) } /. 2.0
  }
}

// -- Cubic bezier -------------------------------------------------------------

/// Evaluate a cubic bezier easing curve at progress `t`.
///
/// Control points (x1, y1) and (x2, y2) match the CSS
/// `cubic-bezier()` function. The curve starts at (0, 0)
/// and ends at (1, 1).
///
/// Uses Newton-Raphson iteration to solve for the bezier
/// parameter given the x coordinate, then evaluates y.
fn cubic_bezier(t: Float, x1: Float, y1: Float, x2: Float, y2: Float) -> Float {
  case t <=. 0.0 {
    True -> 0.0
    False ->
      case t >=. 1.0 {
        True -> 1.0
        False -> {
          let s = newton_raphson_solve(t, x1, x2, t, 8)
          bezier_eval(s, y1, y2)
        }
      }
  }
}

/// Evaluate the cubic bezier polynomial for one axis.
/// B(s) = 3(1-s)^2 * s * p1 + 3(1-s) * s^2 * p2 + s^3
fn bezier_eval(s: Float, p1: Float, p2: Float) -> Float {
  let s2 = s *. s
  let s3 = s2 *. s
  let inv = 1.0 -. s
  3.0 *. inv *. inv *. s *. p1 +. 3.0 *. inv *. s2 *. p2 +. s3
}

/// Derivative of the bezier polynomial for one axis.
/// B'(s) = 3(1-s)^2 * p1 + 6(1-s) * s * (p2-p1) + 3 * s^2 * (1-p2)
fn bezier_derivative(s: Float, p1: Float, p2: Float) -> Float {
  let inv = 1.0 -. s
  { 3.0 *. inv *. inv *. p1 }
  +. { 6.0 *. inv *. s *. { p2 -. p1 } }
  +. { 3.0 *. s *. s *. { 1.0 -. p2 } }
}

/// Newton-Raphson iteration to find s where bezier_x(s) == target_x.
fn newton_raphson_solve(
  target_x: Float,
  x1: Float,
  x2: Float,
  guess: Float,
  iterations: Int,
) -> Float {
  case iterations <= 0 {
    True -> guess
    False -> {
      let x = bezier_eval(guess, x1, x2)
      let dx = bezier_derivative(guess, x1, x2)
      case
        float.absolute_value(x -. target_x) <. 1.0e-7
        || float.absolute_value(dx) <. 1.0e-7
      {
        True -> guess
        False -> {
          let next = guess -. { x -. target_x } /. dx
          let clamped = float.max(0.0, float.min(1.0, next))
          newton_raphson_solve(target_x, x1, x2, clamped, iterations - 1)
        }
      }
    }
  }
}
