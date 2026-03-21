import gleam/dict
import gleam/list
import gleam/option
import plushie/node.{BoolVal, DictVal, FloatVal, ListVal, StringVal}
import plushie/prop/color
import plushie/prop/font
import plushie/prop/length
import plushie/prop/padding
import plushie/prop/wrapping
import plushie/widget/rich_text

pub fn new_builds_minimal_rich_text_test() {
  let node = rich_text.new("rt1") |> rich_text.build()

  assert node.id == "rt1"
  assert node.kind == "rich_text"
  assert node.children == []
  assert dict.size(node.props) == 0
}

pub fn spans_encoded_as_list_of_dicts_test() {
  let s1 = rich_text.span("Hello")
  let s2 =
    rich_text.span("World")
    |> rich_text.span_size(18.0)
    |> rich_text.span_color(color.red)

  let node =
    rich_text.new("rt2")
    |> rich_text.spans([s1, s2])
    |> rich_text.build()

  let assert Ok(ListVal(span_list)) = dict.get(node.props, "spans")
  assert list.length(span_list) == 2

  // First span: only text field
  let assert [DictVal(first), _] = span_list
  assert dict.get(first, "text") == Ok(StringVal("Hello"))
  assert dict.get(first, "size") == Error(Nil)

  // Second span: text, size, color
  let assert [_, DictVal(second)] = span_list
  assert dict.get(second, "text") == Ok(StringVal("World"))
  assert dict.get(second, "size") == Ok(FloatVal(18.0))
  assert dict.get(second, "color") == Ok(color.to_prop_value(color.red))
}

pub fn span_with_link_and_decorations_test() {
  let s =
    rich_text.span("Click me")
    |> rich_text.span_link("https://example.com")
    |> rich_text.span_underline(True)
    |> rich_text.span_strikethrough(False)

  let pv = rich_text.span_to_prop_value(s)
  let assert DictVal(fields) = pv
  assert dict.get(fields, "link") == Ok(StringVal("https://example.com"))
  assert dict.get(fields, "underline") == Ok(BoolVal(True))
  assert dict.get(fields, "strikethrough") == Ok(BoolVal(False))
}

pub fn span_with_font_test() {
  let s =
    rich_text.span("Mono")
    |> rich_text.span_font(font.Monospace)

  let pv = rich_text.span_to_prop_value(s)
  let assert DictVal(fields) = pv
  assert dict.get(fields, "font") == Ok(font.to_prop_value(font.Monospace))
}

pub fn span_with_padding_test() {
  let p = padding.all(4.0)
  let s =
    rich_text.span("Padded")
    |> rich_text.span_padding(p)

  let pv = rich_text.span_to_prop_value(s)
  let assert DictVal(fields) = pv
  assert dict.get(fields, "padding") == Ok(padding.to_prop_value(p))
}

pub fn span_with_highlight_test() {
  let h =
    rich_text.SpanHighlight(
      background: option.Some(color.yellow),
      border_color: option.Some(color.black),
      border_width: option.Some(1.0),
      border_radius: option.Some(rich_text.UniformRadius(4.0)),
    )
  let s =
    rich_text.span("Highlighted")
    |> rich_text.span_highlight(h)

  let pv = rich_text.span_to_prop_value(s)
  let assert DictVal(fields) = pv
  let assert Ok(DictVal(hl)) = dict.get(fields, "highlight")
  assert dict.get(hl, "background") == Ok(color.to_prop_value(color.yellow))
  let assert Ok(DictVal(border)) = dict.get(hl, "border")
  assert dict.get(border, "width") == Ok(FloatVal(1.0))
  assert dict.get(border, "radius") == Ok(FloatVal(4.0))
}

pub fn span_highlight_per_corner_radius_test() {
  let h =
    rich_text.SpanHighlight(
      background: option.None,
      border_color: option.None,
      border_width: option.None,
      border_radius: option.Some(rich_text.PerCornerRadius(1.0, 2.0, 3.0, 4.0)),
    )
  let s =
    rich_text.span("Corners")
    |> rich_text.span_highlight(h)

  let pv = rich_text.span_to_prop_value(s)
  let assert DictVal(fields) = pv
  let assert Ok(DictVal(hl)) = dict.get(fields, "highlight")
  let assert Ok(DictVal(border)) = dict.get(hl, "border")
  assert dict.get(border, "radius")
    == Ok(ListVal([FloatVal(1.0), FloatVal(2.0), FloatVal(3.0), FloatVal(4.0)]))
}

pub fn widget_level_props_test() {
  let node =
    rich_text.new("rt3")
    |> rich_text.width(length.Fill)
    |> rich_text.height(length.Fixed(200.0))
    |> rich_text.size(16.0)
    |> rich_text.font(font.Monospace)
    |> rich_text.color(color.blue)
    |> rich_text.line_height(1.5)
    |> rich_text.wrapping(wrapping.Word)
    |> rich_text.ellipsis("end")
    |> rich_text.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(200.0)))
  assert dict.get(node.props, "size") == Ok(FloatVal(16.0))
  assert dict.get(node.props, "font") == Ok(font.to_prop_value(font.Monospace))
  assert dict.get(node.props, "color") == Ok(color.to_prop_value(color.blue))
  assert dict.get(node.props, "line_height") == Ok(FloatVal(1.5))
  assert dict.get(node.props, "wrapping")
    == Ok(wrapping.to_prop_value(wrapping.Word))
  assert dict.get(node.props, "ellipsis") == Ok(StringVal("end"))
}

pub fn omitted_optionals_are_absent_test() {
  let node = rich_text.new("rt4") |> rich_text.build()

  assert dict.get(node.props, "spans") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "size") == Error(Nil)
  assert dict.get(node.props, "font") == Error(Nil)
  assert dict.get(node.props, "color") == Error(Nil)
  assert dict.get(node.props, "line_height") == Error(Nil)
}

pub fn no_children_on_wire_test() {
  let node =
    rich_text.new("rt5")
    |> rich_text.spans([rich_text.span("test")])
    |> rich_text.build()

  assert node.children == []
}
