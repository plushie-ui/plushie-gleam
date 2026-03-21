//// QR code widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/widget/build

pub type ErrorCorrection {
  Low
  Medium
  Quartile
  High
}

pub opaque type QrCode {
  QrCode(
    id: String,
    data: String,
    cell_size: Option(Int),
    cell_color: Option(Color),
    background_color: Option(Color),
    error_correction: Option(ErrorCorrection),
    alt: Option(String),
    description: Option(String),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, data: String) -> QrCode {
  QrCode(
    id:,
    data:,
    cell_size: None,
    cell_color: None,
    background_color: None,
    error_correction: None,
    alt: None,
    description: None,
    style: None,
    a11y: None,
  )
}

pub fn cell_size(qr: QrCode, s: Int) -> QrCode {
  QrCode(..qr, cell_size: option.Some(s))
}

pub fn cell_color(qr: QrCode, c: Color) -> QrCode {
  QrCode(..qr, cell_color: option.Some(c))
}

pub fn background_color(qr: QrCode, c: Color) -> QrCode {
  QrCode(..qr, background_color: option.Some(c))
}

pub fn error_correction(qr: QrCode, ec: ErrorCorrection) -> QrCode {
  QrCode(..qr, error_correction: option.Some(ec))
}

pub fn alt(qr: QrCode, a: String) -> QrCode {
  QrCode(..qr, alt: option.Some(a))
}

pub fn description(qr: QrCode, d: String) -> QrCode {
  QrCode(..qr, description: option.Some(d))
}

pub fn style(qr: QrCode, s: String) -> QrCode {
  QrCode(..qr, style: option.Some(s))
}

pub fn a11y(qr: QrCode, a: A11y) -> QrCode {
  QrCode(..qr, a11y: option.Some(a))
}

fn error_correction_to_string(ec: ErrorCorrection) -> String {
  case ec {
    Low -> "low"
    Medium -> "medium"
    Quartile -> "quartile"
    High -> "high"
  }
}

pub fn build(qr: QrCode) -> Node {
  let props =
    dict.new()
    |> build.put_string("data", qr.data)
    |> build.put_optional_int("cell_size", qr.cell_size)
    |> build.put_optional("cell_color", qr.cell_color, color.to_prop_value)
    |> build.put_optional(
      "background_color",
      qr.background_color,
      color.to_prop_value,
    )
    |> build.put_optional("error_correction", qr.error_correction, fn(ec) {
      StringVal(error_correction_to_string(ec))
    })
    |> build.put_optional_string("alt", qr.alt)
    |> build.put_optional_string("description", qr.description)
    |> build.put_optional_string("style", qr.style)
    |> build.put_optional("a11y", qr.a11y, a11y.to_prop_value)
  Node(id: qr.id, kind: "qr_code", props:, children: [])
}
