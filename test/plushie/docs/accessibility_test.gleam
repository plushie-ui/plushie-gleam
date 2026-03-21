import gleam/dict
import gleam/list
import gleeunit/should
import plushie/node.{BoolVal, DictVal, IntVal, StringVal}
import plushie/prop/a11y
import plushie/prop/length.{Fill, Fixed}
import plushie/ui
import plushie/widget/button
import plushie/widget/canvas
import plushie/widget/text as text_widget
import plushie/widget/text_input as text_input_widget

// -- Headings with a11y prop (from "Using the a11y prop" section) -------------

pub fn a11y_heading_level_1_ui_builder_test() {
  let node =
    ui.text("title", "Welcome to MyApp", [
      ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1)),
    ])
  should.equal(node.kind, "text")
  should.equal(
    dict.get(node.props, "content"),
    Ok(StringVal("Welcome to MyApp")),
  )
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("heading")))
  should.equal(dict.get(a11y_dict, "level"), Ok(IntVal(1)))
}

pub fn a11y_heading_level_2_ui_builder_test() {
  let node =
    ui.text("settings_heading", "Settings", [
      ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2)),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("heading")))
  should.equal(dict.get(a11y_dict, "level"), Ok(IntVal(2)))
}

// -- Icon button with a11y label ----------------------------------------------

pub fn a11y_icon_button_label_test() {
  let node =
    ui.button("close", "X", [
      ui.a11y(a11y.new() |> a11y.label("Close dialog")),
    ])
  should.equal(node.kind, "button")
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Close dialog")))
}

// -- Landmark region ----------------------------------------------------------

pub fn a11y_landmark_region_test() {
  let node =
    ui.container(
      "search_results",
      [
        ui.a11y(
          a11y.new()
          |> a11y.role(a11y.Region)
          |> a11y.label("Search results"),
        ),
      ],
      [],
    )
  should.equal(node.kind, "container")
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("region")))
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Search results")))
}

// -- Live region --------------------------------------------------------------

pub fn a11y_live_polite_test() {
  let node =
    ui.text("save_status", "5 items saved", [
      ui.a11y(a11y.new() |> a11y.live("polite")),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "live"), Ok(StringVal("polite")))
}

// -- Hidden decorative elements -----------------------------------------------

pub fn a11y_hidden_rule_test() {
  let node = ui.rule("divider", [ui.a11y(a11y.new() |> a11y.hidden(True))])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "hidden"), Ok(BoolVal(True)))
}

// -- Expanded state -----------------------------------------------------------

pub fn a11y_expanded_container_test() {
  let node =
    ui.container(
      "details",
      [
        ui.a11y(
          a11y.new()
          |> a11y.expanded(True)
          |> a11y.role(a11y.Group)
          |> a11y.label("Advanced options"),
        ),
      ],
      [],
    )
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "expanded"), Ok(BoolVal(True)))
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("group")))
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Advanced options")))
}

// -- Required form field ------------------------------------------------------

pub fn a11y_required_text_input_test() {
  let node =
    ui.text_input("email", "", [
      ui.a11y(a11y.new() |> a11y.required(True) |> a11y.label("Email address")),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "required"), Ok(BoolVal(True)))
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Email address")))
}

// -- Typed widget builder API (plushie/widget/*) --------------------------------

pub fn a11y_button_widget_builder_test() {
  let node =
    button.new("close", "X")
    |> button.a11y(a11y.new() |> a11y.label("Close dialog"))
    |> button.build()
  should.equal(node.kind, "button")
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Close dialog")))
}

pub fn a11y_text_widget_builder_test() {
  let node =
    text_widget.new("title", "Welcome")
    |> text_widget.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1))
    |> text_widget.build()
  should.equal(node.kind, "text")
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("heading")))
  should.equal(dict.get(a11y_dict, "level"), Ok(IntVal(1)))
}

pub fn a11y_text_input_widget_builder_test() {
  let node =
    text_input_widget.new("email", "")
    |> text_input_widget.a11y(
      a11y.new() |> a11y.required(True) |> a11y.label("Email address"),
    )
    |> text_input_widget.build()
  should.equal(node.kind, "text_input")
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "required"), Ok(BoolVal(True)))
}

// -- Headings for page structure (from "Use headings to create structure") -----

pub fn a11y_heading_structure_test() {
  let tree =
    ui.window("main", [ui.title("MyApp")], [
      ui.column("content", [], [
        ui.text("page_title", "Dashboard", [
          ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1)),
        ]),
        ui.text("h_recent", "Recent activity", [
          ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2)),
        ]),
        ui.text("h_actions", "Quick actions", [
          ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2)),
        ]),
      ]),
    ])
  let assert [column] = tree.children
  let assert [h1, h2a, h2b] = column.children

  let assert Ok(DictVal(h1_a11y)) = dict.get(h1.props, "a11y")
  should.equal(dict.get(h1_a11y, "level"), Ok(IntVal(1)))

  let assert Ok(DictVal(h2a_a11y)) = dict.get(h2a.props, "a11y")
  should.equal(dict.get(h2a_a11y, "level"), Ok(IntVal(2)))

  let assert Ok(DictVal(h2b_a11y)) = dict.get(h2b.props, "a11y")
  should.equal(dict.get(h2b_a11y, "level"), Ok(IntVal(2)))
}

// -- Landmarks for page regions (from "Use landmarks") ------------------------

pub fn a11y_navigation_landmark_test() {
  let node =
    ui.container(
      "nav",
      [
        ui.a11y(
          a11y.new()
          |> a11y.role(a11y.Navigation)
          |> a11y.label("Main navigation"),
        ),
      ],
      [
        ui.row("nav_buttons", [], [
          ui.button_("home", "Home"),
          ui.button_("settings", "Settings"),
          ui.button_("help", "Help"),
        ]),
      ],
    )
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("navigation")))
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Main navigation")))
  should.equal(list.length(node.children), 1)
}

pub fn a11y_search_landmark_test() {
  let node =
    ui.container(
      "search_area",
      [
        ui.a11y(a11y.new() |> a11y.role(a11y.Search) |> a11y.label("Search")),
      ],
      [
        ui.text_input("query", "", [ui.placeholder("Search...")]),
        ui.button_("go", "Search"),
      ],
    )
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("search")))
  should.equal(list.length(node.children), 2)
}

// -- Live regions for dynamic content -----------------------------------------

pub fn a11y_live_assertive_alert_test() {
  let node =
    ui.text("error", "Something went wrong", [
      ui.a11y(a11y.new() |> a11y.live("assertive") |> a11y.role(a11y.Alert)),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "live"), Ok(StringVal("assertive")))
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("alert")))
}

// -- Cross-widget relationships (labelled_by, described_by, error_message) ----

pub fn a11y_labelled_by_test() {
  let node =
    ui.text_input("email", "", [
      ui.a11y(
        a11y.new()
        |> a11y.labelled_by("email-label")
        |> a11y.described_by("email-help")
        |> a11y.error_message("email-error"),
      ),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "labelled_by"), Ok(StringVal("email-label")))
  should.equal(dict.get(a11y_dict, "described_by"), Ok(StringVal("email-help")))
  should.equal(
    dict.get(a11y_dict, "error_message"),
    Ok(StringVal("email-error")),
  )
}

// -- Hiding decorative content ------------------------------------------------

pub fn a11y_decorative_image_hidden_test() {
  let node =
    ui.image("hero", "/images/banner.png", [
      ui.a11y(a11y.new() |> a11y.hidden(True)),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "hidden"), Ok(BoolVal(True)))
}

pub fn a11y_space_hidden_test() {
  let node = ui.space("gap", [ui.a11y(a11y.new() |> a11y.hidden(True))])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "hidden"), Ok(BoolVal(True)))
}

// -- Canvas widget with a11y (from "Canvas widgets" section) ------------------

pub fn a11y_canvas_with_role_and_label_test() {
  let node =
    canvas.new("chart", Fill, Fill)
    |> canvas.a11y(
      a11y.new()
      |> a11y.role(a11y.Image)
      |> a11y.label("Sales chart: Q1 revenue up 15%, Q2 flat"),
    )
    |> canvas.build()
  should.equal(node.kind, "canvas")
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("image")))
  should.equal(
    dict.get(a11y_dict, "label"),
    Ok(StringVal("Sales chart: Q1 revenue up 15%, Q2 flat")),
  )
}

// -- Custom toggle switch (from "Custom widgets with state") ------------------

pub fn a11y_canvas_switch_toggled_test() {
  let node =
    canvas.new("dark-mode-switch", Fixed(60.0), Fixed(30.0))
    |> canvas.a11y(
      a11y.new()
      |> a11y.role(a11y.Switch)
      |> a11y.label("Dark mode")
      |> a11y.toggled(True),
    )
    |> canvas.build()
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("switch")))
  should.equal(dict.get(a11y_dict, "toggled"), Ok(BoolVal(True)))
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("Dark mode")))
}

// -- Custom gauge with value and orientation ----------------------------------

pub fn a11y_canvas_meter_with_value_test() {
  let node =
    canvas.new("cpu-gauge", Fixed(200.0), Fixed(40.0))
    |> canvas.a11y(
      a11y.new()
      |> a11y.role(a11y.Meter)
      |> a11y.label("CPU usage")
      |> a11y.value("75%")
      |> a11y.orientation(a11y.Horizontal),
    )
    |> canvas.build()
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("meter")))
  should.equal(dict.get(a11y_dict, "value"), Ok(StringVal("75%")))
  should.equal(dict.get(a11y_dict, "label"), Ok(StringVal("CPU usage")))
  should.equal(dict.get(a11y_dict, "orientation"), Ok(StringVal("horizontal")))
}

// -- has_popup ----------------------------------------------------------------

pub fn a11y_has_popup_menu_test() {
  let node =
    ui.button("menu_btn", "Options", [
      ui.a11y(
        a11y.new()
        |> a11y.has_popup(a11y.MenuPopup)
        |> a11y.expanded(False),
      ),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "has_popup"), Ok(StringVal("menu")))
  should.equal(dict.get(a11y_dict, "expanded"), Ok(BoolVal(False)))
}

pub fn a11y_has_popup_listbox_test() {
  let node =
    ui.text_input("search", "", [
      ui.a11y(
        a11y.new()
        |> a11y.has_popup(a11y.ListboxPopup)
        |> a11y.expanded(True),
      ),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "has_popup"), Ok(StringVal("listbox")))
  should.equal(dict.get(a11y_dict, "expanded"), Ok(BoolVal(True)))
}

// -- Disabled override --------------------------------------------------------

pub fn a11y_disabled_override_test() {
  let node =
    ui.button("submit", "Submit", [
      ui.a11y(a11y.new() |> a11y.disabled(True)),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "disabled"), Ok(BoolVal(True)))
}

// -- Expanded/collapsed button ------------------------------------------------

pub fn a11y_expanded_button_test() {
  let node =
    ui.button("toggle_details", "Show details", [
      ui.a11y(a11y.new() |> a11y.expanded(False)),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "expanded"), Ok(BoolVal(False)))
}

// -- Widget-specific a11y props: alt, label, description, decorative ----------

pub fn a11y_image_alt_prop_test() {
  let node = ui.image("logo", "/images/logo.png", [ui.alt("Company logo")])
  should.equal(dict.get(node.props, "alt"), Ok(StringVal("Company logo")))
}

pub fn a11y_image_decorative_prop_test() {
  let node =
    ui.image("divider", "/images/decorative-line.png", [ui.decorative(True)])
  should.equal(dict.get(node.props, "decorative"), Ok(BoolVal(True)))
}

pub fn a11y_slider_label_prop_test() {
  let node = ui.slider("volume", #(0.0, 100.0), 50.0, [ui.label("Volume")])
  should.equal(dict.get(node.props, "label"), Ok(StringVal("Volume")))
}

pub fn a11y_progress_bar_label_prop_test() {
  let node =
    ui.progress_bar("upload", #(0.0, 100.0), 50.0, [
      ui.label("Upload progress"),
    ])
  should.equal(dict.get(node.props, "label"), Ok(StringVal("Upload progress")))
}

pub fn a11y_image_description_prop_test() {
  let node =
    ui.image("photo", "/photo.jpg", [
      ui.alt("Team photo"),
      ui.description("The engineering team at the 2025 offsite"),
    ])
  should.equal(dict.get(node.props, "alt"), Ok(StringVal("Team photo")))
  should.equal(
    dict.get(node.props, "description"),
    Ok(StringVal("The engineering team at the 2025 offsite")),
  )
}

// -- position_in_set / size_of_set (from "Set position and popup hints") ------

pub fn a11y_position_in_set_test() {
  let a =
    a11y.new()
    |> a11y.position_in_set(3)
    |> a11y.size_of_set(7)
  should.equal(dict.get(a.props, "position_in_set"), Ok(IntVal(3)))
  should.equal(dict.get(a.props, "size_of_set"), Ok(IntVal(7)))
}

// -- selected state -----------------------------------------------------------

pub fn a11y_selected_state_test() {
  let a = a11y.new() |> a11y.selected(True)
  should.equal(dict.get(a.props, "selected"), Ok(BoolVal(True)))
}

// -- Tab role with selected ---------------------------------------------------

pub fn a11y_tab_role_selected_test() {
  let node =
    ui.button("tab_home", "Home", [
      ui.a11y(
        a11y.new()
        |> a11y.role(a11y.Tab)
        |> a11y.selected(True)
        |> a11y.position_in_set(1)
        |> a11y.size_of_set(3),
      ),
    ])
  let assert Ok(DictVal(a11y_dict)) = dict.get(node.props, "a11y")
  should.equal(dict.get(a11y_dict, "role"), Ok(StringVal("tab")))
  should.equal(dict.get(a11y_dict, "selected"), Ok(BoolVal(True)))
  should.equal(dict.get(a11y_dict, "position_in_set"), Ok(IntVal(1)))
  should.equal(dict.get(a11y_dict, "size_of_set"), Ok(IntVal(3)))
}

// -- Modal and busy state -----------------------------------------------------

pub fn a11y_modal_and_busy_test() {
  let a =
    a11y.new()
    |> a11y.modal(True)
    |> a11y.busy(True)
  should.equal(dict.get(a.props, "modal"), Ok(BoolVal(True)))
  should.equal(dict.get(a.props, "busy"), Ok(BoolVal(True)))
}

// -- read_only and invalid ---------------------------------------------------

pub fn a11y_read_only_and_invalid_test() {
  let a =
    a11y.new()
    |> a11y.read_only(True)
    |> a11y.invalid(True)
  should.equal(dict.get(a.props, "read_only"), Ok(BoolVal(True)))
  should.equal(dict.get(a.props, "invalid"), Ok(BoolVal(True)))
}

// -- mnemonic ----------------------------------------------------------------

pub fn a11y_mnemonic_test() {
  let a = a11y.new() |> a11y.mnemonic("S")
  should.equal(dict.get(a.props, "mnemonic"), Ok(StringVal("S")))
}
