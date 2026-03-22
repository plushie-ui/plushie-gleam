//// Canvas-based HSV color picker widget.
////
//// Renders a hue ring surrounding a saturation/value square. The ring
//// is built from path segments covering the hue spectrum. The SV square
//// uses overlapping linear gradients (hue-to-white horizontal,
//// transparent-to-black vertical). Cursor circles mark the current hue
//// position on the ring and the current SV position in the square.
////
////     color_picker_widget.render("picker", model.hue, model.saturation, model.value)
////
//// Events: `CanvasPress`, `CanvasMove`, `CanvasRelease` with absolute
//// x/y coordinates. The consuming app computes hue angles and SV
//// positions from the geometry accessors.

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import plushie/canvas/shape
import plushie/node.{type Node, type PropValue}
import plushie/prop/length
import plushie/widget/canvas

// -- Geometry constants -------------------------------------------------------

const canvas_sz = 400

const outer_radius = 190.0

const inner_radius = 150.0

const sq_orig = 100.0

const sq_sz = 200.0

const segments = 72

const cursor_radius = 7.0

// -- Geometry accessors (for consumers doing hit testing) ----------------------

/// Canvas size in pixels (square).
pub fn canvas_size() -> Int {
  canvas_sz
}

/// Centre x coordinate.
pub fn cx() -> Float {
  int.to_float(canvas_sz) /. 2.0
}

/// Centre y coordinate.
pub fn cy() -> Float {
  int.to_float(canvas_sz) /. 2.0
}

/// Inner radius of the hue ring.
pub fn inner_r() -> Float {
  inner_radius
}

/// Outer radius of the hue ring.
pub fn outer_r() -> Float {
  outer_radius
}

/// Origin (top-left x and y) of the SV square.
pub fn sq_origin() -> Float {
  sq_orig
}

/// Side length of the SV square.
pub fn sq_size() -> Float {
  sq_sz
}

// -- Public render function ---------------------------------------------------

/// Render the color picker canvas.
pub fn render(id: String, hue: Float, saturation: Float, value: Float) -> Node {
  canvas.new(
    id,
    length.Fixed(int.to_float(canvas_sz)),
    length.Fixed(int.to_float(canvas_sz)),
  )
  |> canvas.on_press(True)
  |> canvas.on_release(True)
  |> canvas.on_move(True)
  |> canvas.layers(
    dict.from_list([
      #("a_ring", ring_layer()),
      #("b_sv_hue", sv_hue_layer(hue)),
      #("c_sv_dark", sv_dark_layer()),
      #("d_cursors", cursors_layer(hue, saturation, value)),
    ]),
  )
  |> canvas.build()
}

// -- Ring layer ---------------------------------------------------------------

fn ring_layer() -> List(PropValue) {
  let deg_per_segment = 360.0 /. int.to_float(segments)
  list.range(0, segments - 1)
  |> list.map(fn(i) {
    let hue_deg = int.to_float(i) *. deg_per_segment
    let a1 = { hue_deg -. 90.0 } *. pi() /. 180.0
    let a2 = { hue_deg +. deg_per_segment -. 90.0 } *. pi() /. 180.0
    let ctr_x = cx()
    let ctr_y = cy()
    shape.path(
      [
        shape.MoveTo(
          x: ctr_x +. inner_radius *. cos(a1),
          y: ctr_y +. inner_radius *. sin(a1),
        ),
        shape.LineTo(
          x: ctr_x +. outer_radius *. cos(a1),
          y: ctr_y +. outer_radius *. sin(a1),
        ),
        shape.LineTo(
          x: ctr_x +. outer_radius *. cos(a2),
          y: ctr_y +. outer_radius *. sin(a2),
        ),
        shape.LineTo(
          x: ctr_x +. inner_radius *. cos(a2),
          y: ctr_y +. inner_radius *. sin(a2),
        ),
        shape.Close,
      ],
      [shape.Fill(hsv_to_hex(hue_deg, 1.0, 1.0))],
    )
  })
}

// -- SV layers ----------------------------------------------------------------

fn sv_hue_layer(hue: Float) -> List(PropValue) {
  let hue_color = hsv_to_hex(hue, 1.0, 1.0)
  [
    shape.rect(sq_orig, sq_orig, sq_sz, sq_sz, [
      shape.GradientFill(
        shape.linear_gradient(
          #(sq_orig, sq_orig),
          #(sq_orig +. sq_sz, sq_orig),
          [#(0.0, "#ffffff"), #(1.0, hue_color)],
        ),
      ),
    ]),
  ]
}

fn sv_dark_layer() -> List(PropValue) {
  [
    shape.rect(sq_orig, sq_orig, sq_sz, sq_sz, [
      shape.GradientFill(
        shape.linear_gradient(
          #(sq_orig, sq_orig),
          #(sq_orig, sq_orig +. sq_sz),
          [#(0.0, "#00000000"), #(1.0, "#000000ff")],
        ),
      ),
    ]),
  ]
}

// -- Cursors ------------------------------------------------------------------

fn cursors_layer(hue: Float, saturation: Float, value: Float) -> List(PropValue) {
  let mid_r = { inner_radius +. outer_radius } /. 2.0
  let angle = { hue -. 90.0 } *. pi() /. 180.0
  let ring_x = cx() +. mid_r *. cos(angle)
  let ring_y = cy() +. mid_r *. sin(angle)

  let sv_x = sq_orig +. saturation *. sq_sz
  let sv_y = sq_orig +. { 1.0 -. value } *. sq_sz

  let cursor_stroke = shape.stroke("#333333", 2.0, [])

  [
    shape.circle(ring_x, ring_y, cursor_radius, [
      shape.Fill("#ffffff"),
      shape.Stroke(cursor_stroke),
    ]),
    shape.circle(sv_x, sv_y, cursor_radius, [
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

// -- FFI (Erlang math) --------------------------------------------------------

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float

@external(erlang, "math", "floor")
fn float_floor(x: Float) -> Float
