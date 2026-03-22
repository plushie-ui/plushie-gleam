//// Canvas-based star rating widget.
////
//// Renders 5 interactive stars. Click to rate, hover to preview.
////
////     star_rating.render("my-rating", 3, option.None, [])
////
//// Events: `CanvasShapeClick` with shape_id "star-0" through "star-4".
//// Hover: `CanvasShapeEnter`/`CanvasShapeLeave` with the same shape_ids.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option}
import plushie/canvas/shape
import plushie/node.{type Node, type PropValue}
import plushie/prop/length
import plushie/widget/canvas

const outer_r = 12.0

const inner_r = 5.0

const size = 28

const gap = 8

/// Options for star rating rendering.
pub type StarRatingOpt {
  Dark(Bool)
}

/// Render a star rating canvas widget.
///
/// `rating` is the current selection (0-5). `hover_star` is the star
/// being hovered (1-5), or None when no hover is active.
pub fn render(
  id: String,
  rating: Int,
  hover_star: Option(Int),
  opts: List(StarRatingOpt),
) -> Node {
  let dark =
    list.fold(opts, False, fn(acc, opt) {
      case opt {
        Dark(d) -> d
        _ -> acc
      }
    })
  let display = case hover_star {
    option.Some(h) -> h
    option.None -> rating
  }
  let w = 5 * size + 4 * gap

  canvas.new(
    id,
    length.Fixed(int.to_float(w)),
    length.Fixed(int.to_float(size)),
  )
  |> canvas.layers(
    dict.from_list([#("stars", build_stars(display, rating, hover_star, dark))]),
  )
  |> canvas.build()
}

fn build_stars(
  display: Int,
  rating: Int,
  hover_star: Option(Int),
  dark: Bool,
) -> List(PropValue) {
  list.range(0, 4)
  |> list.map(fn(i) {
    let cx = int.to_float(i * { size + gap } + size / 2)
    let cy = int.to_float(size / 2)
    let filled = i < display
    let preview = case hover_star {
      option.Some(h) -> i < h && i >= rating
      option.None -> False
    }

    shape.group(
      [
        shape.path(star_commands(), [
          shape.Fill(star_color(filled, preview, dark)),
        ]),
      ],
      [shape.X(cx), shape.Y(cy)],
    )
    |> shape.interactive([
      shape.InteractiveId("star-" <> int.to_string(i)),
      shape.OnClick(True),
      shape.OnHover(True),
      shape.Cursor("pointer"),
    ])
  })
}

fn star_commands() -> List(shape.PathCommand) {
  let points =
    list.range(0, 9)
    |> list.map(fn(i) {
      let angle = int.to_float(i) *. pi() /. 5.0 -. pi() /. 2.0
      let r = case i % 2 == 0 {
        True -> outer_r
        False -> inner_r
      }
      #(r *. cos(angle), r *. sin(angle))
    })

  case points {
    [#(fx, fy), ..rest] -> [
      shape.MoveTo(x: fx, y: fy),
      ..list.map(rest, fn(pt) { shape.LineTo(x: pt.0, y: pt.1) })
    ]
    _ -> []
  }
  |> list.append([shape.Close])
}

fn star_color(filled: Bool, preview: Bool, dark: Bool) -> String {
  case filled, preview, dark {
    True, False, _ -> "#f59e0b"
    _, True, _ -> "#fcd34d"
    False, False, False -> "#d1d5db"
    False, False, True -> "#4a4a5e"
  }
}

// -- FFI (Erlang math) --------------------------------------------------------

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float
