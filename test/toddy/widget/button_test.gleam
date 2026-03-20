import gleam/dict
import toddy/node.{BoolVal, StringVal}
import toddy/prop/length
import toddy/prop/padding
import toddy/widget/button

pub fn new_builds_minimal_button_test() {
  let node = button.new("ok", "OK") |> button.build()

  assert node.id == "ok"
  assert node.kind == "button"
  assert node.children == []
  assert dict.get(node.props, "label") == Ok(StringVal("OK"))
  assert dict.size(node.props) == 1
}

pub fn style_sets_style_prop_test() {
  let node =
    button.new("btn", "Go")
    |> button.style(button.Primary)
    |> button.build()

  assert dict.get(node.props, "style") == Ok(StringVal("primary"))
}

pub fn all_styles_encode_correctly_test() {
  let cases = [
    #(button.Primary, "primary"),
    #(button.Secondary, "secondary"),
    #(button.Success, "success"),
    #(button.Warning, "warning"),
    #(button.Danger, "danger"),
    #(button.TextStyle, "text"),
    #(button.BackgroundStyle, "background"),
    #(button.Subtle, "subtle"),
  ]
  check_styles(cases)
}

fn check_styles(cases: List(#(button.ButtonStyle, String))) {
  case cases {
    [] -> Nil
    [#(s, expected), ..rest] -> {
      let node =
        button.new("x", "X")
        |> button.style(s)
        |> button.build()
      assert dict.get(node.props, "style") == Ok(StringVal(expected))
      check_styles(rest)
    }
  }
}

pub fn width_sets_length_prop_test() {
  let node =
    button.new("btn", "Go")
    |> button.width(length.Fill)
    |> button.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn disabled_sets_bool_prop_test() {
  let node =
    button.new("btn", "Go")
    |> button.disabled(True)
    |> button.build()

  assert dict.get(node.props, "disabled") == Ok(BoolVal(True))
}

pub fn padding_sets_padding_prop_test() {
  let p = padding.all(8.0)
  let node =
    button.new("btn", "Go")
    |> button.padding(p)
    |> button.build()

  assert dict.get(node.props, "padding") == Ok(padding.to_prop_value(p))
}

pub fn clip_sets_bool_prop_test() {
  let node =
    button.new("btn", "Go")
    |> button.clip(True)
    |> button.build()

  assert dict.get(node.props, "clip") == Ok(BoolVal(True))
}

pub fn omitted_optionals_are_absent_test() {
  let node = button.new("btn", "Go") |> button.build()

  assert dict.get(node.props, "style") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "disabled") == Error(Nil)
}
