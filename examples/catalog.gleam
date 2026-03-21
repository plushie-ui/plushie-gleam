//// Widget catalog: tab-based navigation across layout, input, display,
//// and composite widget categories.

import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import toddy
import toddy/app
import toddy/canvas/shape
import toddy/command
import toddy/event.{
  type Event, MouseAreaEnter, MouseAreaExit, SensorResize, WidgetClick,
  WidgetInput, WidgetSelect, WidgetSlide, WidgetToggle,
}
import toddy/node.{type Node, type PropValue, StringVal}
import toddy/prop/length
import toddy/prop/padding
import toddy/prop/position
import toddy/ui
import toddy/widget/canvas
import toddy/widget/combo_box
import toddy/widget/grid
import toddy/widget/markdown
import toddy/widget/mouse_area
import toddy/widget/pane_grid
import toddy/widget/pick_list
import toddy/widget/radio
import toddy/widget/rich_text
import toddy/widget/sensor
import toddy/widget/table
import toddy/widget/text_editor
import toddy/widget/toggler
import toddy/widget/tooltip
import toddy/widget/vertical_slider

type Model {
  Model(
    active_tab: String,
    text_value: String,
    checkbox_checked: Bool,
    toggler_on: Bool,
    slider_value: Float,
    vslider_value: Float,
    radio_selected: String,
    pick_list_selected: option.Option(String),
    combo_value: String,
    editor_content: String,
    progress: Float,
    click_count: Int,
    mouse_area_status: String,
    sensor_status: String,
    panel_collapsed: Bool,
    modal_visible: Bool,
    demo_tabs_active: String,
  )
}

fn init() {
  #(
    Model(
      active_tab: "layout",
      text_value: "",
      checkbox_checked: False,
      toggler_on: False,
      slider_value: 50.0,
      vslider_value: 50.0,
      radio_selected: "a",
      pick_list_selected: None,
      combo_value: "",
      editor_content: "Edit me...",
      progress: 65.0,
      click_count: 0,
      mouse_area_status: "idle",
      sensor_status: "waiting",
      panel_collapsed: False,
      modal_visible: False,
      demo_tabs_active: "tab_one",
    ),
    command.none(),
  )
}

fn update(model: Model, event: Event) {
  case event {
    // Tab switching
    WidgetClick(id: "tab_layout", ..) -> #(
      Model(..model, active_tab: "layout"),
      command.none(),
    )
    WidgetClick(id: "tab_input", ..) -> #(
      Model(..model, active_tab: "input"),
      command.none(),
    )
    WidgetClick(id: "tab_display", ..) -> #(
      Model(..model, active_tab: "display"),
      command.none(),
    )
    WidgetClick(id: "tab_composite", ..) -> #(
      Model(..model, active_tab: "composite"),
      command.none(),
    )

    // Input widgets
    WidgetInput(id: "demo_input", value:, ..) -> #(
      Model(..model, text_value: value),
      command.none(),
    )
    WidgetToggle(id: "demo_check", value:, ..) -> #(
      Model(..model, checkbox_checked: value),
      command.none(),
    )
    WidgetToggle(id: "demo_toggler", value:, ..) -> #(
      Model(..model, toggler_on: value),
      command.none(),
    )
    WidgetSlide(id: "demo_slider", value:, ..) -> #(
      Model(..model, slider_value: value),
      command.none(),
    )
    WidgetSlide(id: "demo_vslider", value:, ..) -> #(
      Model(..model, vslider_value: value),
      command.none(),
    )
    WidgetSelect(id: "demo_radio", value:, ..) -> #(
      Model(..model, radio_selected: value),
      command.none(),
    )
    WidgetSelect(id: "demo_pick", value:, ..) -> #(
      Model(..model, pick_list_selected: Some(value)),
      command.none(),
    )
    WidgetSelect(id: "demo_combo", value:, ..) -> #(
      Model(..model, combo_value: value),
      command.none(),
    )
    WidgetInput(id: "demo_editor", value:, ..) -> #(
      Model(..model, editor_content: value),
      command.none(),
    )

    // Composite tab
    WidgetClick(id: "tab_one", ..) -> #(
      Model(..model, demo_tabs_active: "tab_one"),
      command.none(),
    )
    WidgetClick(id: "tab_two", ..) -> #(
      Model(..model, demo_tabs_active: "tab_two"),
      command.none(),
    )
    WidgetClick(id: "show_modal", ..) -> #(
      Model(..model, modal_visible: True),
      command.none(),
    )
    WidgetClick(id: "hide_modal", ..) -> #(
      Model(..model, modal_visible: False),
      command.none(),
    )
    WidgetClick(id: "demo_panel", ..) -> #(
      Model(..model, panel_collapsed: !model.panel_collapsed),
      command.none(),
    )
    WidgetClick(id: "counter_btn", ..) -> #(
      Model(..model, click_count: model.click_count + 1),
      command.none(),
    )
    WidgetClick(id: "inc_progress", ..) -> {
      let p = case model.progress +. 5.0 >. 100.0 {
        True -> 100.0
        False -> model.progress +. 5.0
      }
      #(Model(..model, progress: p), command.none())
    }

    // Mouse area and sensor
    MouseAreaEnter(id: "demo_mouse_area", ..) -> #(
      Model(..model, mouse_area_status: "hovering"),
      command.none(),
    )
    MouseAreaExit(id: "demo_mouse_area", ..) -> #(
      Model(..model, mouse_area_status: "idle"),
      command.none(),
    )
    SensorResize(id: "demo_sensor", ..) -> #(
      Model(..model, sensor_status: "activated"),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  ui.window("catalog", [ui.title("Widget Catalog")], [
    ui.column("root", [ui.spacing(12), ui.padding(padding.all(16.0))], [
      ui.text("catalog_title", "Toddy Widget Catalog", [ui.font_size(24.0)]),
      ui.rule("divider1", []),
      ui.row("tabs", [ui.spacing(8)], [
        ui.button_("tab_layout", "Layout"),
        ui.button_("tab_input", "Input"),
        ui.button_("tab_display", "Display"),
        ui.button_("tab_composite", "Composite"),
      ]),
      ui.rule("divider2", []),
      case model.active_tab {
        "layout" -> layout_tab()
        "input" -> input_tab(model)
        "display" -> display_tab(model)
        "composite" -> composite_tab(model)
        _ -> layout_tab()
      },
    ]),
  ])
}

// -- Layout tab ---------------------------------------------------------------

fn layout_tab() -> Node {
  ui.column("layout_content", [ui.spacing(8)], [
    ui.text("layout_heading", "Layout Widgets", [ui.font_size(18.0)]),
    // Row
    ui.row("demo_row", [ui.spacing(8)], [
      ui.text_("row_1", "Row child 1"),
      ui.text_("row_2", "Row child 2"),
      ui.text_("row_3", "Row child 3"),
    ]),
    // Nested column
    ui.column("nested_col", [ui.spacing(4)], [
      ui.text_("ncol_1", "Nested column child 1"),
      ui.text_("ncol_2", "Nested column child 2"),
    ]),
    // Container
    ui.container("demo_container", [ui.padding(padding.all(12.0))], [
      ui.text_("container_text", "Inside a container"),
    ]),
    // Scrollable
    ui.scrollable("demo_scrollable", [], [
      ui.column("scroll_col", [ui.spacing(4)], [
        ui.text_("scroll_1", "Scrollable item 1"),
        ui.text_("scroll_2", "Scrollable item 2"),
        ui.text_("scroll_3", "Scrollable item 3"),
        ui.text_("scroll_4", "Scrollable item 4"),
        ui.text_("scroll_5", "Scrollable item 5"),
      ]),
    ]),
    // Stack
    ui.stack("demo_stack", [], [
      ui.text_("stack_1", "Stack layer 1 (back)"),
      ui.text_("stack_2", "Stack layer 2 (front)"),
    ]),
    // Grid
    grid.new("demo_grid")
      |> grid.columns(3)
      |> grid.spacing(4)
      |> grid.extend([
        ui.text_("grid_1", "Grid 1"),
        ui.text_("grid_2", "Grid 2"),
        ui.text_("grid_3", "Grid 3"),
        ui.text_("grid_4", "Grid 4"),
        ui.text_("grid_5", "Grid 5"),
        ui.text_("grid_6", "Grid 6"),
      ])
      |> grid.build(),
    // Space
    ui.space("demo_space", [ui.height(length.Fixed(16.0))]),
  ])
}

// -- Input tab ----------------------------------------------------------------

fn input_tab(model: Model) -> Node {
  ui.column("input_content", [ui.spacing(8)], [
    ui.text("input_heading", "Input Widgets", [ui.font_size(18.0)]),
    // Text input
    ui.text_input("demo_input", model.text_value, [
      ui.placeholder("Type here..."),
    ]),
    // Button
    ui.button_("demo_button", "A Button"),
    // Checkbox
    ui.checkbox("demo_check", "Check me", model.checkbox_checked, []),
    // Toggler
    toggler.new("demo_toggler", "Toggle me", model.toggler_on)
      |> toggler.build(),
    // Radio group
    ui.row("radio_row", [ui.spacing(8)], [
      radio.new("demo_radio_a", "a", Some(model.radio_selected), "Option A")
        |> radio.group("demo_radio")
        |> radio.build(),
      radio.new("demo_radio_b", "b", Some(model.radio_selected), "Option B")
        |> radio.group("demo_radio")
        |> radio.build(),
      radio.new("demo_radio_c", "c", Some(model.radio_selected), "Option C")
        |> radio.group("demo_radio")
        |> radio.build(),
    ]),
    // Slider
    ui.slider("demo_slider", #(0.0, 100.0), model.slider_value, []),
    ui.text_("slider_val", "Slider: " <> float.to_string(model.slider_value)),
    // Vertical slider
    vertical_slider.new("demo_vslider", #(0.0, 100.0), model.vslider_value)
      |> vertical_slider.build(),
    // Pick list
    pick_list.new(
      "demo_pick",
      ["Small", "Medium", "Large"],
      model.pick_list_selected,
    )
      |> pick_list.placeholder("Pick a size...")
      |> pick_list.build(),
    // Combo box
    combo_box.new("demo_combo", ["Elixir", "Rust", "Go"], model.combo_value)
      |> combo_box.placeholder("Choose a language...")
      |> combo_box.build(),
    // Text editor
    text_editor.new("demo_editor", model.editor_content)
      |> text_editor.height(length.Fixed(100.0))
      |> text_editor.build(),
  ])
}

// -- Display tab --------------------------------------------------------------

fn display_tab(model: Model) -> Node {
  ui.column("display_content", [ui.spacing(8)], [
    ui.text("display_heading", "Display Widgets", [ui.font_size(18.0)]),
    // Plain text
    ui.text_("plain_text", "Plain text label"),
    // Rule
    ui.rule("display_rule", []),
    // Progress bar
    ui.row("progress_row", [ui.spacing(8)], [
      ui.progress_bar("demo_progress", #(0.0, 100.0), model.progress, []),
      ui.button_("inc_progress", "+5%"),
    ]),
    // Tooltip
    tooltip.new("demo_tooltip", "This is a tooltip")
      |> tooltip.position(position.Top)
      |> tooltip.push(ui.button_("tooltip_target", "Hover me for tooltip"))
      |> tooltip.build(),
    // Image
    ui.image("demo_image", "/assets/placeholder.png", [
      ui.width(length.Fixed(120.0)),
      ui.height(length.Fixed(80.0)),
    ]),
    // Markdown
    markdown.new(
      "demo_markdown",
      "## Markdown\n\nSome **bold** and *italic* text.\n\n- Item one\n- Item two",
    )
      |> markdown.build(),
    // Rich text with styled spans
    rich_text.new("demo_rich_text")
      |> rich_text.spans([
        rich_text.span("Bold text ")
          |> rich_text.span_size(16.0),
        rich_text.span("italic text "),
        rich_text.span("normal text "),
        rich_text.span("colored text"),
      ])
      |> rich_text.build(),
    // Canvas with geometric shapes
    canvas.new("demo_canvas", length.Fixed(200.0), length.Fixed(150.0))
      |> canvas.layers(
        dict.from_list([
          #("default", [
            shape.rect(10.0, 10.0, 80.0, 60.0, [shape.Fill("#3498db")]),
            shape.circle(150.0, 75.0, 40.0, [shape.Fill("#e74c3c")]),
            shape.line(10.0, 130.0, 190.0, 130.0, [
              shape.Stroke(shape.stroke("#2ecc71", 2.0, [])),
            ]),
          ]),
        ]),
      )
      |> canvas.build(),
  ])
}

// -- Composite tab ------------------------------------------------------------

fn composite_tab(model: Model) -> Node {
  let modal_children = case model.modal_visible {
    True -> [
      ui.container("demo_modal", [ui.padding(padding.all(16.0))], [
        ui.column("modal_col", [ui.spacing(8)], [
          ui.text_("modal_text", "Modal Content"),
          ui.button_("hide_modal", "Close"),
        ]),
      ]),
    ]
    False -> []
  }

  let panel_children = case model.panel_collapsed {
    True -> []
    False -> [
      ui.container("panel_content", [ui.padding(padding.all(8.0))], [
        ui.text_("panel_text", "Panel content that can be collapsed"),
      ]),
    ]
  }

  let tab_content = case model.demo_tabs_active {
    "tab_one" -> ui.text_("tab_content", "Tab one content")
    _ -> ui.text_("tab_content", "Tab two content")
  }

  let panel_label = case model.panel_collapsed {
    True -> "Expand Panel"
    False -> "Collapse Panel"
  }

  ui.column(
    "composite_content",
    [ui.spacing(8)],
    list.flatten([
      [
        ui.text("composite_heading", "Interactive & Composite Widgets", [
          ui.font_size(18.0),
        ]),
        // Mouse area
        mouse_area.new("demo_mouse_area")
          |> mouse_area.on_enter(True)
          |> mouse_area.on_exit(True)
          |> mouse_area.push(
            ui.container("mouse_area_box", [ui.padding(padding.all(12.0))], [
              ui.text_("mouse_text", "Mouse area: " <> model.mouse_area_status),
            ]),
          )
          |> mouse_area.build(),
        // Sensor
        sensor.new("demo_sensor")
          |> sensor.push(
            ui.container("sensor_box", [ui.padding(padding.all(12.0))], [
              ui.text_("sensor_text", "Sensor: " <> model.sensor_status),
            ]),
          )
          |> sensor.build(),
        // Simulated tabs
        ui.container("demo_tabs", [], [
          ui.column("tabs_col", [ui.spacing(4)], [
            ui.row("tabs_row", [ui.spacing(4)], [
              ui.button_("tab_one", "Tab One"),
              ui.button_("tab_two", "Tab Two"),
            ]),
            tab_content,
          ]),
        ]),
        // Modal
        ui.button_("show_modal", "Show Modal"),
      ],
      modal_children,
      [
        // Collapsible panel
        ui.button_("demo_panel", panel_label),
      ],
      panel_children,
      [
        // Counter
        ui.row("counter_row", [ui.spacing(8)], [
          ui.button_("counter_btn", "Click me"),
          ui.text_(
            "click_text",
            "Clicked " <> int.to_string(model.click_count) <> " times",
          ),
        ]),
        // PaneGrid
        pane_grid.new("demo_panes")
          |> pane_grid.spacing(2)
          |> pane_grid.push(
            ui.container("pane_left", [ui.padding(padding.all(8.0))], [
              ui.column("pane_left_col", [], [
                ui.text_("pl_1", "Left pane"),
                ui.text_("pl_2", "Navigation or file tree"),
              ]),
            ]),
          )
          |> pane_grid.push(
            ui.container("pane_right", [ui.padding(padding.all(8.0))], [
              ui.column("pane_right_col", [], [
                ui.text_("pr_1", "Right pane"),
                ui.text_("pr_2", "Main editor area"),
              ]),
            ]),
          )
          |> pane_grid.build(),
        // Table
        table.new("demo_table")
          |> table.columns([
            table.column("name", "Name"),
            table.column("lang", "Language"),
            table.column("stars", "Stars"),
          ])
          |> table.rows([
            dict.from_list([
              #("name", StringVal("Phoenix")),
              #("lang", StringVal("Elixir")),
              #("stars", StringVal("20k")),
            ]),
            dict.from_list([
              #("name", StringVal("Iced")),
              #("lang", StringVal("Rust")),
              #("stars", StringVal("24k")),
            ]),
            dict.from_list([
              #("name", StringVal("React")),
              #("lang", StringVal("JavaScript")),
              #("stars", StringVal("220k")),
            ]),
          ])
          |> table.build(),
      ],
    ]),
  )
}

pub fn main() {
  let my_app = app.simple(init, update, view)
  let _ = toddy.start(my_app, toddy.default_start_opts())
  process.sleep_forever()
}
