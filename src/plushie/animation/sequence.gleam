//// Renderer-side sequential animation chain.
////
//// Chains multiple transitions and springs that execute one after
//// another on the same prop. Each step's starting value defaults
//// to the previous step's final value if not specified.
////
//// ## Usage
////
////     import plushie/animation/sequence
////     import plushie/animation/spring
////     import plushie/animation/transition
////
////     // Fade in, pulse three times, then fade out
////     sequence.new()
////     |> sequence.then_transition(
////       transition.new(to: 1.0, duration: 200)
////       |> transition.from(0.0),
////     )
////     |> sequence.then_spring(spring.bouncy(0.7))
////     |> sequence.then_transition(
////       transition.new(to: 0.0, duration: 300),
////     )
////     |> sequence.on_complete("fade_cycle_done")
////

import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import plushie/animation/spring.{type Spring}
import plushie/animation/transition.{type Transition}
import plushie/node.{type PropValue, DictVal, ListVal, StringVal}

/// A step in the animation sequence, holding an already-encoded
/// descriptor (transition or spring).
pub opaque type Step {
  TransitionStep(Transition)
  SpringStep(Spring)
}

/// A sequential animation chain.
pub opaque type Sequence {
  Sequence(steps: List(Step), on_complete: Option(String))
}

/// Create an empty sequence. Add steps with `then_transition` and
/// `then_spring`.
pub fn new() -> Sequence {
  Sequence(steps: [], on_complete: None)
}

/// Append a transition step to the sequence.
pub fn then_transition(seq: Sequence, t: Transition) -> Sequence {
  Sequence(..seq, steps: [TransitionStep(t), ..seq.steps])
}

/// Append a spring step to the sequence.
pub fn then_spring(seq: Sequence, s: Spring) -> Sequence {
  Sequence(..seq, steps: [SpringStep(s), ..seq.steps])
}

/// Set the completion event tag for the entire sequence.
///
/// Only the sequence-level tag fires. Individual step completion
/// tags are ignored by the renderer.
pub fn on_complete(seq: Sequence, tag: String) -> Sequence {
  Sequence(..seq, on_complete: Some(tag))
}

/// Encode a sequence to its wire-format PropValue.
pub fn encode(seq: Sequence) -> PropValue {
  let encoded_steps =
    seq.steps
    |> list.reverse
    |> list.map(fn(step) {
      case step {
        TransitionStep(t) -> transition.encode(t)
        SpringStep(s) -> spring.encode(s)
      }
    })

  let fields = [
    #("type", StringVal("sequence")),
    #("steps", ListVal(encoded_steps)),
  ]

  let fields = case seq.on_complete {
    None -> fields
    Some(tag) -> [#("on_complete", StringVal(tag)), ..fields]
  }

  DictVal(dict.from_list(fields))
}
