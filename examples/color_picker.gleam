//// HSV color picker using the extracted canvas widget.
////
//// A hue ring surrounds a saturation/value square. Drag the ring
//// to select hue; drag the square to adjust saturation and value.
//// Demonstrates composing a reusable canvas widget with app-level
//// hit testing and coordinate math.

import examples/widgets/color_picker_widget
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, CanvasMove, CanvasPress, CanvasRelease}
import plushie/node.{type Node}
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/ui

// -- Model --------------------------------------------------------------------

pub type DragTarget {
  DragNone
  DragRing
  DragSquare
}

pub type Model {
  Model(hue: Float, saturation: Float, value: Float, drag: DragTarget)
}

fn init() {
  #(
    Model(hue: 0.0, saturation: 1.0, value: 1.0, drag: DragNone),
    command.none(),
  )
}

// -- Update -------------------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    CanvasPress(id: "picker", x: x, y: y, button: "left", ..) -> {
      let dx = x -. color_picker_widget.cx()
      let dy = y -. color_picker_widget.cy()
      let dist = sqrt(dx *. dx +. dy *. dy)
      case
        dist >=. color_picker_widget.inner_r()
        && dist <=. color_picker_widget.outer_r()
      {
        True -> #(
          Model(..model, drag: DragRing, hue: hue_from_point(dx, dy)),
          command.none(),
        )
        False ->
          case in_square(x, y) {
            True -> #(
              apply_sv(Model(..model, drag: DragSquare), x, y),
              command.none(),
            )
            False -> #(model, command.none())
          }
      }
    }

    CanvasMove(id: "picker", x: x, y: y, ..) ->
      case model.drag {
        DragRing -> #(
          Model(
            ..model,
            hue: hue_from_point(
              x -. color_picker_widget.cx(),
              y -. color_picker_widget.cy(),
            ),
          ),
          command.none(),
        )
        DragSquare -> #(apply_sv(model, x, y), command.none())
        DragNone -> #(model, command.none())
      }

    CanvasRelease(id: "picker", ..) -> #(
      Model(..model, drag: DragNone),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

// -- Hit testing --------------------------------------------------------------

fn in_square(x: Float, y: Float) -> Bool {
  let origin = color_picker_widget.sq_origin()
  let size = color_picker_widget.sq_size()
  x >=. origin && x <=. origin +. size && y >=. origin && y <=. origin +. size
}

// -- Coordinate math ----------------------------------------------------------

fn hue_from_point(dx: Float, dy: Float) -> Float {
  let angle = atan2(dy, dx)
  let hue = angle +. pi() /. 2.0
  let hue = case hue <. 0.0 {
    True -> hue +. 2.0 *. pi()
    False -> hue
  }
  hue *. 180.0 /. pi()
}

fn apply_sv(model: Model, x: Float, y: Float) -> Model {
  let origin = color_picker_widget.sq_origin()
  let size = color_picker_widget.sq_size()
  let s = clamp({ x -. origin } /. size, 0.0, 1.0)
  let v = clamp(1.0 -. { y -. origin } /. size, 0.0, 1.0)
  Model(..model, saturation: s, value: v)
}

fn clamp(val: Float, lo: Float, hi: Float) -> Float {
  float.max(lo, float.min(hi, val))
}

// -- Color conversion (for display only) --------------------------------------

fn hsv_to_hex(h: Float, s: Float, v: Float) -> String {
  let h = fmod(h, 360.0)
  let h = case h <. 0.0 {
    True -> h +. 360.0
    False -> h
  }
  let c = v *. s
  let h_sector = h /. 60.0
  let x = c *. { 1.0 -. float_abs(fmod(h_sector, 2.0) -. 1.0) }
  let m = v -. c

  let #(r1, g1, b1) = case True {
    _ if h_sector <. 1.0 -> #(c, x, 0.0)
    _ if h_sector <. 2.0 -> #(x, c, 0.0)
    _ if h_sector <. 3.0 -> #(0.0, c, x)
    _ if h_sector <. 4.0 -> #(0.0, x, c)
    _ if h_sector <. 5.0 -> #(x, 0.0, c)
    _ -> #(c, 0.0, x)
  }

  let r = float.round({ r1 +. m } *. 255.0)
  let g = float.round({ g1 +. m } *. 255.0)
  let b = float.round({ b1 +. m } *. 255.0)

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

fn fmod(a: Float, b: Float) -> Float {
  a -. b *. float_floor(a /. b)
}

fn float_abs(x: Float) -> Float {
  case x <. 0.0 {
    True -> 0.0 -. x
    False -> x
  }
}

// -- View ---------------------------------------------------------------------

fn view(model: Model) -> Node {
  let hex = hsv_to_hex(model.hue, model.saturation, model.value)
  let h_int = float.round(model.hue)
  let s_pct = float.round(model.saturation *. 100.0)
  let v_pct = float.round(model.value *. 100.0)

  ui.window("color_picker", [ui.title("Color Picker")], [
    ui.column(
      "content",
      [
        ui.padding(padding.all(20.0)),
        ui.spacing(16),
      ],
      [
        color_picker_widget.render(
          "picker",
          model.hue,
          model.saturation,
          model.value,
        ),
        ui.row("info", [ui.spacing(16)], [
          ui.container(
            "swatch",
            [
              ui.width(length.Fixed(48.0)),
              ui.height(length.Fixed(48.0)),
              ui.background(unsafe_color(hex)),
            ],
            [],
          ),
          ui.column("color_info", [ui.spacing(4)], [
            ui.text("hex_display", hex, [ui.font_size(18.0)]),
            ui.text_(
              "hsv_display",
              "H: "
                <> int.to_string(h_int)
                <> "  S: "
                <> int.to_string(s_pct)
                <> "%  V: "
                <> int.to_string(v_pct)
                <> "%",
            ),
          ]),
        ]),
      ],
    ),
  ])
}

// -- Helpers ------------------------------------------------------------------

fn unsafe_color(hex: String) -> color.Color {
  let assert Ok(c) = color.from_hex(hex)
  c
}

// -- FFI (Erlang math) --------------------------------------------------------

@external(erlang, "math", "sqrt")
fn sqrt(x: Float) -> Float

@external(erlang, "math", "atan2")
fn atan2(y: Float, x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float

@external(erlang, "math", "floor")
fn float_floor(x: Float) -> Float

// -- Entry point --------------------------------------------------------------

pub fn app() {
  app.simple(init, update, view)
}

pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
