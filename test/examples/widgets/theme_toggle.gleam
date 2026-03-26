//// Animated theme toggle with a face on the thumb.
////
//// A toggle switch where the thumb has a drawn face. Light mode shows a
//// smiley; dark mode shows the face rotated upside down. The face rotates
//// during the transition. Animation is managed internally.
////
////     theme_toggle.widget("my-toggle")
////
//// Events:
//// - `WidgetEvent(kind: "toggle")` with value = Bool (new dark mode state)

import gleam/dict
import gleam/dynamic
import gleam/float
import gleam/int
import plushie/canvas/shape
import plushie/canvas_widget.{
  type CanvasWidgetDef, type EventAction, CanvasWidgetDef, Consumed, Emit,
  UpdateState,
}
import plushie/event.{type Event, CanvasElementClick, TimerTick}
import plushie/node.{type Node, type PropValue}
import plushie/prop/length
import plushie/subscription
import plushie/widget/canvas

const track_w = 64

const track_h = 32

const thumb_r = 13.0

// -- Types --------------------------------------------------------------------

pub type ToggleState {
  ToggleState(progress: Float, target: Float)
}

// -- Widget definition --------------------------------------------------------

pub fn def() -> CanvasWidgetDef(ToggleState, Nil) {
  CanvasWidgetDef(
    init: fn() { ToggleState(progress: 0.0, target: 0.0) },
    render: render,
    handle_event: handle_event,
    subscriptions: fn(_, state) {
      case state.progress != state.target {
        True -> [subscription.every(16, "animate")]
        False -> []
      }
    },
  )
}

/// Build a theme toggle canvas widget placeholder.
pub fn widget(id: String) -> Node {
  canvas_widget.build(def(), id, Nil)
}

// -- Event handler ------------------------------------------------------------

fn handle_event(event: Event, state: ToggleState) -> #(EventAction, ToggleState) {
  case event {
    // Click on the switch group -> emit :toggle with the new boolean state
    // and flip the animation target.
    CanvasElementClick(element_id: "switch", ..) -> {
      let new_target = case state.target == 0.0 {
        True -> 1.0
        False -> 0.0
      }
      #(
        Emit(kind: "toggle", data: dynamic.bool(new_target >=. 0.5)),
        ToggleState(..state, target: new_target),
      )
    }

    // Animation tick -> step progress toward the target value.
    TimerTick(tag: "animate", ..) -> {
      let new_progress = approach(state.progress, state.target, 0.06)
      #(UpdateState, ToggleState(..state, progress: new_progress))
    }

    // All other events consumed.
    _ -> #(Consumed, state)
  }
}

// -- Render -------------------------------------------------------------------

fn render(id: String, _props: Nil, state: ToggleState) -> Node {
  let progress = state.progress
  let eased = smoothstep(progress)
  let half_h = int.to_float(track_h) /. 2.0
  let thumb_x = lerp(half_h, int.to_float(track_w) -. half_h, eased)
  let track_color = lerp_color(#(253, 230, 138), #(91, 33, 182), eased)
  let rotation = eased *. pi()
  let face_color = case progress <. 0.5 {
    True -> "#665500"
    False -> "#4c1d95"
  }

  let ring_pad = 4

  let shapes = [
    shape.group(
      [
        // Track
        shape.rect(0.0, 0.0, int.to_float(track_w), int.to_float(track_h), [
          shape.Fill(track_color),
          shape.Rotation(0.0),
        ])
          |> set_radius(half_h),
        // Thumb circle
        shape.circle(thumb_x, half_h, thumb_r, [shape.Fill("#ffffff")]),
        // Face drawn inside a transform group (rotates during transition)
        shape.group(
          [
            shape.circle(-3.5, -3.0, 2.0, [shape.Fill(face_color)]),
            shape.circle(3.5, -3.0, 2.0, [shape.Fill(face_color)]),
            shape.path(smile_path(), [
              shape.Stroke(shape.stroke(face_color, 2.0, [])),
            ]),
          ],
          [
            shape.Transforms([
              shape.translate(thumb_x, half_h),
              shape.rotate(rotation),
            ]),
          ],
        ),
      ],
      [shape.X(int.to_float(ring_pad)), shape.Y(int.to_float(ring_pad))],
    )
    |> shape.interactive("switch", [
      shape.OnClick(True),
      shape.Cursor("pointer"),
      shape.HitRect(
        x: 0.0,
        y: 0.0,
        w: int.to_float(track_w),
        h: int.to_float(track_h),
      ),
      shape.FocusRingRadius(half_h +. int.to_float(ring_pad)),
      shape.A11y(
        node.DictVal(
          dict.from_list([
            #("role", node.StringVal("switch")),
            #("label", node.StringVal("Dark humor")),
            #("toggled", node.BoolVal(progress >=. 0.5)),
          ]),
        ),
      ),
    ]),
  ]

  canvas.new(
    id,
    length.Fixed(int.to_float(track_w + ring_pad * 2)),
    length.Fixed(int.to_float(track_h + ring_pad * 2)),
  )
  |> canvas.alt("Theme toggle")
  |> canvas.layers(dict.from_list([#("toggle", shapes)]))
  |> canvas.build()
}

fn smile_path() -> List(shape.PathCommand) {
  [
    shape.MoveTo(x: -5.0, y: 1.0),
    shape.LineTo(x: -3.0, y: 5.0),
    shape.LineTo(x: 3.0, y: 5.0),
    shape.LineTo(x: 5.0, y: 1.0),
  ]
}

fn smoothstep(t: Float) -> Float {
  case t <=. 0.0 {
    True -> 0.0
    False ->
      case t >=. 1.0 {
        True -> 1.0
        False -> t *. t *. { 3.0 -. 2.0 *. t }
      }
  }
}

fn approach(current: Float, target: Float, step: Float) -> Float {
  case current <. target {
    True -> float.min(current +. step, target)
    False ->
      case current >. target {
        True -> float.max(current -. step, target)
        False -> current
      }
  }
}

fn lerp(a: Float, b: Float, t: Float) -> Float {
  a +. { b -. a } *. t
}

fn lerp_color(c1: #(Int, Int, Int), c2: #(Int, Int, Int), t: Float) -> String {
  let r = float.round(lerp(int.to_float(c1.0), int.to_float(c2.0), t))
  let g = float.round(lerp(int.to_float(c1.1), int.to_float(c2.1), t))
  let b = float.round(lerp(int.to_float(c1.2), int.to_float(c2.2), t))
  "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b)
}

fn hex_byte(n: Int) -> String {
  let n = int.max(0, int.min(255, n))
  let high = n / 16
  let low = n % 16
  hex_digit(high) <> hex_digit(low)
}

fn hex_digit(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    _ -> "f"
  }
}

/// Set a radius on a rect shape's PropValue dict.
fn set_radius(shape_val: PropValue, r: Float) -> PropValue {
  let assert node.DictVal(d) = shape_val
  node.DictVal(dict.insert(d, "radius", node.FloatVal(r)))
}

@external(erlang, "math", "pi")
fn pi() -> Float
