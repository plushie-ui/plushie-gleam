//// Accessibility properties for widgets.
////
//// Builder pattern: start with `new()` and pipe through `role`, `label`,
//// `description`, `hidden`, `level`, etc. Wire format is a flat dictionary
//// of string-keyed PropValues.

import gleam/dict.{type Dict}
import plushie/node.{type PropValue, BoolVal, DictVal, IntVal, StringVal}

pub type A11y {
  A11y(props: Dict(String, PropValue))
}

/// Roles recognized by the Rust renderer's parse_role function.
/// WAI-ARIA roles NOT supported by the renderer (no iced accessible::Role
/// mapping): application, article, banner, complementary, content_info,
/// definition, directory, feed, figure, form, grid, grid_cell, list_box,
/// log, main, marquee, math, menu_item_checkbox, menu_item_radio, note,
/// option, presentation, radio_group, row_group, row_header, search_box,
/// spin_button, term, timer, tree_grid.
pub type Role {
  Alert
  AlertDialog
  Button
  Canvas
  CheckBox
  ColumnHeader
  ComboBox
  Dialog
  Document
  Group
  Heading
  Image
  Label
  Link
  List
  ListItem
  Menu
  MenuBar
  MenuItem
  Meter
  MultilineTextInput
  Navigation
  ProgressIndicator
  RadioButton
  Region
  Row
  Cell
  ScrollBar
  ScrollView
  Search
  Separator
  Slider
  StaticText
  Status
  Switch
  Tab
  TabList
  TabPanel
  Table
  TextInput
  Toolbar
  Tooltip
  Tree
  TreeItem
  Window
}

/// Create an empty accessibility property set.
pub fn new() -> A11y {
  A11y(props: dict.new())
}

/// Set the ARIA role.
pub fn role(a: A11y, r: Role) -> A11y {
  A11y(props: dict.insert(a.props, "role", StringVal(role_to_string(r))))
}

/// Set the accessible label.
pub fn label(a: A11y, s: String) -> A11y {
  A11y(props: dict.insert(a.props, "label", StringVal(s)))
}

/// Set the accessible description.
pub fn description(a: A11y, s: String) -> A11y {
  A11y(props: dict.insert(a.props, "description", StringVal(s)))
}

/// Set whether the element is hidden from assistive technology.
pub fn hidden(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "hidden", BoolVal(b)))
}

/// Set the heading level (1-6).
pub fn level(a: A11y, n: Int) -> A11y {
  A11y(props: dict.insert(a.props, "level", IntVal(n)))
}

/// Set the live region politeness.
pub fn live(a: A11y, s: String) -> A11y {
  A11y(props: dict.insert(a.props, "live", StringVal(s)))
}

/// Set expanded/collapsed state for disclosure widgets.
pub fn expanded(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "expanded", BoolVal(b)))
}

/// Mark a form field as required.
pub fn required(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "required", BoolVal(b)))
}

/// Set loading/processing state.
pub fn busy(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "busy", BoolVal(b)))
}

/// Set form validation failure state.
pub fn invalid(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "invalid", BoolVal(b)))
}

/// Set whether a dialog is modal.
pub fn modal(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "modal", BoolVal(b)))
}

/// Set read-only state (can be read but not edited).
pub fn read_only(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "read_only", BoolVal(b)))
}

/// Set an Alt+letter keyboard shortcut (single character).
pub fn mnemonic(a: A11y, s: String) -> A11y {
  A11y(props: dict.insert(a.props, "mnemonic", StringVal(s)))
}

/// Set toggled/checked state for custom toggle widgets.
pub fn toggled(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "toggled", BoolVal(b)))
}

/// Set selected state for custom selectable widgets.
pub fn selected(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "selected", BoolVal(b)))
}

/// Set the current value as a string (for custom value-displaying widgets).
pub fn value(a: A11y, s: String) -> A11y {
  A11y(props: dict.insert(a.props, "value", StringVal(s)))
}

/// Orientation type for accessible widgets.
pub type Orientation {
  Horizontal
  Vertical
}

/// Set the orientation of the widget.
pub fn orientation(a: A11y, o: Orientation) -> A11y {
  let val = case o {
    Horizontal -> "horizontal"
    Vertical -> "vertical"
  }
  A11y(props: dict.insert(a.props, "orientation", StringVal(val)))
}

/// Set the ID of the widget that labels this one.
/// Resolved during tree normalization (scoped ID lookup).
pub fn labelled_by(a: A11y, id: String) -> A11y {
  A11y(props: dict.insert(a.props, "labelled_by", StringVal(id)))
}

/// Set the ID of the widget that describes this one.
/// Resolved during tree normalization (scoped ID lookup).
pub fn described_by(a: A11y, id: String) -> A11y {
  A11y(props: dict.insert(a.props, "described_by", StringVal(id)))
}

/// Set the ID of the widget showing the error message for this one.
/// Resolved during tree normalization (scoped ID lookup).
pub fn error_message(a: A11y, id: String) -> A11y {
  A11y(props: dict.insert(a.props, "error_message", StringVal(id)))
}

/// Override disabled state for assistive technology.
pub fn disabled(a: A11y, b: Bool) -> A11y {
  A11y(props: dict.insert(a.props, "disabled", BoolVal(b)))
}

/// Set 1-based position within a set (lists, radio groups, tabs).
pub fn position_in_set(a: A11y, n: Int) -> A11y {
  A11y(props: dict.insert(a.props, "position_in_set", IntVal(n)))
}

/// Set the total number of items in the set.
pub fn size_of_set(a: A11y, n: Int) -> A11y {
  A11y(props: dict.insert(a.props, "size_of_set", IntVal(n)))
}

/// Popup type for has_popup attribute.
pub type HasPopup {
  ListboxPopup
  MenuPopup
  DialogPopup
  TreePopup
  GridPopup
}

/// Set the popup type for this widget.
pub fn has_popup(a: A11y, p: HasPopup) -> A11y {
  let val = case p {
    ListboxPopup -> "listbox"
    MenuPopup -> "menu"
    DialogPopup -> "dialog"
    TreePopup -> "tree"
    GridPopup -> "grid"
  }
  A11y(props: dict.insert(a.props, "has_popup", StringVal(val)))
}

/// Set an arbitrary accessibility property.
pub fn set(a: A11y, key: String, val: PropValue) -> A11y {
  A11y(props: dict.insert(a.props, key, val))
}

/// Encode an A11y to its wire-format PropValue.
pub fn to_prop_value(a: A11y) -> PropValue {
  DictVal(a.props)
}

pub fn role_to_string(r: Role) -> String {
  case r {
    Alert -> "alert"
    AlertDialog -> "alert_dialog"
    Button -> "button"
    Canvas -> "canvas"
    CheckBox -> "check_box"
    Cell -> "cell"
    ColumnHeader -> "column_header"
    ComboBox -> "combo_box"
    Dialog -> "dialog"
    Document -> "document"
    Group -> "group"
    Heading -> "heading"
    Image -> "image"
    Label -> "label"
    Link -> "link"
    List -> "list"
    ListItem -> "list_item"
    Menu -> "menu"
    MenuBar -> "menu_bar"
    MenuItem -> "menu_item"
    Meter -> "meter"
    MultilineTextInput -> "multiline_text_input"
    Navigation -> "navigation"
    ProgressIndicator -> "progress_indicator"
    RadioButton -> "radio_button"
    Region -> "region"
    Row -> "row"
    ScrollBar -> "scroll_bar"
    ScrollView -> "scroll_view"
    Search -> "search"
    Separator -> "separator"
    Slider -> "slider"
    StaticText -> "static_text"
    Status -> "status"
    Switch -> "switch"
    Tab -> "tab"
    TabList -> "tab_list"
    TabPanel -> "tab_panel"
    Table -> "table"
    TextInput -> "text_input"
    Toolbar -> "toolbar"
    Tooltip -> "tooltip"
    Tree -> "tree"
    TreeItem -> "tree_item"
    Window -> "window"
  }
}
