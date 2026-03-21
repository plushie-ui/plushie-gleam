import gleam/dict
import gleeunit/should
import toddy/node.{DictVal, StringVal}
import toddy/prop/gradient
import toddy/prop/style_map

pub fn new_is_empty_test() {
  let sm = style_map.new()
  should.equal(sm.props, dict.new())
}

pub fn background_sets_prop_test() {
  let sm = style_map.new() |> style_map.background("#ff0000")
  should.equal(dict.get(sm.props, "background"), Ok(StringVal("#ff0000")))
}

pub fn gradient_background_sets_prop_test() {
  let g =
    gradient.linear(90.0, [
      gradient.stop(0.0, "#ff0000"),
      gradient.stop(1.0, "#0000ff"),
    ])
  let sm = style_map.new() |> style_map.gradient_background(g)
  should.equal(dict.get(sm.props, "background"), Ok(gradient.to_prop_value(g)))
}

pub fn text_color_sets_prop_test() {
  let sm = style_map.new() |> style_map.text_color("#00ff00")
  should.equal(dict.get(sm.props, "text_color"), Ok(StringVal("#00ff00")))
}

pub fn to_prop_value_is_dict_val_test() {
  let result =
    style_map.new()
    |> style_map.background("#aaa")
    |> style_map.to_prop_value()
  let expected = DictVal(dict.from_list([#("background", StringVal("#aaa"))]))
  should.equal(result, expected)
}

pub fn nested_hovered_test() {
  let hover_style = style_map.new() |> style_map.background("#ccc")
  let result =
    style_map.new()
    |> style_map.background("#fff")
    |> style_map.hovered(hover_style)
    |> style_map.to_prop_value()
  let expected =
    DictVal(
      dict.from_list([
        #("background", StringVal("#fff")),
        #(
          "hovered",
          DictVal(dict.from_list([#("background", StringVal("#ccc"))])),
        ),
      ]),
    )
  should.equal(result, expected)
}
