//// ProgressBar widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, FloatVal, ListVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type ProgressBar {
  ProgressBar(
    id: String,
    range: #(Float, Float),
    value: Float,
    width: Option(Length),
    height: Option(Float),
    style: Option(String),
    vertical: Option(Bool),
    label: Option(String),
    a11y: Option(A11y),
  )
}

/// Create a new progress bar builder.
pub fn new(id: String, range: #(Float, Float), value: Float) -> ProgressBar {
  ProgressBar(
    id:,
    range:,
    value:,
    width: None,
    height: None,
    style: None,
    vertical: None,
    label: None,
    a11y: None,
  )
}

/// Set the width.
pub fn width(pb: ProgressBar, w: Length) -> ProgressBar {
  ProgressBar(..pb, width: option.Some(w))
}

/// Set the height.
pub fn height(pb: ProgressBar, h: Float) -> ProgressBar {
  ProgressBar(..pb, height: option.Some(h))
}

/// Set the style.
pub fn style(pb: ProgressBar, s: String) -> ProgressBar {
  ProgressBar(..pb, style: option.Some(s))
}

/// Set whether the progress bar is vertical.
pub fn vertical(pb: ProgressBar, v: Bool) -> ProgressBar {
  ProgressBar(..pb, vertical: option.Some(v))
}

/// Set the label text.
pub fn label(pb: ProgressBar, l: String) -> ProgressBar {
  ProgressBar(..pb, label: option.Some(l))
}

fn range_to_prop_value(range: #(Float, Float)) -> node.PropValue {
  ListVal([FloatVal(range.0), FloatVal(range.1)])
}

/// Set accessibility properties for this widget.
pub fn a11y(pb: ProgressBar, a: A11y) -> ProgressBar {
  ProgressBar(..pb, a11y: option.Some(a))
}

/// Option type for progress bar properties.
pub type Opt {
  Width(Length)
  Height(Float)
  Style(String)
  Vertical(Bool)
  Label(String)
  A11y(A11y)
}

/// Apply a list of options to a progress bar builder.
pub fn with_opts(pb: ProgressBar, opts: List(Opt)) -> ProgressBar {
  list.fold(opts, pb, fn(p, opt) {
    case opt {
      Width(w) -> width(p, w)
      Height(h) -> height(p, h)
      Style(s) -> style(p, s)
      Vertical(v) -> vertical(p, v)
      Label(l) -> label(p, l)
      A11y(a) -> a11y(p, a)
    }
  })
}

/// Build the progress bar into a renderable Node.
pub fn build(pb: ProgressBar) -> Node {
  let props =
    dict.new()
    |> dict.insert("range", range_to_prop_value(pb.range))
    |> dict.insert("value", FloatVal(pb.value))
    |> build.put_optional("width", pb.width, length.to_prop_value)
    |> build.put_optional_float("height", pb.height)
    |> build.put_optional_string("style", pb.style)
    |> build.put_optional_bool("vertical", pb.vertical)
    |> build.put_optional_string("label", pb.label)
    |> build.put_optional("a11y", pb.a11y, a11y.to_prop_value)
  Node(id: pb.id, kind: "progress_bar", props:, children: [])
}
