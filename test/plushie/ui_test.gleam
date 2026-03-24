import gleam/dict
import gleam/option
import plushie/node.{BoolVal, FloatVal, IntVal, StringVal}
import plushie/prop/alignment
import plushie/prop/length
import plushie/prop/padding
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/text
import plushie/widget/text_input
import plushie/widget/window

pub fn window_creates_window_node_test() {
  let node = ui.window("main", [window.Title("App")], [])

  assert node.id == "main"
  assert node.kind == "window"
  assert dict.get(node.props, "title") == Ok(StringVal("App"))
  assert node.children == []
}

pub fn column_creates_column_node_test() {
  let node = ui.column("col", [column.Spacing(8)], [])

  assert node.id == "col"
  assert node.kind == "column"
  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
}

pub fn row_creates_row_node_test() {
  let node = ui.row("r", [row.Spacing(4)], [])

  assert node.id == "r"
  assert node.kind == "row"
  assert dict.get(node.props, "spacing") == Ok(IntVal(4))
}

pub fn text_underscore_creates_text_node_test() {
  let node = ui.text_("lbl", "Hello")

  assert node.id == "lbl"
  assert node.kind == "text"
  assert dict.get(node.props, "content") == Ok(StringVal("Hello"))
  assert dict.size(node.props) == 1
}

pub fn text_with_attrs_test() {
  let node = ui.text("lbl", "Hello", [text.Size(24.0)])

  assert dict.get(node.props, "content") == Ok(StringVal("Hello"))
  assert dict.get(node.props, "size") == Ok(FloatVal(24.0))
}

pub fn button_underscore_creates_button_node_test() {
  let node = ui.button_("ok", "OK")

  assert node.id == "ok"
  assert node.kind == "button"
  assert dict.get(node.props, "label") == Ok(StringVal("OK"))
  assert dict.size(node.props) == 1
}

pub fn button_with_attrs_test() {
  let node =
    ui.button("ok", "OK", [button.Disabled(True), button.Style(button.Primary)])

  assert dict.get(node.props, "label") == Ok(StringVal("OK"))
  assert dict.get(node.props, "disabled") == Ok(BoolVal(True))
  assert dict.get(node.props, "style") == Ok(StringVal("primary"))
}

pub fn text_input_creates_text_input_node_test() {
  let node =
    ui.text_input("email", "user@example.com", [
      text_input.Placeholder("Email"),
    ])

  assert node.id == "email"
  assert node.kind == "text_input"
  assert dict.get(node.props, "value") == Ok(StringVal("user@example.com"))
  assert dict.get(node.props, "placeholder") == Ok(StringVal("Email"))
}

pub fn checkbox_creates_checkbox_node_test() {
  let node = ui.checkbox("agree", "I agree", True, [])

  assert node.id == "agree"
  assert node.kind == "checkbox"
  assert dict.get(node.props, "label") == Ok(StringVal("I agree"))
  assert dict.get(node.props, "checked") == Ok(BoolVal(True))
}

pub fn slider_creates_slider_node_test() {
  let node = ui.slider("vol", #(0.0, 100.0), 50.0, [])

  assert node.id == "vol"
  assert node.kind == "slider"
  assert dict.get(node.props, "value") == Ok(FloatVal(50.0))
}

pub fn width_and_height_attrs_test() {
  let node =
    ui.column(
      "col",
      [
        column.Width(length.Fill),
        column.Height(length.Fixed(200.0)),
      ],
      [],
    )

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(200.0)))
}

pub fn padding_attr_test() {
  let p = padding.all(16.0)
  let node = ui.column("col", [column.Padding(p)], [])

  assert dict.get(node.props, "padding") == Ok(padding.to_prop_value(p))
}

pub fn align_attrs_test() {
  let node =
    ui.column(
      "col",
      [
        column.AlignX(alignment.Center),
      ],
      [],
    )

  assert dict.get(node.props, "align_x")
    == Ok(alignment.to_prop_value(alignment.Center))
}

pub fn nested_tree_test() {
  let tree =
    ui.window("main", [window.Title("Counter")], [
      ui.column("body", [column.Spacing(8)], [
        ui.text_("count", "0"),
        ui.row("buttons", [row.Spacing(4)], [
          ui.button_("inc", "+"),
          ui.button_("dec", "-"),
        ]),
      ]),
    ])

  assert tree.id == "main"
  assert tree.kind == "window"

  // Verify children nested correctly
  case tree.children {
    [col] -> {
      assert col.id == "body"
      assert col.kind == "column"
      case col.children {
        [txt, r] -> {
          assert txt.id == "count"
          assert r.id == "buttons"
          assert r.kind == "row"
        }
        _ -> panic as "expected two children in column"
      }
    }
    _ -> panic as "expected one child in window"
  }
}

pub fn find_delegates_to_tree_test() {
  let tree =
    ui.window("main", [], [
      ui.text_("lbl", "Hi"),
    ])

  assert option.is_some(ui.find(tree, "lbl"))
  assert ui.find(tree, "nope") == option.None
}

pub fn exists_delegates_to_tree_test() {
  let tree =
    ui.window("main", [], [
      ui.button_("btn", "Go"),
    ])

  assert ui.exists(tree, "btn") == True
  assert ui.exists(tree, "nope") == False
}

pub fn container_creates_container_node_test() {
  let node = ui.container("c", [container.Clip(True)], [])

  assert node.id == "c"
  assert node.kind == "container"
  assert dict.get(node.props, "clip") == Ok(BoolVal(True))
}

pub fn space_creates_space_node_test() {
  let node = ui.space("s", [])

  assert node.id == "s"
  assert node.kind == "space"
}

pub fn rule_creates_rule_node_test() {
  let node = ui.rule("r", [])

  assert node.id == "r"
  assert node.kind == "rule"
}
