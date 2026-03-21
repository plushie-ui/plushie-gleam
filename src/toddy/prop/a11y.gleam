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

pub type Role {
  Alert
  AlertDialog
  Application
  Article
  Banner
  Button
  Cell
  Checkbox
  ColumnHeader
  Combobox
  Complementary
  ContentInfo
  Definition
  Dialog
  Directory
  Document
  Feed
  Figure
  Form
  Grid
  GridCell
  Group
  Heading
  Img
  Link
  List
  ListBox
  ListItem
  Log
  Main
  Marquee
  Math
  Menu
  MenuBar
  MenuItem
  MenuItemCheckbox
  MenuItemRadio
  Navigation
  Note
  Option
  Presentation
  ProgressBar
  Radio
  RadioGroup
  Region
  Row
  RowGroup
  RowHeader
  ScrollBar
  Search
  SearchBox
  Separator
  Slider
  SpinButton
  Status
  Switch
  Tab
  TabList
  TabPanel
  Table
  Term
  TextBox
  Timer
  Toolbar
  Tooltip
  Tree
  TreeGrid
  TreeItem
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
    AlertDialog -> "alertdialog"
    Application -> "application"
    Article -> "article"
    Banner -> "banner"
    Button -> "button"
    Cell -> "cell"
    Checkbox -> "checkbox"
    ColumnHeader -> "columnheader"
    Combobox -> "combobox"
    Complementary -> "complementary"
    ContentInfo -> "contentinfo"
    Definition -> "definition"
    Dialog -> "dialog"
    Directory -> "directory"
    Document -> "document"
    Feed -> "feed"
    Figure -> "figure"
    Form -> "form"
    Grid -> "grid"
    GridCell -> "gridcell"
    Group -> "group"
    Heading -> "heading"
    Img -> "img"
    Link -> "link"
    List -> "list"
    ListBox -> "listbox"
    ListItem -> "list_item"
    Log -> "log"
    Main -> "main"
    Marquee -> "marquee"
    Math -> "math"
    Menu -> "menu"
    MenuBar -> "menu_bar"
    MenuItem -> "menu_item"
    MenuItemCheckbox -> "menuitemcheckbox"
    MenuItemRadio -> "menuitemradio"
    Navigation -> "navigation"
    Note -> "note"
    Option -> "option"
    Presentation -> "presentation"
    ProgressBar -> "progressbar"
    Radio -> "radio"
    RadioGroup -> "radiogroup"
    Region -> "region"
    Row -> "row"
    RowGroup -> "rowgroup"
    RowHeader -> "rowheader"
    ScrollBar -> "scrollbar"
    Search -> "search"
    SearchBox -> "searchbox"
    Separator -> "separator"
    Slider -> "slider"
    SpinButton -> "spinbutton"
    Status -> "status"
    Switch -> "switch"
    Tab -> "tab"
    TabList -> "tab_list"
    TabPanel -> "tab_panel"
    Table -> "table"
    Term -> "term"
    TextBox -> "textbox"
    Timer -> "timer"
    Toolbar -> "toolbar"
    Tooltip -> "tooltip"
    Tree -> "tree"
    TreeGrid -> "treegrid"
    TreeItem -> "tree_item"
  }
}
