//// Accessibility properties for widgets.
////
//// Builder pattern: start with `new()` and pipe through `role`, `label`,
//// `description`, `hidden`, `level`, etc. Wire format is a flat dictionary
//// of string-keyed PropValues.

import gleam/dict.{type Dict}
import toddy/node.{type PropValue, BoolVal, DictVal, IntVal, StringVal}

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
