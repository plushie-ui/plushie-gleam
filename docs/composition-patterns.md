# Composition patterns

Plushie provides primitives, not pre-built composites. There is no `TabBar`
widget, no `Modal` widget, no `Card` widget. Instead, you compose the same
building blocks -- `row`, `column`, `container`, `stack`, `button`, `text`,
`rule`, `mouse_area`, `space` -- with `StyleMap` to build any UI pattern you
need.

This guide shows how. Every pattern is copy-pasteable and produces a polished
result. All examples use `plushie/ui` functions and assume you have the following
at the top of your module:

```gleam
import plushie/ui
import plushie/prop/style_map.{type StyleMap}
import plushie/prop/border
import plushie/prop/shadow
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding
import plushie/prop/alignment
```

---

## 1. Tab bar

A horizontal row of buttons where the active tab is visually distinct from
the inactive ones. Common at the top of a content area to switch between
views.

### Code

<!-- test: tab_bar_init_test, tab_bar_click_changes_active_tab_test, tab_bar_view_has_three_tab_buttons_test -- keep this code block in sync with the test -->
```gleam
import gleam/int
import gleam/list
import gleam/string
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding
import plushie/prop/style_map
import plushie/ui

pub type Model {
  Model(active_tab: String)
}

const tabs = ["overview", "details", "settings"]

pub fn init(_flags) {
  #(Model(active_tab: "overview"), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "tab:" <> name, ..) ->
      #(Model(active_tab: name), command.None)
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Tab Demo")], [
    ui.column("tabs_layout", [ui.width(Fill)], [
      ui.row("tab_row", [ui.spacing(0)],
        list.map(tabs, fn(tab) {
          ui.button("tab:" <> tab, string.capitalise(tab), [
            ui.style_map(tab_style(model.active_tab == tab)),
            ui.padding(padding.xy(10.0, 20.0)),
          ])
        }),
      ),
      // Bottom border under the tab bar
      ui.rule("tab_rule", []),
      // Content area
      ui.container("content", [
        ui.padding(padding.all(20)),
        ui.width(Fill),
        ui.height(Fill),
      ], [
        ui.text_("tab_content", "Content for " <> model.active_tab),
      ]),
    ]),
  ])
}

fn tab_style(active: Bool) -> StyleMap {
  case active {
    True ->
      style_map.new()
      |> style_map.background("#ffffff")
      |> style_map.text_color("#1a1a1a")
      |> style_map.border(
        border.new()
        |> border.color("#0066ff")
        |> border.width(2.0)
        |> border.radius(0.0)
        |> border.to_prop_value()
      )
    False ->
      style_map.new()
      |> style_map.background("#f0f0f0")
      |> style_map.text_color("#666666")
      |> style_map.hovered(
        style_map.new() |> style_map.background("#e0e0e0"),
      )
  }
}
```

### How it works

Each tab is a `button` with a `StyleMap` driven by whether it matches the
active tab. The active style uses a solid background and a blue border to
create the "selected" indicator. Inactive tabs get a flat grey look with a
hover state for feedback. The `list.map` call inside the `row` generates one
button per tab.

The `rule` below the row acts as a full-width horizontal divider, visually
anchoring the tab bar to the content below.

### What it looks like

A horizontal row of flat buttons flush against each other. The active tab
has a white background with a blue bottom border. Inactive tabs are light
grey and lighten on hover. Below the tabs, a thin horizontal line separates
the bar from the content area.

---

## 2. Sidebar navigation

A dark column on the left side of the window containing navigation items
that highlight on hover. The selected item has an accent background.

### Code

<!-- test: sidebar_init_test, sidebar_click_changes_page_test, sidebar_view_has_nav_items_test -- keep this code block in sync with the test -->
```gleam
import gleam/list
import gleam/string
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding.{Padding}
import plushie/prop/style_map
import plushie/ui

pub type Model {
  Model(page: String)
}

const nav_items = [
  #("inbox", "Inbox"),
  #("sent", "Sent"),
  #("drafts", "Drafts"),
  #("trash", "Trash"),
]

pub fn init(_flags) {
  #(Model(page: "inbox"), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "nav:" <> name, ..) ->
      #(Model(page: name), command.None)
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Sidebar Demo")], [
    ui.row("layout", [ui.width(Fill), ui.height(Fill)], [
      // Sidebar
      ui.container("sidebar", [
        ui.width(Px(200.0)),
        ui.height(Fill),
        ui.background("#1e1e2e"),
        ui.padding(padding.all(8)),
      ], [
        ui.column("nav", [ui.spacing(4), ui.width(Fill)], [
          ui.text("nav_label", "Navigation", [
            ui.font_size(12.0),
            ui.text_color("#888888"),
          ]),
          ui.space("nav_spacer", [ui.height(Px(8.0))]),
          ..list.map(nav_items, fn(item) {
            let #(id, label) = item
            ui.button("nav:" <> id, label, [
              ui.style_map(nav_item_style(model.page == id)),
              ui.width(Fill),
              ui.padding(Padding(top: 8.0, right: 8.0, bottom: 12.0, left: 12.0)),
            ])
          })
        ]),
      ]),
      // Main content
      ui.container("main", [
        ui.width(Fill),
        ui.height(Fill),
        ui.padding(padding.all(24)),
      ], [
        ui.text("page_title", string.capitalise(model.page) <> " page", [
          ui.font_size(20.0),
        ]),
      ]),
    ]),
  ])
}

fn nav_item_style(selected: Bool) -> StyleMap {
  case selected {
    True ->
      style_map.new()
      |> style_map.background("#3366ff")
      |> style_map.text_color("#ffffff")
      |> style_map.hovered(
        style_map.new() |> style_map.background("#4477ff"),
      )
    False ->
      style_map.new()
      |> style_map.background("#1e1e2e")
      |> style_map.text_color("#cccccc")
      |> style_map.hovered(
        style_map.new()
        |> style_map.background("#2a2a3e")
        |> style_map.text_color("#ffffff"),
      )
  }
}
```

### How it works

The outer `row` splits the window into two areas: a fixed-width sidebar and
a fill-width content area. The sidebar is a `container` with a dark
background colour. Inside it, nav items are `button` widgets spanning the
full sidebar width.

The selected item uses `StyleMap` with a blue background and white text.
Unselected items match the sidebar background so they appear invisible until
hovered, when they brighten slightly. This gives the classic "highlight on
hover, solid on select" sidebar feel.

### What it looks like

A dark panel (200px wide) on the left. Four text labels stacked vertically
inside it. The active item has a blue background. Hovering over other items
reveals a subtle lighter background. The rest of the window is the content
area.

---

## 3. Toolbar

A compact horizontal bar with grouped icon-style buttons separated by
vertical rules. Toolbars typically sit at the top of an editor or document
view.

### Code

```gleam
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding
import plushie/prop/style_map
import plushie/ui

pub type Model {
  Model(bold: Bool, italic: Bool, underline: Bool)
}

pub fn init(_flags) {
  #(Model(bold: False, italic: False, underline: False), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "tool:bold", ..) ->
      #(Model(..model, bold: !model.bold), command.None)
    WidgetClick(id: "tool:italic", ..) ->
      #(Model(..model, italic: !model.italic), command.None)
    WidgetClick(id: "tool:underline", ..) ->
      #(Model(..model, underline: !model.underline), command.None)
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Toolbar Demo")], [
    ui.column("layout", [ui.width(Fill)], [
      // Toolbar
      ui.container("toolbar", [
        ui.width(Fill),
        ui.background("#f5f5f5"),
        ui.padding(padding.all(4)),
      ], [
        ui.row("tools", [ui.spacing(2), ui.align_y(alignment.Center)], [
          // File group
          ui.button("tool:new", "New", [
            ui.style_map(tool_style(False)),
            ui.padding(padding.all(6)),
          ]),
          ui.button("tool:open", "Open", [
            ui.style_map(tool_style(False)),
            ui.padding(padding.all(6)),
          ]),
          ui.button("tool:save", "Save", [
            ui.style_map(tool_style(False)),
            ui.padding(padding.all(6)),
          ]),
          // Separator
          ui.rule("sep1", [ui.direction("vertical"), ui.height(Px(20.0))]),
          // Format group
          ui.button("tool:bold", "B", [
            ui.style_map(tool_style(model.bold)),
            ui.padding(padding.all(6)),
          ]),
          ui.button("tool:italic", "I", [
            ui.style_map(tool_style(model.italic)),
            ui.padding(padding.all(6)),
          ]),
          ui.button("tool:underline", "U", [
            ui.style_map(tool_style(model.underline)),
            ui.padding(padding.all(6)),
          ]),
          // Separator
          ui.rule("sep2", [ui.direction("vertical"), ui.height(Px(20.0))]),
          // Spacer pushes trailing items to the right
          ui.space("flex", [ui.width(Fill)]),
          ui.button("tool:help", "?", [
            ui.style_map(tool_style(False)),
            ui.padding(padding.all(6)),
          ]),
        ]),
      ]),
      ui.rule("toolbar_rule", []),
      // Editor area
      ui.container("editor", [
        ui.width(Fill),
        ui.height(Fill),
        ui.padding(padding.all(16)),
      ], [
        ui.text_("content", "Editor content goes here"),
      ]),
    ]),
  ])
}

fn tool_style(toggled: Bool) -> StyleMap {
  case toggled {
    True ->
      style_map.new()
      |> style_map.background("#d0d0d0")
      |> style_map.text_color("#1a1a1a")
      |> style_map.border(
        border.new()
        |> border.color("#b0b0b0")
        |> border.width(1.0)
        |> border.radius(3.0)
        |> border.to_prop_value()
      )
      |> style_map.hovered(
        style_map.new() |> style_map.background("#c0c0c0"),
      )
    False ->
      style_map.new()
      |> style_map.background("#f5f5f5")
      |> style_map.text_color("#333333")
      |> style_map.hovered(
        style_map.new() |> style_map.background("#e0e0e0"),
      )
      |> style_map.pressed(
        style_map.new() |> style_map.background("#d0d0d0"),
      )
  }
}
```

### How it works

The toolbar is a `container` with a light background wrapping a `row`. Button
groups are visually separated by vertical `rule` widgets. A `space(width:
Fill)` between the main group and the help button pushes the help button to
the far right -- a common toolbar layout technique.

Toggle-style buttons (bold, italic, underline) pass their current state to
`tool_style`. When toggled on, they get a depressed look via a darker
background and a subtle border. The `pressed` status override on untoggled
buttons gives tactile click feedback.

### What it looks like

A light grey horizontal bar at the top. Three button groups separated by
thin vertical lines. "New | Open | Save", then "B | I | U", then a "?"
button pushed to the far right. Toggled buttons appear slightly sunken.

---

## 4. Modal dialog

A full-screen overlay with a centered dialog box on top. Uses `stack` to
layer the overlay behind the dialog. The overlay is a semi-transparent
container that dims the background.

### Code

<!-- test: modal_init_test, modal_open_test, modal_confirm_test, modal_view_has_overlay_when_open_test -- keep this code block in sync with the test -->
```gleam
import gleam/list
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding
import plushie/prop/shadow
import plushie/prop/style_map
import plushie/prop/alignment
import plushie/ui

pub type Model {
  Model(show_modal: Bool, confirmed: Bool)
}

pub fn init(_flags) {
  #(Model(show_modal: False, confirmed: False), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "open_modal", ..) ->
      #(Model(..model, show_modal: True), command.None)
    WidgetClick(id: "confirm", ..) ->
      #(Model(show_modal: False, confirmed: True), command.None)
    WidgetClick(id: "cancel", ..) ->
      #(Model(..model, show_modal: False), command.None)
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  let main_content =
    ui.container("main", [
      ui.width(Fill),
      ui.height(Fill),
      ui.padding(padding.all(24)),
      ui.align_x(alignment.Center),
      ui.align_y(alignment.Center),
    ], [
      ui.column("main_col", [
        ui.spacing(12),
        ui.align_x(alignment.Center),
      ], list.concat([
        [ui.text("main_content", "Main application content", [
          ui.font_size(20.0),
        ])],
        case model.confirmed {
          True -> [ui.text("confirmed_msg", "Action confirmed.", [
            ui.text_color("#22aa44"),
          ])]
          False -> []
        },
        [ui.button("open_modal", "Open Dialog", [ui.style("primary")])],
      ])),
    ])

  let modal_layer = case model.show_modal {
    True -> [
      ui.container("overlay", [
        ui.width(Fill),
        ui.height(Fill),
        ui.background("#00000088"),
        ui.align_x(alignment.Center),
        ui.align_y(alignment.Center),
      ], [
        ui.container("dialog", [
          ui.max_width(400.0),
          ui.padding(padding.all(24)),
          ui.background("#ffffff"),
          ui.border(
            border.new()
            |> border.color("#dddddd")
            |> border.width(1.0)
            |> border.radius(8.0)
          ),
          ui.shadow(
            shadow.new()
            |> shadow.color("#00000040")
            |> shadow.offset(0.0, 4.0)
            |> shadow.blur_radius(16.0)
          ),
        ], [
          ui.column("dialog_col", [ui.spacing(16)], [
            ui.text("dialog_title", "Confirm action", [
              ui.font_size(18.0),
              ui.text_color("#1a1a1a"),
            ]),
            ui.text("dialog_body",
              "Are you sure you want to proceed? This cannot be undone.",
              [ui.text_color("#555555")],
            ),
            ui.row("dialog_actions", [
              ui.spacing(8),
              ui.align_x(alignment.End),
            ], [
              ui.button("cancel", "Cancel", [ui.style("secondary")]),
              ui.button("confirm", "Confirm", [ui.style("primary")]),
            ]),
          ]),
        ]),
      ]),
    ]
    False -> []
  }

  ui.window("main", [ui.title("Modal Demo")], [
    ui.stack("modal_stack", [ui.width(Fill), ui.height(Fill)],
      [main_content, ..modal_layer],
    ),
  ])
}
```

### How it works

`stack` layers its children front-to-back. The main content is layer 0.
When `show_modal` is true, the overlay container appears as layer 1 on top.

The overlay is a full-size container with `background: "#00000088"` -- the
last two hex digits (`88`) set ~53% opacity, dimming everything behind it.
Setting `align_x` and `align_y` to `Center` on the overlay centres its
single child: the dialog card.

The dialog card is a container with a white background, rounded border, and
a drop shadow. The shadow offset `(0, 4)` with a 16px blur gives a natural
"floating above" appearance.

When `show_modal` is false, the modal layer list is empty, so the overlay
and dialog simply do not exist in the tree.

### What it looks like

A centred page with a button. Clicking the button dims the entire window
behind a dark translucent overlay. A white rounded card appears in the
centre with a title, message text, and Cancel/Confirm buttons. The card has
a soft drop shadow.

---

## 5. Card

A container with rounded corners, a border, an optional shadow, and an
optional header section. The simplest composition pattern -- it is just a
styled container.

### Code

<!-- test: card_helper_produces_correct_structure_test -- keep this code block in sync with the test -->
```gleam
import gleam/list
import plushie/app
import plushie/command
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding
import plushie/prop/shadow
import plushie/ui

pub type Model {
  Model
}

pub fn init(_flags) {
  #(Model, command.None)
}

pub fn update(model: Model, _event: Event) {
  #(model, command.None)
}

pub fn view(_model: Model) -> Node {
  ui.window("main", [ui.title("Card Demo")], [
    ui.column("cards", [
      ui.padding(padding.all(24)),
      ui.spacing(16),
      ui.width(Fill),
    ], [
      // Simple card
      card("info", "System status", [
        ui.text("status_msg", "All services operational", [
          ui.text_color("#22aa44"),
        ]),
        ui.text("last_checked", "Last checked: 2 minutes ago", [
          ui.font_size(12.0),
          ui.text_color("#888888"),
        ]),
      ]),
      // Card with action
      ui.container("promo", [
        ui.width(Fill),
        ui.padding(padding.all(0)),
        ui.border(
          border.new()
          |> border.color("#e0e0e0")
          |> border.width(1.0)
          |> border.radius(8.0)
        ),
        ui.shadow(
          shadow.new()
          |> shadow.color("#00000020")
          |> shadow.offset(0.0, 2.0)
          |> shadow.blur_radius(8.0)
        ),
        ui.background("#ffffff"),
        ui.clip(True),
      ], [
        ui.column("promo_col", [ui.width(Fill)], [
          // Header band
          ui.container("promo_header", [
            ui.width(Fill),
            ui.padding(padding.all(12)),
            ui.background("#3366ff"),
          ], [
            ui.text("promo_title", "Upgrade available", [
              ui.font_size(14.0),
              ui.text_color("#ffffff"),
            ]),
          ]),
          // Body
          ui.container("promo_body", [
            ui.width(Fill),
            ui.padding(padding.all(16)),
          ], [
            ui.column("promo_body_col", [ui.spacing(12)], [
              ui.text_("promo_desc",
                "Version 2.0 brings new features and performance improvements.",
              ),
              ui.button("upgrade", "Upgrade now", [ui.style("primary")]),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}

/// Reusable card helper. Returns a container node.
fn card(id: String, title: String, body: List(Node)) -> Node {
  let b =
    border.new()
    |> border.color("#e0e0e0")
    |> border.width(1.0)
    |> border.radius(8.0)
  let s =
    shadow.new()
    |> shadow.color("#00000020")
    |> shadow.offset(0.0, 2.0)
    |> shadow.blur_radius(8.0)

  ui.container(id, [
    ui.width(Fill),
    ui.padding(padding.all(16)),
    ui.background("#ffffff"),
    ui.border(b),
    ui.shadow(s),
  ], [
    ui.column(id <> "_col", [ui.spacing(8)], list.concat([
      [
        ui.text("card_title", title, [
          ui.font_size(16.0),
          ui.text_color("#1a1a1a"),
        ]),
        ui.rule(id <> "_rule", []),
      ],
      body,
    ])),
  ])
}
```

### How it works

A card is a `container` with four visual properties: `background` for the
fill colour, `border` with a rounded radius for the outline, `shadow` for
depth, and `padding` for internal spacing. That is the entire pattern.

The `card` helper extracts this into a reusable function. It takes an id,
a title string, and a list of child nodes for the body. The child nodes are
concatenated with the title and rule into the card's column.

The "promo" card demonstrates a header band: a nested container with a
coloured background and `clip: True` on the outer card so the header's
background respects the rounded corners.

### What it looks like

Rounded white rectangles with subtle borders and soft shadows. The first
card has a title, a divider line, and body text. The second has a blue
header band spanning the full width, body text below, and a primary-styled
button.

---

## 6. Split panel

Two content areas side by side with a draggable divider between them. The
divider is a vertical `rule` wrapped in a `mouse_area` that changes the
cursor to a horizontal resize indicator.

### Code

<!-- test: split_panel_has_three_sections_test -- keep this code block in sync with the test -->
```gleam
import plushie/app
import plushie/command
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding
import plushie/ui

pub type Model {
  Model(left_width: Float)
}

pub fn init(_flags) {
  #(Model(left_width: 300.0), command.None)
}

// In a real app, you would track mouse drag events to resize.
// This example shows the static layout and cursor feedback.
pub fn update(model: Model, _event: Event) {
  #(model, command.None)
}

pub fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Split Panel Demo")], [
    ui.row("split", [ui.width(Fill), ui.height(Fill)], [
      // Left panel
      ui.container("left_panel", [
        ui.width(Px(model.left_width)),
        ui.height(Fill),
        ui.padding(padding.all(16)),
        ui.background("#fafafa"),
      ], [
        ui.column("left_col", [ui.spacing(8)], [
          ui.text("left_title", "Left panel", [ui.font_size(16.0)]),
          ui.text("left_desc",
            "File browser, outline, or any sidebar content.",
            [ui.text_color("#666666")],
          ),
        ]),
      ]),
      // Draggable divider
      ui.mouse_area("divider", [ui.cursor("resizing_horizontally")], [
        ui.container("divider_track", [
          ui.width(Px(5.0)),
          ui.height(Fill),
          ui.background("#e0e0e0"),
        ], [
          ui.rule("divider_rule", [ui.direction("vertical")]),
        ]),
      ]),
      // Right panel
      ui.container("right_panel", [
        ui.width(Fill),
        ui.height(Fill),
        ui.padding(padding.all(16)),
      ], [
        ui.column("right_col", [ui.spacing(8)], [
          ui.text("right_title", "Right panel", [ui.font_size(16.0)]),
          ui.text("right_desc", "Main editor or content area.", [
            ui.text_color("#666666"),
          ]),
        ]),
      ]),
    ]),
  ])
}
```

### How it works

The outer `row` holds three children: left panel, divider, right panel. The
left panel has a fixed pixel width. The right panel uses `width: Fill` to
take the remaining space.

The divider is a `mouse_area` wrapping a thin container. The `cursor:
"resizing_horizontally"` prop changes the mouse cursor to the standard
horizontal resize indicator when the user hovers over the divider, giving
clear affordance that it is draggable.

In a production app you would handle mouse press/release events on the
divider along with mouse move tracking to update `left_width` dynamically.
The static layout pattern is the same regardless.

### What it looks like

Two panels side by side filling the window. A thin grey vertical bar between
them. Hovering over the bar changes the cursor to a horizontal resize arrow.

---

## 7. Breadcrumb

A horizontal trail of clickable path segments separated by ">" characters.
The last segment is plain text (not clickable) representing the current
location.

### Code

<!-- test: breadcrumb_click_truncates_path_test -- keep this code block in sync with the test -->
```gleam
import gleam/int
import gleam/list
import gleam/string
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/length.{Fill}
import plushie/prop/padding.{Padding}
import plushie/prop/style_map
import plushie/ui

pub type Model {
  Model(path: List(String))
}

pub fn init(_flags) {
  #(Model(path: ["Home", "Projects", "Plushie", "Docs"]), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "crumb:" <> index_str, ..) -> {
      let assert Ok(index) = int.parse(index_str)
      #(Model(path: list.take(model.path, index + 1)), command.None)
    }
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  let last_index = list.length(model.path) - 1

  let crumbs =
    model.path
    |> list.index_map(fn(segment, index) {
      case index == last_index {
        // Current location: plain text, not clickable
        True -> [
          ui.text("crumb_current", segment, [
            ui.font_size(14.0),
            ui.text_color("#1a1a1a"),
          ]),
        ]
        // Clickable ancestor
        False -> [
          ui.button("crumb:" <> int.to_string(index), segment, [
            ui.style_map(crumb_style()),
            ui.padding(Padding(top: 2.0, right: 2.0, bottom: 4.0, left: 4.0)),
          ]),
          ui.text("sep:" <> int.to_string(index), ">", [
            ui.font_size(14.0),
            ui.text_color("#999999"),
          ]),
        ]
      }
    })
    |> list.flatten()

  ui.window("main", [ui.title("Breadcrumb Demo")], [
    ui.column("layout", [
      ui.padding(padding.all(16)),
      ui.spacing(16),
      ui.width(Fill),
    ], [
      ui.row("breadcrumbs", [
        ui.spacing(4),
        ui.align_y(alignment.Center),
      ], crumbs),
      ui.rule("bc_rule", []),
      ui.text("viewing",
        "Viewing: " <> {
          list.last(model.path) |> result.unwrap("(none)")
        },
        [ui.font_size(18.0)],
      ),
    ]),
  ])
}

fn crumb_style() -> StyleMap {
  style_map.new()
  |> style_map.background("#00000000")
  |> style_map.text_color("#3366ff")
  |> style_map.hovered(
    style_map.new()
    |> style_map.text_color("#1144cc")
    |> style_map.background("#f0f0ff"),
  )
  |> style_map.pressed(
    style_map.new() |> style_map.text_color("#0033aa"),
  )
}
```

### How it works

The breadcrumb is a `row` containing an interleaved sequence of buttons and
separator text nodes. The `list.index_map` call iterates over the path
segments with their index. For every segment except the last, it emits a
two-element list: a clickable button and a ">" separator. The nested lists
are then flattened into a single child list.

The last segment is rendered as plain `text` -- no click handler, no hover
state. This signals "you are here" without needing a disabled button.

The crumb buttons use a fully transparent background (`#00000000`) so they
look like plain text links. The hover state adds a subtle blue tint and
changes the text colour, mimicking a hyperlink.

Clicking a breadcrumb truncates the path to that index, navigating "up".

### What it looks like

A horizontal line of text: "Home > Projects > Plushie > Docs". Everything
except "Docs" is blue and clickable. Hovering over a segment highlights it
with a light blue background. "Docs" is plain dark text.

---

## 8. Badge / chip

A small container with a coloured background and fully rounded corners. Used
for tags, counts, status indicators, or filter chips.

### Code

<!-- test: chip_toggle_on_test, chip_toggle_off_test -- keep this code block in sync with the test -->
```gleam
import gleam/list
import gleam/set.{type Set}
import gleam/string
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/length.{Fill}
import plushie/prop/padding.{Padding}
import plushie/prop/style_map
import plushie/ui

pub type Model {
  Model(selected: Set(String))
}

const tags = ["elixir", "rust", "iced", "desktop"]

pub fn init(_flags) {
  #(Model(selected: set.from_list(["elixir"])), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "tag:" <> name, ..) -> {
      let selected = case set.contains(model.selected, name) {
        True -> set.delete(model.selected, name)
        False -> set.insert(model.selected, name)
      }
      #(Model(selected:), command.None)
    }
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Badge Demo")], [
    ui.column("layout", [
      ui.padding(padding.all(24)),
      ui.spacing(16),
      ui.width(Fill),
    ], [
      // Status badges (display only)
      ui.row("status_row", [ui.spacing(8), ui.align_y(alignment.Center)], [
        ui.text("status_label", "Status:", [ui.font_size(14.0)]),
        badge("online", "Online", "#22aa44", "#ffffff"),
        badge("count", "3 new", "#3366ff", "#ffffff"),
        badge("warn", "Deprecated", "#ff8800", "#ffffff"),
      ]),
      ui.rule("badge_rule", []),
      // Filter chips (clickable)
      ui.text_("filter_label", "Filter by tag:"),
      ui.row("chips", [ui.spacing(6)],
        list.map(tags, fn(tag) {
          ui.button("tag:" <> tag, tag, [
            ui.style_map(chip_style(set.contains(model.selected, tag))),
            ui.padding(Padding(top: 4.0, right: 4.0, bottom: 10.0, left: 10.0)),
          ])
        }),
      ),
      ui.text("selected_display",
        "Selected: " <> {
          model.selected
          |> set.to_list()
          |> list.sort(string.compare)
          |> string.join(", ")
        },
        [ui.text_color("#666666")],
      ),
    ]),
  ])
}

/// Display-only badge: a small container with pill shape.
fn badge(id: String, label: String, bg_color: String, txt_color: String) -> Node {
  ui.container(id, [
    ui.padding(Padding(top: 2.0, right: 2.0, bottom: 8.0, left: 8.0)),
    ui.background(bg_color),
    ui.border(
      border.new() |> border.radius(999.0)
    ),
  ], [
    ui.text("badge_text_" <> id, label, [
      ui.font_size(11.0),
      ui.text_color(txt_color),
    ]),
  ])
}

/// Clickable chip style: pill-shaped button with toggle state.
fn chip_style(selected: Bool) -> StyleMap {
  case selected {
    True ->
      style_map.new()
      |> style_map.background("#3366ff")
      |> style_map.text_color("#ffffff")
      |> style_map.border(
        border.new()
        |> border.color("#3366ff")
        |> border.width(1.0)
        |> border.radius(999.0)
        |> border.to_prop_value()
      )
      |> style_map.hovered(
        style_map.new() |> style_map.background("#4477ff"),
      )
    False ->
      style_map.new()
      |> style_map.background("#f0f0f0")
      |> style_map.text_color("#333333")
      |> style_map.border(
        border.new()
        |> border.color("#cccccc")
        |> border.width(1.0)
        |> border.radius(999.0)
        |> border.to_prop_value()
      )
      |> style_map.hovered(
        style_map.new() |> style_map.background("#e4e4e4"),
      )
  }
}
```

### How it works

A badge is a `container` with a high `border` radius (999 creates a pill
shape by ensuring the radius exceeds the container height) and a coloured
background. The text inside is small and tightly padded.

The `badge` helper encapsulates this as a display-only element. It returns
a container node with the given background colour, text colour, and label.

Filter chips reuse the same pill-shape concept but as clickable `button`
widgets. The `chip_style` function returns a `StyleMap` with rounded
borders. Selected chips have a solid blue fill; unselected chips have a
grey outline. Clicking toggles the tag in a `Set`.

### What it looks like

A row of small coloured pills: green "Online", blue "3 new", orange
"Deprecated". Below that, a row of rounded filter buttons. Selected filters
are solid blue; others are grey-outlined. Clicking a chip toggles its
selection state.

---

## 9. Canvas interactive shapes

Canvas handles custom visuals and hit testing. Built-in widgets handle
text editing, scrolling, and popup positioning. Complex components compose
both -- the canvas draws what iced's widget set cannot, and built-in widgets
handle what canvas cannot.

### Canvas-only: custom toggle switch

A single canvas with one interactive group. The renderer handles hover
feedback and focus ring locally. The host only sees click events.

#### Code

```gleam
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetEvent}
import plushie/node.{type Node}
import plushie/prop/length.{Px}
import plushie/prop/padding
import plushie/canvas/shape
import plushie/ui

pub type Model {
  Model(dark_mode: Bool)
}

pub fn init(_flags) {
  #(Model(dark_mode: False), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetEvent(kind: "canvas_shape_click", id: "toggle", data: data, ..) -> {
      // data contains shape_id via Dynamic
      #(Model(dark_mode: !model.dark_mode), command.None)
    }
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  let on = model.dark_mode
  let knob_x = case on {
    True -> 36.0
    False -> 16.0
  }
  let track_color = case on {
    True -> "#4CAF50"
    False -> "#ccc"
  }

  let switch_shape =
    shape.rect(0.0, 0.0, 52.0, 28.0, [shape.Fill(track_color)])
  let knob_shape =
    shape.circle(knob_x, 14.0, 10.0, [shape.Fill("#fff")])

  // Mark the group as interactive
  let interactive_group =
    shape.interactive(switch_shape, [
      shape.InteractiveId("switch"),
      shape.OnClick(True),
      shape.Cursor("pointer"),
    ])

  ui.window("main", [ui.title("Toggle Demo")], [
    ui.column("layout", [ui.padding(padding.all(24)), ui.spacing(16)], [
      ui.canvas("toggle", [
        ui.width(Px(52.0)),
        ui.height(Px(28.0)),
        // Canvas layers/shapes are passed via props
      ]),
    ]),
  ])
}
```

#### How it works

The canvas contains shapes -- here a rounded rect background and a circle
knob. The `shape.interactive` function enables click events, sets the
pointer cursor, and can provide a11y metadata. On click, the host toggles
`dark_mode` and the view re-renders with new positions and colours.

Canvas shape functions (`shape.rect`, `shape.circle`, `shape.line`,
`shape.path`, `shape.stroke`, `shape.linear_gradient`, etc.) are available
via `import plushie/canvas/shape`.

### Canvas-only: chart with clickable data points

Multiple interactive groups inside a canvas. Each bar is focusable,
has a tooltip, and announces its position in the set.

#### Code

```gleam
import gleam/float
import gleam/int
import gleam/list
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetEvent}
import plushie/node.{type Node}
import plushie/prop/length.{Px}
import plushie/prop/padding
import plushie/canvas/shape
import plushie/ui
import gleam/option.{type Option, None, Some}

pub type BarData {
  BarData(month: String, value: Float, color: String)
}

pub type Model {
  Model(selected: Option(String))
}

const data = [
  BarData(month: "Jan", value: 120.0, color: "#3498db"),
  BarData(month: "Feb", value: 85.0, color: "#2ecc71"),
  BarData(month: "Mar", value: 200.0, color: "#e74c3c"),
  BarData(month: "Apr", value: 150.0, color: "#f39c12"),
]

pub fn init(_flags) {
  #(Model(selected: None), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetEvent(kind: "canvas_shape_click", id: "chart", data: data, ..) ->
      // Extract shape_id from data via Dynamic decoding
      #(Model(selected: Some("clicked")), command.None)
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  let bar_w = 60.0
  let chart_h = 220.0
  let count = list.length(data)

  let bar_shapes =
    list.index_map(data, fn(bar, i) {
      let bar_h = bar.value
      let bar_x = int.to_float(i) *. { bar_w +. 20.0 }
      let bar_y = chart_h -. bar_h

      let bar_rect =
        shape.rect(bar_x, bar_y, bar_w, bar_h, [shape.Fill(bar.color)])
      let label =
        shape.text(bar_x +. bar_w /. 2.0, bar_y -. 12.0,
          float.to_string(bar.value),
          [shape.Fill("#666"), shape.AlignX("center")],
        )

      shape.interactive(bar_rect, [
        shape.InteractiveId("bar-" <> int.to_string(i)),
        shape.OnClick(True),
        shape.OnHover(True),
        shape.Cursor("pointer"),
        shape.Tooltip(bar.month <> ": " <> float.to_string(bar.value) <> " units"),
      ])
    })

  ui.window("main", [ui.title("Chart Demo")], [
    ui.column("layout", [ui.padding(padding.all(24)), ui.spacing(16)], list.concat([
      [ui.canvas("chart", [
        ui.width(Px(int.to_float(count) *. { bar_w +. 20.0 })),
        ui.height(Px(chart_h)),
      ])],
      case model.selected {
        Some(id) -> [ui.text("selection", "Selected: " <> id, [])]
        None -> []
      },
    ])),
  ])
}
```

#### How it works

Each bar is a rect shape marked interactive with `shape.interactive`. The
interactive options enable click and hover events, set a pointer cursor, and
provide a tooltip. Arrow keys navigate between bars.

### Canvas + built-in: custom styled text input

Stack a canvas behind a `text_input` to draw a custom background. The
canvas is purely decorative -- the text_input handles cursor, selection,
IME, and clipboard.

#### Code

```gleam
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetInput}
import plushie/node.{type Node}
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding.{Padding}
import plushie/canvas/shape
import plushie/ui

pub type Model {
  Model(query: String)
}

pub fn init(_flags) {
  #(Model(query: ""), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetInput(id: "search", value: value, ..) ->
      #(Model(query: value), command.None)
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  // Canvas shapes for custom background
  let bg_rect =
    shape.rect(0.0, 0.0, 300.0, 36.0, [shape.Fill("#f5f5f5")])
  let search_icon =
    shape.image("priv/icons/search.svg", 8.0, 8.0, 20.0, 20.0, [])

  ui.window("main", [ui.title("Search Demo")], [
    ui.column("layout", [ui.padding(padding.all(24)), ui.spacing(16)], [
      ui.stack("search_stack", [
        ui.width(Px(300.0)),
        ui.height(Px(36.0)),
      ], [
        ui.canvas("search-bg", [
          ui.width(Px(300.0)),
          ui.height(Px(36.0)),
        ]),
        ui.container("search-wrap", [
          ui.padding(Padding(top: 0.0, right: 36.0, bottom: 0.0, left: 8.0)),
          ui.height(Px(36.0)),
        ], [
          ui.text_input("search", model.query, [
            ui.style("borderless"),
            ui.width(Fill),
          ]),
        ]),
      ]),
    ]),
  ])
}
```

#### How it works

The `stack` layers the canvas background behind the text_input. The
canvas draws the rounded rect and search icon -- purely visual, no
interactive marking needed. The `text_input` sits on top in a padded
container so it clears the icon area. Clicks in the text area hit the
text_input (it is on top in the stack).

Canvas = visuals. text_input = editing and IME.

### Canvas + built-in: custom combo box

Overlay positions the dropdown. Canvas draws the trigger and option
visuals. text_input handles filtering. scrollable handles long lists.

#### Code

```gleam
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick, WidgetInput, WidgetEvent}
import plushie/node.{type Node}
import plushie/prop/border
import plushie/prop/length.{Fill, Px}
import plushie/prop/padding.{Padding}
import plushie/canvas/shape
import plushie/ui

pub type Model {
  Model(open: Bool, filter: String, selected: Option(String))
}

const options = [
  "Elixir", "Rust", "Python", "TypeScript", "Go", "Haskell", "OCaml", "Zig",
]

pub fn init(_flags) {
  #(Model(open: False, filter: "", selected: None), command.None)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "combo-trigger", ..) ->
      #(Model(..model, open: !model.open), command.None)
    WidgetInput(id: "combo-filter", value: value, ..) ->
      #(Model(..model, filter: value, open: True), command.None)
    WidgetEvent(kind: "canvas_shape_click", id: "combo-opts", data: data, ..) -> {
      // Extract selected option from data via Dynamic decoding
      #(Model(..model, selected: Some("chosen"), open: False, filter: ""), command.None)
    }
    _ -> #(model, command.None)
  }
}

pub fn view(model: Model) -> Node {
  let filtered = filtered_options(model.filter)
  let count = list.length(filtered)
  let placeholder = case model.selected {
    Some(s) -> s
    None -> "Select..."
  }

  let dropdown_children = case model.open && count > 0 {
    True -> [
      ui.container("combo-dropdown", [
        ui.width(Px(250.0)),
        ui.background("#fff"),
        ui.border(
          border.new()
          |> border.color("#ddd")
          |> border.width(1.0)
          |> border.radius(8.0)
        ),
        ui.clip(True),
      ], [
        ui.scrollable("combo-scroll", [
          ui.height(Px(float.min(int.to_float(count) *. 32.0, 200.0))),
        ], [
          ui.canvas("combo-opts", [
            ui.width(Px(250.0)),
            ui.height(Px(int.to_float(count) *. 32.0)),
          ]),
        ]),
      ]),
    ]
    False -> []
  }

  ui.window("main", [ui.title("Combo Demo")], [
    ui.column("layout", [
      ui.padding(padding.all(24)),
      ui.spacing(16),
      ui.width(Fill),
    ], list.concat([
      [
        ui.text("label", "Language:", [ui.font_size(14.0)]),
        ui.overlay("combo", [], [
          // Trigger
          ui.stack("combo-anchor", [
            ui.width(Px(250.0)),
            ui.height(Px(36.0)),
          ], [
            ui.canvas("combo-bg", [
              ui.width(Px(250.0)),
              ui.height(Px(36.0)),
            ]),
            ui.container("combo-input", [
              ui.padding(Padding(top: 0.0, right: 12.0, bottom: 0.0, left: 32.0)),
              ui.height(Px(36.0)),
            ], [
              ui.text_input("combo-filter", model.filter, [
                ui.placeholder(placeholder),
                ui.style("borderless"),
                ui.width(Fill),
              ]),
            ]),
          ]),
          // Dropdown
          ..dropdown_children
        ]),
      ],
      case model.selected {
        Some(s) -> [ui.text("chosen", "Selected: " <> s, [
          ui.text_color("#333"),
        ])]
        None -> []
      },
    ])),
  ])
}

fn filtered_options(filter: String) -> List(String) {
  case filter {
    "" -> options
    _ -> {
      let down = string.lowercase(filter)
      list.filter(options, fn(opt) {
        string.contains(string.lowercase(opt), down)
      })
    }
  }
}
```

#### How it works

The `overlay` widget positions the dropdown below the trigger. The
trigger is a `stack` with a canvas background (border, chevron icon)
and a borderless text_input for typing. The dropdown is a `scrollable`
wrapping a canvas whose interactive groups are the options.

Each piece does what it is good at:

- **canvas** -- custom visuals, hover feedback, hit testing
- **text_input** -- text editing, cursor, IME, clipboard
- **overlay** -- popup positioning that escapes parent bounds
- **scrollable** -- scroll container for long option lists

Closing the dropdown: on canvas shape click for an option, the host
sets `open: False` and removes the overlay content from the tree.

---

## General techniques

These patterns share a few recurring techniques worth calling out:

**Style functions over style constants.** Most patterns define a function
like `tab_style(active)` or `chip_style(selected)` that returns a
`StyleMap`. This keeps style logic next to the view, makes it easy to
derive styles from model state, and avoids module-level constants for
something that varies per render.

**`ui.space` with `width(Fill)` as a flex pusher.** Inserting a space with
`width: Fill` inside a row pushes everything after it to the right edge.
This is the flexbox `margin-left: auto` equivalent and is used in toolbars,
headers, and nav bars.

**`border.radius(999.0)` for pills.** Setting a border radius larger than the
element can possibly be tall creates a perfect pill shape. The renderer
clamps the radius to the available space.

**Transparent backgrounds for link-style buttons.** Using `#00000000` (fully
transparent) as a button background makes it look like a text link. Add a
hover state with a subtle background tint for affordance.

**`case` expressions for conditional children.** Since Gleam has no
implicit nil in trees, use `case` expressions that return either a list
with the child or an empty list, then flatten or concatenate into the
parent's children list.

**`list.flatten` for multi-element sequences.** Returning nested lists
from `list.index_map` (e.g. a button and separator pair) and then calling
`list.flatten` produces a flat child list. The breadcrumb pattern relies on
this to emit a button and separator as a pair.

**Helper functions for repeated compositions.** Extract common patterns into
functions (like `card` or `badge`) that return `Node` values. Keep them in
the same module or a dedicated view helpers module. They are plain functions
returning plain data -- no macros needed.

---

## State helpers

Plushie provides optional state management modules for common UI patterns.
None of these are required -- your model can be any type. They exist because
these patterns come up repeatedly in desktop apps and getting them right from
scratch is tedious.

All helpers are pure data structures with no processes or side effects.

### plushie/undo

Undo/redo stack for commands.

<!-- test: state_helper_undo_apply_and_revert_test -- keep this code block in sync with the test -->
```gleam
import plushie/undo
import gleam/option.{None, Some}

let stack = undo.new(model)

// Apply a command (records it for undo)
let stack = undo.apply(stack, undo.UndoCommand(
  apply: fn(m) { Model(..m, name: "Bob") },
  undo: fn(m) { Model(..m, name: "Alice") },
  label: "Rename to Bob",
  coalesce_key: None,
  coalesce_window_ms: None,
))

undo.current(stack).name
// => "Bob"

// Undo
let stack = undo.undo(stack)
undo.current(stack).name
// => "Alice"

// Redo
let stack = undo.redo(stack)
undo.current(stack).name
// => "Bob"

// Coalescing (group rapid changes, like typing)
let stack = undo.apply(stack, undo.UndoCommand(
  apply: fn(m) { Model(..m, text: m.text <> "a") },
  undo: fn(m) { Model(..m, text: string.drop_right(m.text, 1)) },
  label: "Typing",
  coalesce_key: Some("typing:editor"),
  coalesce_window_ms: Some(500),
))
// Multiple applies with the same coalesce key within the time window
// are merged into a single undo entry.
```

Use `plushie/undo` when your app has user actions that should be reversible
(text editing, form filling, drawing, configuration changes). Skip it for
apps where undo does not make sense (dashboards, monitoring).

### plushie/selection

Selection state for lists and tables.

<!-- test: state_helper_selection_multi_test, state_helper_selection_range_test -- keep this code block in sync with the test -->
```gleam
import plushie/selection
import gleam/set

let sel = selection.new(selection.Multi)

let sel = selection.select(sel, "item_1", False)
let sel = selection.select(sel, "item_3", True)

selection.selected(sel)
// => set.from_list(["item_1", "item_3"])

let sel = selection.toggle(sel, "item_1")
selection.selected(sel)
// => set.from_list(["item_3"])

// Range select (shift-click pattern)
let sel = selection.new_with_order(
  selection.Range,
  ["a", "b", "c", "d", "e"],
)
let sel = selection.select(sel, "b", False)
let sel = selection.range_select(sel, "d")
selection.selected(sel)
// => set.from_list(["b", "c", "d"])
```

Use `plushie/selection` when you have selectable lists, tables, or tree
views. It handles single, multi (ctrl-click), and range (shift-click)
selection modes correctly. Skip it for simple cases where a single
`selected_id` in your model is sufficient.

### plushie/route

Client-side routing for multi-view apps.

<!-- test: state_helper_route_push_and_pop_test -- keep this code block in sync with the test -->
```gleam
import plushie/route
import gleam/dict

let r = route.new("/dashboard")

let r = route.push_with_params(r, "/settings", dict.from_list([
  #("tab", "general"),
]))
route.current(r)
// => "/settings"
route.params(r)
// => dict.from_list([#("tab", "general")])

let r = route.pop(r)
route.current(r)
// => "/dashboard"
```

Routes are just data. There is no URL bar, no browser history API. This
is for apps that have multiple "screens" and want back/forward navigation
with history tracking. Use it for apps with distinct screens (settings,
detail views, wizards). Skip it for single-screen apps.

### plushie/data

Query pipeline for in-memory record collections.

<!-- test: state_helper_data_query_filter_test -- keep this code block in sync with the test -->
```gleam
import plushie/data
import gleam/string

let records = [
  User(id: 1, name: "Alice", role: "admin", active: True),
  User(id: 2, name: "Bob", role: "user", active: False),
  User(id: 3, name: "Carol", role: "admin", active: True),
]

data.query(records, [
  data.Filter(fn(r) { r.active }),
  data.Sort(direction: data.Asc, key: fn(r) { r.name }),
  data.Page(1),
  data.PageSize(10),
])
// => QueryResult(
//   entries: [User(id: 1, ..), User(id: 3, ..)],
//   total: 2,
//   page: 1,
//   page_size: 10,
//   groups: dict.new(),
// )
```

Use `plushie/data` when you have tabular data that needs filtering, sorting,
grouping, or pagination in the UI. It is a query pipeline over lists, not a
database -- keep data sets small enough to fit in memory.

### General philosophy

These helpers share a few properties:

- **Pure data.** No actors, no processes, no side effects. They are
  just types and functions.
- **Optional.** You can use zero, one, or all of them. They do not depend
  on each other.
- **Composable.** They work with your model, not instead of it. Embed them
  as fields in your model type.

```gleam
import plushie/undo
import plushie/selection
import plushie/route

pub type Model {
  Model(
    undo: undo.UndoStack(InnerModel),
    selection: selection.Selection,
    route: route.Route,
    todos: List(Todo),
  )
}
```
