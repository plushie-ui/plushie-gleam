import gleam/dict
import plushie/node.{FloatVal, StringVal}
import plushie/prop/alignment
import plushie/prop/color
import plushie/prop/ellipsis
import plushie/prop/font
import plushie/prop/length
import plushie/prop/text_direction
import plushie/widget/text

pub fn new_builds_minimal_text_test() {
  let node = text.new("lbl", "Hello") |> text.build()

  assert node.id == "lbl"
  assert node.kind == "text"
  assert node.children == []
  assert dict.get(node.props, "content") == Ok(StringVal("Hello"))
  assert dict.size(node.props) == 2
}

pub fn size_sets_float_prop_test() {
  let node =
    text.new("lbl", "Hi")
    |> text.size(24.0)
    |> text.build()

  assert dict.get(node.props, "size") == Ok(FloatVal(24.0))
}

pub fn color_sets_color_prop_test() {
  let node =
    text.new("lbl", "Hi")
    |> text.color(color.red)
    |> text.build()

  assert dict.get(node.props, "color") == Ok(color.to_prop_value(color.red))
}

pub fn font_sets_font_prop_test() {
  let f = font.Monospace
  let node =
    text.new("lbl", "Hi")
    |> text.font(f)
    |> text.build()

  assert dict.get(node.props, "font") == Ok(font.to_prop_value(f))
}

pub fn width_and_height_test() {
  let node =
    text.new("lbl", "Hi")
    |> text.width(length.Fill)
    |> text.height(length.Fixed(100.0))
    |> text.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(100.0)))
}

pub fn alignment_test() {
  let node =
    text.new("lbl", "Hi")
    |> text.align_x(alignment.Center)
    |> text.align_y(alignment.Top)
    |> text.build()

  assert dict.get(node.props, "align_x")
    == Ok(alignment.to_prop_value(alignment.Center))
  assert dict.get(node.props, "align_y")
    == Ok(alignment.to_prop_value(alignment.Top))
}

pub fn text_direction_sets_text_direction_prop_test() {
  let node =
    text.new("lbl", "Hi")
    |> text.text_direction(text_direction.Rtl)
    |> text.build()

  assert dict.get(node.props, "text_direction")
    == Ok(text_direction.to_prop_value(text_direction.Rtl))
}

pub fn ellipsis_sets_ellipsis_prop_test() {
  let node =
    text.new("lbl", "Hi")
    |> text.ellipsis(ellipsis.Middle)
    |> text.build()

  assert dict.get(node.props, "ellipsis")
    == Ok(ellipsis.to_prop_value(ellipsis.Middle))
}

pub fn omitted_optionals_are_absent_test() {
  let node = text.new("lbl", "Hi") |> text.build()

  assert dict.get(node.props, "size") == Error(Nil)
  assert dict.get(node.props, "color") == Error(Nil)
  assert dict.get(node.props, "font") == Error(Nil)
  assert dict.get(node.props, "text_direction") == Error(Nil)
}
