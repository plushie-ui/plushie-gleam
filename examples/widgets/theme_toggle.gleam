//// Animated emoji theme toggle.
////
//// A toggle switch where the thumb is an emoji face. Light mode shows
//// a smiley; dark mode shows a devil. The emoji rotates during the
//// transition.
////
////     theme_toggle.render("my-toggle", model.toggle_progress, [])
////
//// Events: `CanvasShapeClick` with shape_id "switch".
//// Drive `progress` from 0.0 (light) to 1.0 (dark) with a timer.

import gleam/dict
import gleam/float
import gleam/int
import gleam/string
import plushie/canvas/shape
import plushie/node.{type Node, type PropValue}
import plushie/prop/length
import plushie/widget/canvas

const track_w = 56

const track_h = 28

const thumb_r = 11.0

/// Render the theme toggle canvas widget.
///
/// `progress` ranges from 0.0 (light) to 1.0 (dark).
pub fn render(id: String, progress: Float, _opts: List(Nil)) -> Node {
  let eased = smoothstep(progress)
  let thumb_x = lerp(14.0, 42.0, eased)
  let track_color = lerp_color(#(253, 230, 138), #(91, 33, 182), eased)
  let emoji = case progress <. 0.5 {
    True -> "\u{1F60A}"
    False -> "\u{1F608}"
  }
  let rotation = eased *. pi()

  let shapes = [
    shape.group(
      [
        shape.rect(0.0, 0.0, int.to_float(track_w), int.to_float(track_h), [
          shape.Fill(track_color),
          shape.Rotation(0.0),
        ])
          |> set_radius(int.to_float(track_h) /. 2.0),
        shape.circle(thumb_x, int.to_float(track_h) /. 2.0, thumb_r, [
          shape.Fill("#ffffff"),
        ]),
        shape.push_transform(),
        shape.translate(thumb_x, int.to_float(track_h) /. 2.0),
        shape.rotate(rotation),
        shape.text(0.0, -1.0, emoji, [
          shape.Size(14.0),
          shape.AlignX("center"),
          shape.AlignY("center"),
        ]),
        shape.pop_transform(),
      ],
      [],
    )
    |> shape.interactive([
      shape.InteractiveId("switch"),
      shape.OnClick(True),
      shape.Cursor("pointer"),
    ]),
  ]

  canvas.new(
    id,
    length.Fixed(int.to_float(track_w)),
    length.Fixed(int.to_float(track_h)),
  )
  |> canvas.layers(dict.from_list([#("toggle", shapes)]))
  |> canvas.build()
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

/// Set a radius on a rect shape's PropValue dict. The rect shape builder
/// doesn't expose radius directly, so we patch the dict.
fn set_radius(shape_val: PropValue, r: Float) -> PropValue {
  let assert node.DictVal(d) = shape_val
  node.DictVal(dict.insert(d, "radius", node.FloatVal(r)))
}

@external(erlang, "math", "pi")
fn pi() -> Float
