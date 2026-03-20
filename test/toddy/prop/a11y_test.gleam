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

pub fn role_to_string_samples_test() {
  should.equal(a11y.role_to_string(a11y.AlertDialog), "alertdialog")
  should.equal(a11y.role_to_string(a11y.Checkbox), "checkbox")
  should.equal(a11y.role_to_string(a11y.MenuItemRadio), "menuitemradio")
  should.equal(a11y.role_to_string(a11y.ProgressBar), "progressbar")
  should.equal(a11y.role_to_string(a11y.TreeItem), "treeitem")
}
