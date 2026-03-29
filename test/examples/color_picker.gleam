//// HSV color picker using a custom widget.
////
//// The color picker widget handles all interaction internally (mouse drag,
//// keyboard adjustment, focus tracking). The app receives semantic "change"
//// events with the current HSV values.

import examples/widgets/color_picker_widget
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetEvent}
import plushie/node.{type Node}
import plushie/prop/a11y
import plushie/prop/border
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/text
import plushie/widget/window

// -- Model --------------------------------------------------------------------

pub type Model {
  Model(hue: Float, saturation: Float, value: Float)
}

fn init() {
  #(Model(hue: 0.0, saturation: 1.0, value: 1.0), command.none())
}

// -- Update -------------------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    // ColorPickerWidget emits "change" with { hue, saturation, value }.
    WidgetEvent(kind: "change", id: "picker", data: data, ..) ->
      case decode.run(data, hsv_decoder()) {
        Ok(#(hue, saturation, value)) -> #(
          Model(hue: hue, saturation: saturation, value: value),
          command.none(),
        )
        Error(_) -> #(model, command.none())
      }

    _ -> #(model, command.none())
  }
}

fn hsv_decoder() -> decode.Decoder(#(Float, Float, Float)) {
  use h <- decode.field("hue", decode.float)
  use s <- decode.field("saturation", decode.float)
  use v <- decode.field("value", decode.float)
  decode.success(#(h, s, v))
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

  ui.window("color_picker", [window.Title("Color Picker")], [
    ui.column(
      "content",
      [
        column.Padding(padding.all(20.0)),
        column.Spacing(16),
      ],
      [
        color_picker_widget.widget("picker"),
        ui.row("info", [row.Spacing(16)], [
          ui.container(
            "swatch",
            [
              container.Width(length.Fixed(48.0)),
              container.Height(length.Fixed(48.0)),
              container.BgColor(unsafe_color(hex)),
              container.Border(
                border.new()
                |> border.width(1.0)
                |> border.color(unsafe_color("#cccccc"))
                |> border.radius(4.0),
              ),
              container.A11y(
                a11y.new()
                |> a11y.role(a11y.Image)
                |> a11y.label("Selected color: " <> hex),
              ),
            ],
            [],
          ),
          ui.column("color_info", [column.Spacing(4)], [
            ui.text("hex_display", hex, [
              text.Size(18.0),
              text.A11y(
                a11y.new()
                |> a11y.live("polite")
                |> a11y.busy(
                  model.hue == 0.0
                  && model.saturation == 1.0
                  && model.value == 1.0,
                ),
              ),
            ]),
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
