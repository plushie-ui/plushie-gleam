//// Canvas-based HSV color picker widget.
////
//// A hue ring surrounds a saturation/value square. Drag the ring to
//// select a hue; drag the square to adjust saturation and value.
//// Keyboard accessible: Tab to focus cursors, arrow keys to adjust.
////
////     color_picker_widget.widget("picker")
////
//// Events:
//// - `WidgetEvent(kind: "change")` with data containing hue, saturation, value

import gleam/dict
import gleam/dynamic
import gleam/float
import gleam/int
import gleam/list
import plushie/canvas/shape
import plushie/widget.{
  type WidgetDef, type EventAction, WidgetDef, Consumed, Emit,
  UpdateState,
}
import plushie/event.{
  type Event, CanvasElementKeyPress, CanvasMove, CanvasPress, CanvasRelease,
}
import plushie/node.{type Node, type PropValue, DictVal, FloatVal, StringVal}
import plushie/prop/a11y
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

const fine_step = 1.0

const coarse_step = 15.0

const sv_fine_step = 0.01

const sv_coarse_step = 0.1

// -- Types --------------------------------------------------------------------

pub type DragTarget {
  DragNone
  DragRing
  DragSquare
}

pub type PickerState {
  PickerState(hue: Float, saturation: Float, value: Float, drag: DragTarget)
}

// -- Widget definition --------------------------------------------------------

pub fn def() -> WidgetDef(PickerState, Nil) {
  WidgetDef(
    init: fn() {
      PickerState(hue: 0.0, saturation: 1.0, value: 1.0, drag: DragNone)
    },
    render: render,
    handle_event: handle_event,
    subscriptions: fn(_, _) { [] },
  )
}

/// Build a color picker widget placeholder.
pub fn widget(id: String) -> Node {
  widget.build(def(), id, Nil)
}

// -- Geometry accessors (for consumers) ---------------------------------------

fn cx() -> Float {
  int.to_float(canvas_sz) /. 2.0
}

fn cy() -> Float {
  int.to_float(canvas_sz) /. 2.0
}

// -- Event handler ------------------------------------------------------------

fn handle_event(event: Event, state: PickerState) -> #(EventAction, PickerState) {
  case event {
    CanvasPress(x: x, y: y, button: event.LeftButton, ..) -> {
      let dx = x -. cx()
      let dy = y -. cy()
      let dist = sqrt(dx *. dx +. dy *. dy)
      case dist >=. inner_radius && dist <=. outer_radius {
        True -> {
          let new_state =
            PickerState(..state, drag: DragRing, hue: hue_from_point(dx, dy))
          #(Emit(kind: "change", data: hsv_data(new_state)), new_state)
        }
        False ->
          case in_square(x, y) {
            True -> {
              let new_state =
                apply_sv(PickerState(..state, drag: DragSquare), x, y)
              #(Emit(kind: "change", data: hsv_data(new_state)), new_state)
            }
            False -> #(Consumed, state)
          }
      }
    }

    CanvasMove(x: x, y: y, ..) ->
      case state.drag {
        DragRing -> {
          let new_state =
            PickerState(..state, hue: hue_from_point(x -. cx(), y -. cy()))
          #(Emit(kind: "change", data: hsv_data(new_state)), new_state)
        }
        DragSquare -> {
          let new_state = apply_sv(state, x, y)
          #(Emit(kind: "change", data: hsv_data(new_state)), new_state)
        }
        DragNone -> #(Consumed, state)
      }

    CanvasRelease(..) -> #(UpdateState, PickerState(..state, drag: DragNone))

    CanvasElementKeyPress(
      element_id: "hue-cursor",
      key: key,
      modifiers: mods,
      ..,
    ) -> handle_hue_key(key, mods, state)

    CanvasElementKeyPress(
      element_id: "sv-cursor",
      key: key,
      modifiers: mods,
      ..,
    ) -> handle_sv_key(key, mods, state)

    _ -> #(Consumed, state)
  }
}

// -- Keyboard ----------------------------------------------------------------

fn handle_hue_key(
  key: String,
  mods: event.Modifiers,
  state: PickerState,
) -> #(EventAction, PickerState) {
  let step = case mods.shift {
    True -> coarse_step
    False -> fine_step
  }

  let new_hue = case key {
    "ArrowRight" | "ArrowUp" -> fmod(state.hue +. step, 360.0)
    "ArrowLeft" | "ArrowDown" -> fmod(state.hue -. step +. 360.0, 360.0)
    "PageUp" -> fmod(state.hue +. coarse_step, 360.0)
    "PageDown" -> fmod(state.hue -. coarse_step +. 360.0, 360.0)
    "Home" -> 0.0
    "End" -> 359.0
    _ -> state.hue
  }

  case new_hue != state.hue {
    True -> {
      let new_state = PickerState(..state, hue: new_hue)
      #(Emit(kind: "change", data: hsv_data(new_state)), new_state)
    }
    False -> #(Consumed, state)
  }
}

fn handle_sv_key(
  key: String,
  mods: event.Modifiers,
  state: PickerState,
) -> #(EventAction, PickerState) {
  let step = case mods.shift {
    True -> sv_coarse_step
    False -> sv_fine_step
  }

  let #(new_s, new_v) = case key {
    "ArrowRight" -> #(clamp(state.saturation +. step, 0.0, 1.0), state.value)
    "ArrowLeft" -> #(clamp(state.saturation -. step, 0.0, 1.0), state.value)
    "ArrowUp" -> #(state.saturation, clamp(state.value +. step, 0.0, 1.0))
    "ArrowDown" -> #(state.saturation, clamp(state.value -. step, 0.0, 1.0))
    "PageUp" ->
      case mods.shift {
        True -> #(
          clamp(state.saturation +. sv_coarse_step, 0.0, 1.0),
          state.value,
        )
        False -> #(
          state.saturation,
          clamp(state.value +. sv_coarse_step, 0.0, 1.0),
        )
      }
    "PageDown" ->
      case mods.shift {
        True -> #(
          clamp(state.saturation -. sv_coarse_step, 0.0, 1.0),
          state.value,
        )
        False -> #(
          state.saturation,
          clamp(state.value -. sv_coarse_step, 0.0, 1.0),
        )
      }
    "Home" ->
      case mods.shift {
        True -> #(0.0, state.value)
        False -> #(state.saturation, 1.0)
      }
    "End" ->
      case mods.shift {
        True -> #(1.0, state.value)
        False -> #(state.saturation, 0.0)
      }
    _ -> #(state.saturation, state.value)
  }

  case new_s != state.saturation || new_v != state.value {
    True -> {
      let new_state = PickerState(..state, saturation: new_s, value: new_v)
      #(Emit(kind: "change", data: hsv_data(new_state)), new_state)
    }
    False -> #(Consumed, state)
  }
}

// -- Render -------------------------------------------------------------------

fn render(id: String, _props: Nil, state: PickerState) -> Node {
  canvas.new(
    id,
    length.Fixed(int.to_float(canvas_sz)),
    length.Fixed(int.to_float(canvas_sz)),
  )
  |> canvas.on_press(True)
  |> canvas.on_release(True)
  |> canvas.on_move(True)
  |> canvas.alt("HSV color picker")
  |> canvas.layers(
    dict.from_list([
      #("a_ring", ring_layer()),
      #("b_sv_hue", sv_hue_layer(state.hue)),
      #("c_sv_dark", sv_dark_layer()),
      #("d_cursors", cursors_layer(state)),
    ]),
  )
  |> canvas.build()
}

// -- Cursors ------------------------------------------------------------------

fn cursors_layer(state: PickerState) -> List(PropValue) {
  let mid_r = { inner_radius +. outer_radius } /. 2.0
  let angle = { state.hue -. 90.0 } *. pi() /. 180.0
  let ring_x = cx() +. mid_r *. cos(angle)
  let ring_y = cy() +. mid_r *. sin(angle)

  let sv_x = sq_orig +. state.saturation *. sq_sz
  let sv_y = sq_orig +. { 1.0 -. state.value } *. sq_sz

  let cursor_stroke = shape.stroke("#333333", 2.0, [])
  let focus_stroke =
    DictVal(
      dict.from_list([
        #(
          "stroke",
          DictVal(
            dict.from_list([
              #("color", StringVal("#3b82f6")),
              #("width", FloatVal(3.0)),
            ]),
          ),
        ),
      ]),
    )

  [
    shape.group(
      [
        shape.circle(0.0, 0.0, cursor_radius, [
          shape.Fill("#ffffff"),
          shape.Stroke(cursor_stroke),
        ]),
      ],
      [shape.X(ring_x), shape.Y(ring_y)],
    )
      |> shape.interactive("hue-cursor", [
        shape.Focusable(True),
        shape.OnClick(True),
        shape.FocusStyle(focus_stroke),
        shape.ShowFocusRing(False),
        shape.A11y(
          a11y.new()
          |> a11y.role(a11y.Slider)
          |> a11y.label("Hue")
          |> a11y.value(int.to_string(float.round(state.hue)) <> " degrees")
          |> a11y.orientation(a11y.Horizontal)
          |> a11y.to_prop_value(),
        ),
      ]),
    shape.group(
      [
        shape.circle(0.0, 0.0, cursor_radius, [
          shape.Fill("#ffffff"),
          shape.Stroke(cursor_stroke),
        ]),
      ],
      [shape.X(sv_x), shape.Y(sv_y)],
    )
      |> shape.interactive("sv-cursor", [
        shape.Focusable(True),
        shape.OnClick(True),
        shape.FocusStyle(focus_stroke),
        shape.ShowFocusRing(False),
        shape.A11y(
          a11y.new()
          |> a11y.role(a11y.Slider)
          |> a11y.label("Saturation and brightness")
          |> a11y.value(
            int.to_string(float.round(state.saturation *. 100.0))
            <> "% saturation, "
            <> int.to_string(float.round(state.value *. 100.0))
            <> "% brightness",
          )
          |> a11y.orientation(a11y.Horizontal)
          |> a11y.to_prop_value(),
        ),
      ]),
  ]
}

// -- Ring layer ---------------------------------------------------------------

fn ring_layer() -> List(PropValue) {
  let deg_per_segment = 360.0 /. int.to_float(segments)
  range_list(0, segments - 1)
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

// -- Hit testing --------------------------------------------------------------

fn in_square(x: Float, y: Float) -> Bool {
  x >=. sq_orig
  && x <=. sq_orig +. sq_sz
  && y >=. sq_orig
  && y <=. sq_orig +. sq_sz
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

fn apply_sv(state: PickerState, x: Float, y: Float) -> PickerState {
  let s = clamp({ x -. sq_orig } /. sq_sz, 0.0, 1.0)
  let v = clamp(1.0 -. { y -. sq_orig } /. sq_sz, 0.0, 1.0)
  PickerState(..state, saturation: s, value: v)
}

fn clamp(val: Float, lo: Float, hi: Float) -> Float {
  float.max(lo, float.min(hi, val))
}

fn hsv_data(state: PickerState) -> dynamic.Dynamic {
  dynamic.properties([
    #(dynamic.string("hue"), dynamic.float(state.hue)),
    #(dynamic.string("saturation"), dynamic.float(state.saturation)),
    #(dynamic.string("value"), dynamic.float(state.value)),
  ])
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

fn range_list(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..range_list(from + 1, to)]
  }
}

// -- FFI (Erlang math) --------------------------------------------------------

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "sqrt")
fn sqrt(x: Float) -> Float

@external(erlang, "math", "atan2")
fn atan2(y: Float, x: Float) -> Float

@external(erlang, "math", "pi")
fn pi() -> Float

@external(erlang, "math", "floor")
fn float_floor(x: Float) -> Float
