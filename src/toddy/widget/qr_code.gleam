//// QR code widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type QrCode {
  QrCode(
    id: String,
    data: String,
    cell_size: Option(Int),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, data: String) -> QrCode {
  QrCode(id:, data:, cell_size: None, style: None, a11y: None)
}

pub fn cell_size(qr: QrCode, s: Int) -> QrCode {
  QrCode(..qr, cell_size: option.Some(s))
}

pub fn style(qr: QrCode, s: String) -> QrCode {
  QrCode(..qr, style: option.Some(s))
}

pub fn a11y(qr: QrCode, a: A11y) -> QrCode {
  QrCode(..qr, a11y: option.Some(a))
}

pub fn build(qr: QrCode) -> Node {
  let props =
    dict.new()
    |> build.put_string("data", qr.data)
    |> build.put_optional_int("cell_size", qr.cell_size)
    |> build.put_optional_string("style", qr.style)
    |> build.put_optional("a11y", qr.a11y, a11y.to_prop_value)
  Node(id: qr.id, kind: "qr_code", props:, children: [])
}
