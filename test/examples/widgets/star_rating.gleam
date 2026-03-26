//// Canvas-based star rating widget.
////
//// Renders 5 stars as a radio group. Interactive by default (click to
//// rate, hover to preview, Tab/arrow to navigate, Enter/Space to select).
//// Pass `Readonly(True)` for a display-only version.
////
////     star_rating.widget("my-rating", StarRatingProps(rating: 3, ..))
////
////     // Read-only (small, for review display)
////     star_rating.widget("review-stars", StarRatingProps(
////       rating: 4, readonly: True, scale: 0.5, ..
////     ))
////
//// Events:
//// - `WidgetEvent(kind: "select")` with value = star count (1-5)

import gleam/dict
import gleam/dynamic
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/canvas/shape
import plushie/canvas_widget.{
  type CanvasWidgetDef, type EventAction, CanvasWidgetDef, Consumed, Emit,
  UpdateState,
}
import plushie/event.{
  type Event, CanvasElementClick, CanvasElementEnter, CanvasElementLeave,
}
import plushie/node.{type Node, DictVal, FloatVal, StringVal}
import plushie/prop/a11y
import plushie/prop/length
import plushie/widget/canvas

// -- Types --------------------------------------------------------------------

pub type StarRatingProps {
  StarRatingProps(
    rating: Int,
    readonly: Bool,
    scale: Float,
    theme_progress: Float,
  )
}

pub type StarState {
  StarState(hover: Option(Int))
}

// -- Widget definition --------------------------------------------------------

pub fn def() -> CanvasWidgetDef(StarState, StarRatingProps) {
  CanvasWidgetDef(
    init: fn() { StarState(hover: None) },
    render: render,
    handle_event: handle_event,
    subscriptions: fn(_, _) { [] },
  )
}

/// Build a star rating canvas widget placeholder.
pub fn widget(id: String, props: StarRatingProps) -> Node {
  canvas_widget.build(def(), id, props)
}

// -- Default props constructor ------------------------------------------------

/// Create props with defaults. Only `rating` is required.
pub fn props(rating: Int) -> StarRatingProps {
  StarRatingProps(
    rating: rating,
    readonly: False,
    scale: 1.0,
    theme_progress: 0.0,
  )
}

/// Set readonly mode.
pub fn readonly(p: StarRatingProps, v: Bool) -> StarRatingProps {
  StarRatingProps(..p, readonly: v)
}

/// Set the scale factor.
pub fn scale(p: StarRatingProps, v: Float) -> StarRatingProps {
  StarRatingProps(..p, scale: v)
}

/// Set the theme interpolation progress (0.0 = light, 1.0 = dark).
pub fn theme_progress(p: StarRatingProps, v: Float) -> StarRatingProps {
  StarRatingProps(..p, theme_progress: v)
}

// -- Event handler ------------------------------------------------------------

fn handle_event(event: Event, state: StarState) -> #(EventAction, StarState) {
  case event {
    // Click on a star -> emit :select with the 1-based star number.
    CanvasElementClick(element_id: element_id, ..) ->
      case parse_star_index(element_id) {
        Ok(n) -> #(Emit(kind: "select", data: dynamic.int(n + 1)), state)
        Error(_) -> #(Consumed, state)
      }

    // Hover enter -> update internal hover state for preview highlight.
    CanvasElementEnter(element_id: element_id, ..) ->
      case parse_star_index(element_id) {
        Ok(n) -> #(UpdateState, StarState(hover: Some(n + 1)))
        Error(_) -> #(Consumed, state)
      }

    // Hover leave -> clear preview highlight.
    CanvasElementLeave(..) -> #(UpdateState, StarState(hover: None))

    // All other events consumed.
    _ -> #(Consumed, state)
  }
}

fn parse_star_index(element_id: String) -> Result(Int, Nil) {
  case string.starts_with(element_id, "star-") {
    True -> {
      let suffix = string.drop_start(element_id, 5)
      case int.parse(suffix) {
        Ok(n) -> Ok(n)
        Error(_) -> Error(Nil)
      }
    }
    False -> Error(Nil)
  }
}

// -- Render -------------------------------------------------------------------

fn render(id: String, props: StarRatingProps, state: StarState) -> Node {
  let rating = props.rating
  let readonly = props.readonly
  let scale_ = props.scale
  let theme_progress_ = props.theme_progress

  let outer_r = 13.0 *. scale_
  let inner_r = 5.0 *. scale_
  let size = float.round(30.0 *. scale_)
  let gap = float.round(2.0 *. scale_)
  let display = case state.hover {
    Some(h) -> h
    None -> rating
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
                      shape.Fill(star_color(i < rating, False, theme_progress_)),
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
                let preview = case state.hover {
                  Some(h) -> i < h && i >= rating
                  None -> False
                }

                shape.group(
                  [
                    shape.path(commands, [
                      shape.Fill(star_color(filled, preview, theme_progress_)),
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
                        #(
                          "stroke",
                          DictVal(
                            dict.from_list([
                              #("color", StringVal("#3b82f6")),
                              #("width", FloatVal(2.0 *. scale_)),
                            ]),
                          ),
                        ),
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
      let angle = pi() /. 2.0 +. int.to_float(i) *. { pi() /. 5.0 }
      let r = case i % 2 == 0 {
        True -> outer_r
        False -> inner_r
      }
      #(r *. cos(angle), 0.0 -. r *. sin(angle))
    })

  case points {
    [#(fx, fy), ..rest] ->
      [shape.MoveTo(fx, fy), ..list.map(rest, fn(p) { shape.LineTo(p.0, p.1) })]
      |> list.append([shape.Close])
    [] -> []
  }
}

fn star_color(filled: Bool, preview: Bool, progress: Float) -> String {
  case preview, filled {
    True, _ -> fade(#(255, 200, 50), #(200, 160, 80), progress)
    False, True -> fade(#(255, 180, 0), #(255, 200, 50), progress)
    False, False -> fade(#(224, 224, 224), #(60, 60, 80), progress)
  }
}

fn fade(c1: #(Int, Int, Int), c2: #(Int, Int, Int), t: Float) -> String {
  let r = float.round(int.to_float(c1.0) +. int.to_float(c2.0 - c1.0) *. t)
  let g = float.round(int.to_float(c1.1) +. int.to_float(c2.1 - c1.1) *. t)
  let b = float.round(int.to_float(c1.2) +. int.to_float(c2.2 - c1.2) *. t)
  "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b)
}

fn hex_byte(n: Int) -> String {
  let n = int.max(0, int.min(255, n))
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
