//// HSV color picker using the canvas widget.
////
//// A hue ring surrounds a saturation/value square. Drag the ring
//// to select hue; drag the square to adjust saturation and value.
//// Demonstrates canvas layers, path commands, linear gradients,
//// and mouse interaction with coordinate math.

import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import plushie
import plushie/app
import plushie/canvas/shape
import plushie/command
import plushie/event.{type Event, CanvasMove, CanvasPress, CanvasRelease}
import plushie/node.{type Node, type PropValue}
import plushie/prop/length
import plushie/prop/padding
import plushie/ui
import plushie/widget/canvas

// -- Geometry constants -------------------------------------------------------

const canvas_size = 400

const outer_r = 190.0

const inner_r = 150.0

const sq_origin = 100.0

const sq_size = 200.0

const segments = 72

const cursor_r = 7.0

fn cx() -> Float {
  int.to_float(canvas_size) /. 2.0
}

fn cy() -> Float {
  int.to_float(canvas_size) /. 2.0
}

fn mid_r() -> Float {
  { inner_r +. outer_r } /. 2.0
}

// -- Model --------------------------------------------------------------------

type DragTarget {
  DragNone
  DragRing
  DragSquare
}

type Model {
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
      let dx = x -. cx()
      let dy = y -. cy()
      let dist = sqrt(dx *. dx +. dy *. dy)
      case dist >=. inner_r && dist <=. outer_r {
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
          Model(..model, hue: hue_from_point(x -. cx(), y -. cy())),
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
  x >=. sq_origin
  && x <=. sq_origin +. sq_size
  && y >=. sq_origin
  && y <=. sq_origin +. sq_size
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
  let s = clamp({ x -. sq_origin } /. sq_size, 0.0, 1.0)
  let v = clamp(1.0 -. { y -. sq_origin } /. sq_size, 0.0, 1.0)
  Model(..model, saturation: s, value: v)
}

fn clamp(val: Float, lo: Float, hi: Float) -> Float {
  float.max(lo, float.min(hi, val))
}

// -- Layer builders -----------------------------------------------------------

fn build_layers(model: Model) -> dict.Dict(String, List(PropValue)) {
  dict.from_list([
    #("a_ring", ring_layer()),
    #("b_sv_hue", sv_hue_layer(model.hue)),
    #("c_sv_dark", sv_dark_layer()),
    #("d_cursors", cursors_layer(model)),
  ])
}

fn ring_layer() -> List(PropValue) {
  let deg_per_segment = 360.0 /. int.to_float(segments)
  list.range(0, segments - 1)
  |> list.map(fn(i) {
    let hue_deg = int.to_float(i) *. deg_per_segment
    let a1 = { hue_deg -. 90.0 } *. pi() /. 180.0
    let a2 = { hue_deg +. deg_per_segment -. 90.0 } *. pi() /. 180.0
    shape.path(
      [
        shape.MoveTo(
          x: cx() +. inner_r *. cos(a1),
          y: cy() +. inner_r *. sin(a1),
        ),
        shape.LineTo(
          x: cx() +. outer_r *. cos(a1),
          y: cy() +. outer_r *. sin(a1),
        ),
        shape.LineTo(
          x: cx() +. outer_r *. cos(a2),
          y: cy() +. outer_r *. sin(a2),
        ),
        shape.LineTo(
          x: cx() +. inner_r *. cos(a2),
          y: cy() +. inner_r *. sin(a2),
        ),
        shape.Close,
      ],
      [shape.Fill(hsv_to_hex(hue_deg, 1.0, 1.0))],
    )
  })
}

fn sv_hue_layer(hue: Float) -> List(PropValue) {
  let hue_color = hsv_to_hex(hue, 1.0, 1.0)
  [
    shape.rect(sq_origin, sq_origin, sq_size, sq_size, [
      shape.GradientFill(
        shape.linear_gradient(
          #(sq_origin, sq_origin),
          #(sq_origin +. sq_size, sq_origin),
          [#(0.0, "#ffffff"), #(1.0, hue_color)],
        ),
      ),
    ]),
  ]
}

fn sv_dark_layer() -> List(PropValue) {
  [
    shape.rect(sq_origin, sq_origin, sq_size, sq_size, [
      shape.GradientFill(
        shape.linear_gradient(
          #(sq_origin, sq_origin),
          #(sq_origin, sq_origin +. sq_size),
          [#(0.0, "#00000000"), #(1.0, "#000000ff")],
        ),
      ),
    ]),
  ]
}

fn cursors_layer(model: Model) -> List(PropValue) {
  let angle = { model.hue -. 90.0 } *. pi() /. 180.0
  let ring_x = cx() +. mid_r() *. cos(angle)
  let ring_y = cy() +. mid_r() *. sin(angle)

  let sv_x = sq_origin +. model.saturation *. sq_size
  let sv_y = sq_origin +. { 1.0 -. model.value } *. sq_size

  let cursor_stroke = shape.stroke("#333333", 2.0, [])

  [
    shape.circle(ring_x, ring_y, cursor_r, [
      shape.Fill("#ffffff"),
      shape.Stroke(cursor_stroke),
    ]),
    shape.circle(sv_x, sv_y, cursor_r, [
      shape.Fill("#ffffff"),
      shape.Stroke(cursor_stroke),
    ]),
  ]
}

// -- Color conversion ---------------------------------------------------------

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
        canvas.new(
          "picker",
          length.Fixed(int.to_float(canvas_size)),
          length.Fixed(int.to_float(canvas_size)),
        )
          |> canvas.on_press(True)
          |> canvas.on_release(True)
          |> canvas.on_move(True)
          |> canvas.layers(build_layers(model))
          |> canvas.build(),
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

// -- FFI helpers (Erlang math) ------------------------------------------------

@external(erlang, "math", "sqrt")
fn sqrt(x: Float) -> Float

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "atan2")
fn atan2(y: Float, x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float

@external(erlang, "math", "floor")
fn float_floor(x: Float) -> Float

// Color helper -- we know our hex values are valid, so we can
// bypass the Result from color.from_hex by constructing directly
// via the opaque-safe approach. Since Color is opaque and we can't
// construct it directly from outside the module, we use the prop
// value approach via ui.background which accepts Color.
// We need to use color.from_hex and assert Ok.
import plushie/prop/color

fn unsafe_color(hex: String) -> color.Color {
  let assert Ok(c) = color.from_hex(hex)
  c
}

pub fn main() {
  let my_app = app.simple(init, update, view)
  let _ = plushie.start(my_app, plushie.default_start_opts())
  process.sleep_forever()
}
