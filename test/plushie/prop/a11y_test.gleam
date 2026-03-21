import gleam/dict
import gleeunit/should
import plushie/node.{BoolVal, DictVal, IntVal, StringVal}
import plushie/prop/a11y

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

// -- Tests for the 18 new typed setters --

pub fn expanded_sets_bool_test() {
  let a = a11y.new() |> a11y.expanded(True)
  should.equal(dict.get(a.props, "expanded"), Ok(BoolVal(True)))
}

pub fn required_sets_bool_test() {
  let a = a11y.new() |> a11y.required(True)
  should.equal(dict.get(a.props, "required"), Ok(BoolVal(True)))
}

pub fn busy_sets_bool_test() {
  let a = a11y.new() |> a11y.busy(True)
  should.equal(dict.get(a.props, "busy"), Ok(BoolVal(True)))
}

pub fn invalid_sets_bool_test() {
  let a = a11y.new() |> a11y.invalid(True)
  should.equal(dict.get(a.props, "invalid"), Ok(BoolVal(True)))
}

pub fn modal_sets_bool_test() {
  let a = a11y.new() |> a11y.modal(True)
  should.equal(dict.get(a.props, "modal"), Ok(BoolVal(True)))
}

pub fn read_only_sets_bool_test() {
  let a = a11y.new() |> a11y.read_only(True)
  should.equal(dict.get(a.props, "read_only"), Ok(BoolVal(True)))
}

pub fn mnemonic_sets_string_test() {
  let a = a11y.new() |> a11y.mnemonic("F")
  should.equal(dict.get(a.props, "mnemonic"), Ok(StringVal("F")))
}

pub fn toggled_sets_bool_test() {
  let a = a11y.new() |> a11y.toggled(True)
  should.equal(dict.get(a.props, "toggled"), Ok(BoolVal(True)))
}

pub fn selected_sets_bool_test() {
  let a = a11y.new() |> a11y.selected(True)
  should.equal(dict.get(a.props, "selected"), Ok(BoolVal(True)))
}

pub fn value_sets_string_test() {
  let a = a11y.new() |> a11y.value("42")
  should.equal(dict.get(a.props, "value"), Ok(StringVal("42")))
}

pub fn orientation_horizontal_test() {
  let a = a11y.new() |> a11y.orientation(a11y.Horizontal)
  should.equal(dict.get(a.props, "orientation"), Ok(StringVal("horizontal")))
}

pub fn orientation_vertical_test() {
  let a = a11y.new() |> a11y.orientation(a11y.Vertical)
  should.equal(dict.get(a.props, "orientation"), Ok(StringVal("vertical")))
}

pub fn labelled_by_sets_string_test() {
  let a = a11y.new() |> a11y.labelled_by("label-widget")
  should.equal(dict.get(a.props, "labelled_by"), Ok(StringVal("label-widget")))
}

pub fn described_by_sets_string_test() {
  let a = a11y.new() |> a11y.described_by("desc-widget")
  should.equal(dict.get(a.props, "described_by"), Ok(StringVal("desc-widget")))
}

pub fn error_message_sets_string_test() {
  let a = a11y.new() |> a11y.error_message("err-widget")
  should.equal(dict.get(a.props, "error_message"), Ok(StringVal("err-widget")))
}

pub fn disabled_sets_bool_test() {
  let a = a11y.new() |> a11y.disabled(True)
  should.equal(dict.get(a.props, "disabled"), Ok(BoolVal(True)))
}

pub fn position_in_set_sets_int_test() {
  let a = a11y.new() |> a11y.position_in_set(3)
  should.equal(dict.get(a.props, "position_in_set"), Ok(IntVal(3)))
}

pub fn size_of_set_sets_int_test() {
  let a = a11y.new() |> a11y.size_of_set(10)
  should.equal(dict.get(a.props, "size_of_set"), Ok(IntVal(10)))
}

pub fn has_popup_listbox_test() {
  let a = a11y.new() |> a11y.has_popup(a11y.ListboxPopup)
  should.equal(dict.get(a.props, "has_popup"), Ok(StringVal("listbox")))
}

pub fn has_popup_menu_test() {
  let a = a11y.new() |> a11y.has_popup(a11y.MenuPopup)
  should.equal(dict.get(a.props, "has_popup"), Ok(StringVal("menu")))
}

pub fn has_popup_dialog_test() {
  let a = a11y.new() |> a11y.has_popup(a11y.DialogPopup)
  should.equal(dict.get(a.props, "has_popup"), Ok(StringVal("dialog")))
}

pub fn has_popup_tree_test() {
  let a = a11y.new() |> a11y.has_popup(a11y.TreePopup)
  should.equal(dict.get(a.props, "has_popup"), Ok(StringVal("tree")))
}

pub fn has_popup_grid_test() {
  let a = a11y.new() |> a11y.has_popup(a11y.GridPopup)
  should.equal(dict.get(a.props, "has_popup"), Ok(StringVal("grid")))
}

pub fn chained_setters_test() {
  let a =
    a11y.new()
    |> a11y.role(a11y.Dialog)
    |> a11y.label("Confirm delete")
    |> a11y.modal(True)
    |> a11y.expanded(False)
    |> a11y.described_by("confirm-desc")
  should.equal(dict.get(a.props, "role"), Ok(StringVal("dialog")))
  should.equal(dict.get(a.props, "label"), Ok(StringVal("Confirm delete")))
  should.equal(dict.get(a.props, "modal"), Ok(BoolVal(True)))
  should.equal(dict.get(a.props, "expanded"), Ok(BoolVal(False)))
  should.equal(dict.get(a.props, "described_by"), Ok(StringVal("confirm-desc")))
}
