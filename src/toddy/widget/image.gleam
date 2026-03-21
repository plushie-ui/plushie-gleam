//// Image widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, type PropValue, DictVal, IntVal, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/content_fit.{type ContentFit}
import toddy/prop/filter_method.{type FilterMethod}
import toddy/prop/length.{type Length}
import toddy/widget/build

/// Crop rectangle for image cropping (integer pixel values).
pub type Crop {
  Crop(x: Int, y: Int, width: Int, height: Int)
}

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
    filter_method: Option(FilterMethod),
    expand: Option(Bool),
    scale: Option(Float),
    crop: Option(Crop),
    alt: Option(String),
    description: Option(String),
    decorative: Option(Bool),
    a11y: Option(A11y),
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
    filter_method: None,
    expand: None,
    scale: None,
    crop: None,
    alt: None,
    description: None,
    decorative: None,
    a11y: None,
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

pub fn filter_method(img: Image, f: FilterMethod) -> Image {
  Image(..img, filter_method: option.Some(f))
}

pub fn expand(img: Image, e: Bool) -> Image {
  Image(..img, expand: option.Some(e))
}

pub fn scale(img: Image, s: Float) -> Image {
  Image(..img, scale: option.Some(s))
}

pub fn crop(img: Image, c: Crop) -> Image {
  Image(..img, crop: option.Some(c))
}

pub fn alt(img: Image, a: String) -> Image {
  Image(..img, alt: option.Some(a))
}

pub fn description(img: Image, d: String) -> Image {
  Image(..img, description: option.Some(d))
}

pub fn decorative(img: Image, d: Bool) -> Image {
  Image(..img, decorative: option.Some(d))
}

pub fn a11y(img: Image, a: A11y) -> Image {
  Image(..img, a11y: option.Some(a))
}

fn crop_to_prop_value(c: Crop) -> PropValue {
  DictVal(
    dict.from_list([
      #("x", IntVal(c.x)),
      #("y", IntVal(c.y)),
      #("width", IntVal(c.width)),
      #("height", IntVal(c.height)),
    ]),
  )
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
    |> build.put_optional(
      "filter_method",
      img.filter_method,
      filter_method.to_prop_value,
    )
    |> build.put_optional_bool("expand", img.expand)
    |> build.put_optional_float("scale", img.scale)
    |> build.put_optional("crop", img.crop, crop_to_prop_value)
    |> build.put_optional_string("alt", img.alt)
    |> build.put_optional_string("description", img.description)
    |> build.put_optional_bool("decorative", img.decorative)
    |> build.put_optional("a11y", img.a11y, a11y.to_prop_value)
  Node(id: img.id, kind: "image", props:, children: [])
}
