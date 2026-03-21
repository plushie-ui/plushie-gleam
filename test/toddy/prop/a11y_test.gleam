import gleam/dict
import gleeunit/should
import toddy/node.{BoolVal, DictVal, IntVal, StringVal}
import toddy/prop/a11y

pub fn new_is_empty_test() {
  let a = a11y.new()
  should.equal(a.props, dict.new())
}

pub fn role_sets_string_test() {
  let a = a11y.new() |> a11y.role(a11y.Button)
  should.equal(dict.get(a.props, "role"), Ok(StringVal("button")))
}

pub fn label_sets_string_test() {
  let a = a11y.new() |> a11y.label("Submit form")
  should.equal(dict.get(a.props, "label"), Ok(StringVal("Submit form")))
}

pub fn description_sets_string_test() {
  let a = a11y.new() |> a11y.description("Sends the form data")
  should.equal(
    dict.get(a.props, "description"),
    Ok(StringVal("Sends the form data")),
  )
}

pub fn hidden_sets_bool_test() {
  let a = a11y.new() |> a11y.hidden(True)
  should.equal(dict.get(a.props, "hidden"), Ok(BoolVal(True)))
}

pub fn level_sets_int_test() {
  let a = a11y.new() |> a11y.level(2)
  should.equal(dict.get(a.props, "level"), Ok(IntVal(2)))
}

pub fn to_prop_value_is_dict_val_test() {
  let result =
    a11y.new()
    |> a11y.role(a11y.Alert)
    |> a11y.label("Warning")
    |> a11y.to_prop_value()
  let expected =
    DictVal(
      dict.from_list([
        #("role", StringVal("alert")),
        #("label", StringVal("Warning")),
      ]),
    )
  should.equal(result, expected)
}

pub fn role_to_string_matches_rust_parser_test() {
  should.equal(a11y.role_to_string(a11y.AlertDialog), "alert_dialog")
  should.equal(a11y.role_to_string(a11y.CheckBox), "check_box")
  should.equal(a11y.role_to_string(a11y.ComboBox), "combo_box")
  should.equal(a11y.role_to_string(a11y.ColumnHeader), "column_header")
  should.equal(a11y.role_to_string(a11y.Image), "image")
  should.equal(
    a11y.role_to_string(a11y.ProgressIndicator),
    "progress_indicator",
  )
  should.equal(a11y.role_to_string(a11y.RadioButton), "radio_button")
  should.equal(a11y.role_to_string(a11y.ScrollBar), "scroll_bar")
  should.equal(a11y.role_to_string(a11y.TextInput), "text_input")
  should.equal(a11y.role_to_string(a11y.TreeItem), "tree_item")
  should.equal(a11y.role_to_string(a11y.Canvas), "canvas")
  should.equal(a11y.role_to_string(a11y.Label), "label")
  should.equal(a11y.role_to_string(a11y.Meter), "meter")
  should.equal(a11y.role_to_string(a11y.StaticText), "static_text")
  should.equal(a11y.role_to_string(a11y.Window), "window")
}
