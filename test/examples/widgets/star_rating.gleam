//// Canvas-based star rating widget.
////
//// Renders 5 stars as a radio group. Interactive by default (click to
//// rate, hover to preview, Tab/arrow to navigate, Enter/Space to select).
//// Pass `Readonly(True)` for a display-only version.
////
////     star_rating.render("my-rating", model.rating, [
////       star_rating.Hover(model.hover_star),
////       star_rating.ThemeProgress(p),
////     ])
////
////     // Read-only (small, for review display)
////     star_rating.render("review-stars", 4, [
////       star_rating.Readonly(True),
////       star_rating.Scale(0.4),
////       star_rating.ThemeProgress(p),
////     ])
////
//// Events: `CanvasElementClick` with element_id "star-0" through "star-4".
//// Hover: `CanvasElementEnter`/`CanvasElementLeave` with the same element_ids.
//// Focus: `CanvasElementFocused` with element_id for keyboard focus.

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import plushie/canvas/shape
import plushie/node.{type Node, DictVal, FloatVal, StringVal}
import plushie/prop/a11y
import plushie/prop/length
import plushie/widget/canvas

pub type StarRatingOpt {
  Hover(Option(Int))
  ThemeProgress(Float)
  Readonly(Bool)
  Scale(Float)
}

/// Render a star rating canvas widget.
///
/// `rating` is the current selection (0-5).
pub fn render(id: String, rating: Int, opts: List(StarRatingOpt)) -> Node {
  let #(hover_star, theme_progress, readonly, scale) =
    list.fold(opts, #(option.None, 0.0, False, 1.0), fn(acc, opt) {
      let #(h, tp, ro, sc) = acc
      case opt {
        Hover(v) -> #(v, tp, ro, sc)
        ThemeProgress(v) -> #(h, v, ro, sc)
        Readonly(v) -> #(h, tp, v, sc)
        Scale(v) -> #(h, tp, ro, v)
      }
    })

  let outer_r = 13.0 *. scale
  let inner_r = 5.0 *. scale
  let size = float.round(30.0 *. scale)
  let gap = float.round(2.0 *. scale)
  let display = case hover_star {
    option.Some(h) -> h
    option.None -> rating
  }
  let w = 5 * size + 4 * gap

  let commands = star_commands(outer_r, inner_r)

  case readonly {
    True ->
      canvas.new(
        id,
        length.Fixed(int.to_float(w)),
        length.Fixed(int.to_float(size)),
      )
      |> canvas.alt(int.to_string(rating) <> " out of 5 stars")
      |> canvas.layers(
        dict.from_list([
          #(
            "stars",
            range(0, 4)
              |> list.map(fn(i) {
                let cx = int.to_float(i * { size + gap } + size / 2)
                let cy = int.to_float(size / 2)
                shape.group(
                  [
                    shape.path(commands, [
                      shape.Fill(star_color(i < rating, False, theme_progress)),
                    ]),
                  ],
                  [shape.X(cx), shape.Y(cy)],
                )
              }),
          ),
        ]),
      )
      |> canvas.build()

    False ->
      canvas.new(
        id,
        length.Fixed(int.to_float(w)),
        length.Fixed(int.to_float(size)),
      )
      |> canvas.alt("Star rating")
      |> canvas.role("radiogroup")
      |> canvas.layers(
        dict.from_list([
          #(
            "stars",
            range(0, 4)
              |> list.map(fn(i) {
                let cx = int.to_float(i * { size + gap } + size / 2)
                let cy = int.to_float(size / 2)
                let filled = i < display
                let preview =
                  option.is_some(hover_star)
                  && {
                    case hover_star {
                      option.Some(h) -> i < h && i >= rating
                      option.None -> False
                    }
                  }

                shape.group(
                  [
                    shape.path(commands, [
                      shape.Fill(star_color(filled, preview, theme_progress)),
                    ]),
                  ],
                  [shape.X(cx), shape.Y(cy)],
                )
                |> shape.interactive("star-" <> int.to_string(i), [
                  shape.OnClick(True),
                  shape.OnHover(True),
                  shape.Cursor("pointer"),
                  shape.FocusStyle(
                    DictVal(
                      dict.from_list([
                        #("stroke", StringVal("#3b82f6")),
                        #("stroke_width", FloatVal(2.0 *. scale)),
                      ]),
                    ),
                  ),
                  shape.ShowFocusRing(False),
                  shape.A11y(
                    a11y.new()
                    |> a11y.role(a11y.RadioButton)
                    |> a11y.label(
                      int.to_string(i + 1)
                      <> " star"
                      <> case i {
                        0 -> ""
                        _ -> "s"
                      },
                    )
                    |> a11y.selected(rating >= i + 1)
                    |> a11y.position_in_set(i + 1)
                    |> a11y.size_of_set(5)
                    |> a11y.to_prop_value(),
                  ),
                ])
              }),
          ),
        ]),
      )
      |> canvas.build()
  }
}

fn star_commands(outer_r: Float, inner_r: Float) -> List(shape.PathCommand) {
  let points =
    range(0, 9)
    |> list.map(fn(i) {
      let angle = int.to_float(i) *. { pi() /. 5.0 } -. { pi() /. 2.0 }
      let r = case i % 2 == 0 {
        True -> outer_r
        False -> inner_r
      }
      #(r *. cos(angle), r *. sin(angle))
    })

  case points {
    [#(fx, fy), ..rest] ->
      [shape.MoveTo(fx, fy), ..list.map(rest, fn(p) { shape.LineTo(p.0, p.1) })]
      |> list.append([shape.Close])
    [] -> []
  }
}

fn star_color(filled: Bool, preview: Bool, progress: Float) -> String {
  case filled, preview {
    True, False -> "#f59e0b"
    _, True -> "#fcd34d"
    False, False -> {
      let r = float.round(209.0 +. { 74.0 -. 209.0 } *. progress)
      let g = float.round(213.0 +. { 74.0 -. 213.0 } *. progress)
      let b = float.round(219.0 +. { 94.0 -. 219.0 } *. progress)
      "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b)
    }
  }
}

fn hex_byte(n: Int) -> String {
  let hi = n / 16
  let lo = n % 16
  hex_digit(hi) <> hex_digit(lo)
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

fn range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..range(from + 1, to)]
  }
}

// -- FFI (Erlang math) --------------------------------------------------------

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float
