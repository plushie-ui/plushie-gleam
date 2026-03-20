//// Image widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/content_fit.{type ContentFit}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Image {
  Image(
    id: String,
    source: String,
    width: Option(Length),
    height: Option(Length),
    content_fit: Option(ContentFit),
    rotation: Option(Float),
    opacity: Option(Float),
    border_radius: Option(Float),
  )
}

pub fn new(id: String, source: String) -> Image {
  Image(
    id:,
    source:,
    width: None,
    height: None,
    content_fit: None,
    rotation: None,
    opacity: None,
    border_radius: None,
  )
}

pub fn width(img: Image, w: Length) -> Image {
  Image(..img, width: option.Some(w))
}

pub fn height(img: Image, h: Length) -> Image {
  Image(..img, height: option.Some(h))
}

pub fn content_fit(img: Image, cf: ContentFit) -> Image {
  Image(..img, content_fit: option.Some(cf))
}

pub fn rotation(img: Image, r: Float) -> Image {
  Image(..img, rotation: option.Some(r))
}

pub fn opacity(img: Image, o: Float) -> Image {
  Image(..img, opacity: option.Some(o))
}

pub fn border_radius(img: Image, r: Float) -> Image {
  Image(..img, border_radius: option.Some(r))
}

pub fn build(img: Image) -> Node {
  let props =
    dict.new()
    |> build.put_string("source", img.source)
    |> build.put_optional("width", img.width, length.to_prop_value)
    |> build.put_optional("height", img.height, length.to_prop_value)
    |> build.put_optional(
      "content_fit",
      img.content_fit,
      content_fit.to_prop_value,
    )
    |> build.put_optional_float("rotation", img.rotation)
    |> build.put_optional_float("opacity", img.opacity)
    |> build.put_optional_float("border_radius", img.border_radius)
  Node(id: img.id, kind: "image", props:, children: [])
}
