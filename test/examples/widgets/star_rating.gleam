//// Canvas-based star rating widget.
////
//// Renders 5 stars. Interactive by default (click to rate, hover to
//// preview, keyboard navigation). Pass `Readonly(True)` for display-only.
////
////     // Interactive (full size)
////     star_rating.render("my-rating", model.rating, [
////       star_rating.Hover(model.hover_star),
////       star_rating.Focused(model.focused_star),
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
import plushie/node.{type Node, type PropValue}
import plushie/prop/length
import plushie/widget/canvas

/// Options for star rating rendering.
pub type StarRatingOpt {
  Hover(Option(Int))
  Focused(Option(Int))
  ThemeProgress(Float)
  Readonly(Bool)
  Scale(Float)
}

/// Render a star rating canvas widget.
///
/// `rating` is the current selection (0-5).
pub fn render(id: String, rating: Int, opts: List(StarRatingOpt)) -> Node {
  let #(hover_star, focused_star, theme_progress, readonly, scale) =
    list.fold(opts, #(option.None, option.None, 0.0, False, 1.0), fn(acc, opt) {
      let #(h, f, tp, ro, sc) = acc
      case opt {
        Hover(v) -> #(v, f, tp, ro, sc)
        Focused(v) -> #(h, v, tp, ro, sc)
        ThemeProgress(v) -> #(h, f, v, ro, sc)
        Readonly(v) -> #(h, f, tp, v, sc)
        Scale(v) -> #(h, f, tp, ro, v)
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
  let focus_r = outer_r +. 3.0 *. scale

  let commands = star_commands(outer_r, inner_r)

  canvas.new(
    id,
    length.Fixed(int.to_float(w)),
    length.Fixed(int.to_float(size)),
  )
  |> canvas.layers(
    dict.from_list([
      #(
        "stars",
        build_stars(
          display,
          rating,
          hover_star,
          focused_star,
          readonly,
          theme_progress,
          commands,
          size,
          gap,
          focus_r,
          scale,
        ),
      ),
    ]),
  )
  |> canvas.build()
}

fn build_stars(
  display: Int,
  rating: Int,
  hover_star: Option(Int),
  focused_star: Option(Int),
  readonly: Bool,
  theme_progress: Float,
  commands: List(shape.PathCommand),
  size: Int,
  gap: Int,
  focus_r: Float,
  scale: Float,
) -> List(PropValue) {
  range(0, 4)
  |> list.map(fn(i) {
    let cx = int.to_float(i * { size + gap } + size / 2)
    let cy = int.to_float(size / 2)
    let filled = i < display
    let preview =
      !readonly
      && option.is_some(hover_star)
      && {
        case hover_star {
          option.Some(h) -> i < h && i >= rating
          option.None -> False
        }
      }
    let is_focused =
      !readonly
      && {
        case focused_star {
          option.Some(f) -> f == i
          option.None -> False
        }
      }

    case readonly {
      True ->
        shape.group(
          [
            shape.path(commands, [
              shape.Fill(star_color(filled, False, theme_progress)),
            ]),
          ],
          [shape.X(cx), shape.Y(cy)],
        )
      False -> {
        let focus_shapes = case is_focused {
          True -> [
            shape.circle(0.0, 0.0, focus_r, [
              shape.Stroke(shape.stroke("#3b82f6", 2.0 *. scale, [])),
            ]),
          ]
          False -> []
        }

        shape.group(
          list.flatten([
            focus_shapes,
            [
              shape.path(commands, [
                shape.Fill(star_color(filled, preview, theme_progress)),
              ]),
            ],
          ]),
          [shape.X(cx), shape.Y(cy)],
        )
        |> shape.interactive("star-" <> int.to_string(i), [
          shape.OnClick(True),
          shape.OnHover(True),
          shape.Cursor("pointer"),
          shape.A11y(
            node.DictVal(
              dict.from_list([
                #("role", node.StringVal("button")),
                #(
                  "label",
                  node.StringVal(
                    int.to_string(i + 1)
                    <> " star"
                    <> case i {
                      0 -> ""
                      _ -> "s"
                    },
                  ),
                ),
              ]),
            ),
          ),
        ])
      }
    }
  })
}

fn star_commands(outer_r: Float, inner_r: Float) -> List(shape.PathCommand) {
  let points =
    range(0, 9)
    |> list.map(fn(i) {
      let angle = int.to_float(i) *. pi() /. 5.0 -. pi() /. 2.0
      let r = case i % 2 == 0 {
        True -> outer_r
        False -> inner_r
      }
      #(r *. cos(angle), r *. sin(angle))
    })

  case points {
    [#(fx, fy), ..rest] ->
      list.flatten([
        [shape.MoveTo(x: fx, y: fy)],
        list.map(rest, fn(pt) { shape.LineTo(x: pt.0, y: pt.1) }),
        [shape.Close],
      ])
    _ -> []
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

fn range(from: Int, to: Int) -> List(Int) {
  int.range(from:, to:, with: [], run: fn(acc, i) { [i, ..acc] })
  |> list.reverse
}

// -- FFI (Erlang math) --------------------------------------------------------

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float
