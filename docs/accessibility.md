# Accessibility

Plushie provides built-in accessibility support via
[accesskit](https://github.com/AccessKit/accesskit), a cross-platform
accessibility toolkit. The default renderer build includes accessibility,
activating native platform APIs automatically: VoiceOver on macOS,
AT-SPI/Orca on Linux, and UI Automation/NVDA/JAWS on Windows.

Screen reader users, keyboard-only users, and other AT users interact with
the same widgets and receive the same events as mouse users. No special
event handling is needed in your `update` -- AT actions produce the same
`WidgetClick(id: id, ..)`, `WidgetInput(id: id, value: val, ..)`, etc. events as direct interaction.


## How it works

Iced's fork (`v0.14.0-a11y-accesskit` branch) provides native accessibility
support. Three pieces work together:

1. **iced widgets report `Accessible` metadata** -- each widget implements
   the `Accessible` trait via iced's `operate()` mechanism. Widgets declare
   their role, label, and state to the accessibility system automatically.

2. **TreeBuilder assembles the accesskit tree** -- `iced_winit::a11y`
   contains a `TreeBuilder` that walks the widget tree during `operate()`,
   collecting `Accessible` metadata and building an accesskit `TreeUpdate`.
   This happens natively inside iced -- plushie does not build the tree.

3. **AT actions become native iced events** -- when an AT triggers an action
   (e.g. a screen reader user activates a button), iced translates it to a
   native event. The renderer maps it to a standard plushie event and sends it
   to Gleam over the wire protocol.

```
Host (Gleam)              Renderer (iced)               Platform AT
   |                         |                              |
   |--- UI tree (a11y) ----->|                              |
   |                         |-- operate() + TreeBuilder -->|
   |                         |-- TreeUpdate --------------->|
   |                         |                              |
   |                         |<-- AT Action (Click) --------|
   |                         |   (native iced event)        |
   |<-- WidgetClick ---------|                              |
```

### plushie's role

plushie does not build its own accesskit tree. Iced handles tree building,
AT actions, and platform integration natively. plushie's contribution is the
`A11yOverride` wrapper widget (`a11y_widget.rs` in plushie) that
intercepts `operate()` to apply Gleam-side overrides from the `a11y` prop.

This means:

- **Standard widgets** get correct accessibility semantics automatically
  from iced's own `Accessible` implementations.
- **Extension widgets** get free a11y support without any code -- they are
  already iced `Element`s that participate in `operate()`.
- **The `a11y` prop** lets Gleam override or augment the inferred semantics
  when auto-inference is insufficient.
- **`HiddenInterceptor`** is a companion wrapper that excludes widgets from
  the AT tree when `hidden: True` is set.

Accessibility is compiled unconditionally -- there are no feature flags to
toggle it.


## Auto-inference

Most widgets get correct accessibility semantics without any annotation.
Iced automatically reports roles, labels, and state from widget types and
existing props via the `Accessible` trait.

### Role mapping

Every widget type maps to an accesskit role:

| Widget type | Role | Notes |
|---|---|---|
| `button` | Button | |
| `text`, `rich_text` | Label | |
| `text_input` | TextInput | |
| `text_editor` | MultilineTextInput | |
| `checkbox` | CheckBox | |
| `toggler` | Switch | |
| `radio` | RadioButton | |
| `slider`, `vertical_slider` | Slider | |
| `pick_list`, `combo_box` | ComboBox | |
| `progress_bar` | ProgressIndicator | |
| `scrollable` | ScrollView | |
| `container`, `column`, `row`, `stack` | GenericContainer | Also: `keyed_column`, `grid`, `float`, `pin`, `responsive`, `space`, `themer`, `mouse_area`, `sensor`, `overlay` |
| `window` | Window | |
| `image`, `svg`, `qr_code` | Image | |
| `canvas` | Canvas | |
| `table` | Table | |
| `tooltip` | Tooltip | |
| `markdown` | Document | |
| `pane_grid` | Group | |
| `rule` | Splitter | |

### Labels

Labels are the accessible name announced by screen readers. They are
extracted from the prop that makes sense for each widget type:

| Widget type | Label source |
|---|---|
| `button`, `checkbox`, `toggler`, `radio` | `label` prop |
| `text`, `rich_text` | `content` prop |
| `image`, `svg` | `alt` prop |
| `text_input` | `placeholder` prop (as description, not label) |

If a widget has no auto-inferred label and no `a11y` label override, the
screen reader sees the role with no name. This is fine for structural
containers but not for interactive widgets -- always give buttons, inputs,
and toggles either a visible label or an `a11y` label.

### State

Widget state is extracted from existing props automatically:

| State | Source | Widgets |
|---|---|---|
| Disabled | `disabled: True` | Any widget |
| Toggled | `checked` prop | `checkbox` |
| Toggled | `is_toggled` prop | `toggler` |
| Toggled | `selected` prop (boolean) | `radio` |
| Numeric value | `value` prop (number) | `slider`, `progress_bar` |
| Min/max | `range` prop (`[min, max]`) | `slider`, `progress_bar` |
| String value | `value` prop (string) | `text_input` |
| Selected item | `selected` prop (string) | `pick_list` |


## The a11y prop

For cases where auto-inference is insufficient, every widget accepts an
`a11y` prop -- built with the `plushie/prop/a11y` module's builder functions.

### Fields

| Field | Builder function | Description |
|---|---|---|
| `role` | `a11y.role(r)` | Override the inferred role (see [available roles](#available-roles)) |
| `label` | `a11y.label(s)` | Accessible name (what the screen reader announces) |
| `description` | `a11y.description(s)` | Longer description (secondary announcement) |
| `live` | `a11y.live(s)` | Live region -- AT announces content changes (`"off"`, `"polite"`, `"assertive"`) |
| `hidden` | `a11y.hidden(b)` | Exclude from accessibility tree entirely |
| `expanded` | `a11y.expanded(b)` | Expanded/collapsed state (menus, disclosures) |
| `required` | `a11y.required(b)` | Mark form field as required |
| `level` | `a11y.level(n)` | Heading level (1-6, only meaningful with `Heading` role) |
| `busy` | `a11y.busy(b)` | Loading/processing state (AT announces when done) |
| `invalid` | `a11y.invalid(b)` | Form validation failure |
| `modal` | `a11y.modal(b)` | Dialog is modal (AT restricts navigation to this container) |
| `read_only` | `a11y.read_only(b)` | Can be read but not edited |
| `mnemonic` | `a11y.mnemonic(s)` | Alt+letter keyboard shortcut (single character) |
| `toggled` | `a11y.toggled(b)` | Toggled/checked state (for custom toggle widgets) |
| `selected` | `a11y.selected(b)` | Selected state (for custom selectable widgets) |
| `value` | `a11y.value(s)` | Current value as a string (for custom value-displaying widgets) |
| `orientation` | `a11y.orientation(o)` | Orientation hint for AT navigation (`Horizontal` or `Vertical`) |
| `labelled_by` | `a11y.labelled_by(id)` | ID of the widget that labels this one |
| `described_by` | `a11y.described_by(id)` | ID of the widget that describes this one |
| `error_message` | `a11y.error_message(id)` | ID of the widget showing the error message |
| `disabled` | `a11y.disabled(b)` | Override disabled state for AT |
| `position_in_set` | `a11y.position_in_set(n)` | 1-based position in a set ("Item 3 of 7") |
| `size_of_set` | `a11y.size_of_set(n)` | Total items in the set |
| `has_popup` | `a11y.has_popup(p)` | Popup type: `ListboxPopup`, `MenuPopup`, `DialogPopup`, `TreePopup`, `GridPopup` |

The type is defined in `plushie/prop/a11y`. All fields are optional -- start
with `a11y.new()` and pipe through only the setters you need.

### Using the a11y prop

With `plushie/ui` (convenience builder):

<!-- test: a11y_heading_level_1_ui_builder_test, a11y_icon_button_label_test, a11y_landmark_region_test -- keep this code block in sync with the test -->
```gleam
import plushie/ui
import plushie/prop/a11y
import plushie/prop/padding

// Headings
ui.text("title", "Welcome to MyApp", [
  ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1)),
])
ui.text("settings_heading", "Settings", [
  ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2)),
])

// Icon buttons that need a label for screen readers
ui.button("close", "X", [
  ui.a11y(a11y.new() |> a11y.label("Close dialog")),
])

// Landmark regions
ui.container("search_results", [
  ui.a11y(a11y.new() |> a11y.role(a11y.Region) |> a11y.label("Search results")),
], [
  // ...
])

// Live regions -- AT announces changes automatically
ui.text("save_status", int.to_string(model.saved_count) <> " items saved", [
  ui.a11y(a11y.new() |> a11y.live("polite")),
])

// Decorative elements hidden from AT
ui.rule("divider", [ui.a11y(a11y.new() |> a11y.hidden(True))])
ui.image("divider", "/images/decorative-line.png", [
  ui.a11y(a11y.new() |> a11y.hidden(True)),
])

// Disclosure / expandable sections
ui.container("details", [
  ui.a11y(
    a11y.new()
    |> a11y.expanded(model.expanded)
    |> a11y.role(a11y.Group)
    |> a11y.label("Advanced options"),
  ),
], case model.expanded {
  True -> [/* ... */]
  False -> []
})

// Required form fields
ui.text_input("email", model.email, [
  ui.a11y(a11y.new() |> a11y.required(True) |> a11y.label("Email address")),
])
```

With the typed widget builder API (`plushie/widget/*`):

<!-- test: a11y_button_widget_builder_test, a11y_text_widget_builder_test, a11y_text_input_widget_builder_test -- keep this code block in sync with the test -->
```gleam
import plushie/widget/button
import plushie/widget/text
import plushie/widget/text_input
import plushie/prop/a11y

button.new("close", "X")
|> button.a11y(a11y.new() |> a11y.label("Close dialog"))
|> button.build()

text.new("title", "Welcome")
|> text.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1))
|> text.build()

text_input.new("email", model.email)
|> text_input.a11y(a11y.new() |> a11y.required(True) |> a11y.label("Email address"))
|> text_input.build()
```

### Available roles

The `role` function accepts a `Role` constructor from `plushie/prop/a11y`.
Use them to override the auto-inferred role when a widget is semantically
different from its type (e.g. a `text` that's actually a heading, or a
`container` that's a navigation landmark).

**Interactive:**
`Button`, `CheckBox`, `ComboBox`, `Link`, `MenuItem`,
`RadioButton`, `Slider`, `Switch`, `Tab`, `TextInput`,
`MultilineTextInput`, `TreeItem`

**Structure:**
`Group`, `Heading`, `Label`, `List`, `ListItem`, `Row`,
`Cell`, `ColumnHeader`, `Table`, `Tree`

**Landmarks:**
`Navigation`, `Region`, `Search`

**Status:**
`Alert`, `AlertDialog`, `Dialog`, `Status`, `Meter`,
`ProgressIndicator`

**Other:**
`Document`, `Image`, `Menu`, `MenuBar`, `ScrollView`,
`Separator`, `TabList`, `TabPanel`, `Toolbar`, `Tooltip`,
`Window`

Unknown role values are accepted but mapped to `Unknown`.


## Patterns and best practices

### Every interactive widget needs a name

Screen readers announce a widget's role and its label. A button with no
label is announced as just "button" -- useless. Make sure every button,
input, checkbox, and toggle has either:

- A visible label prop that auto-inference picks up, or
- An `a11y` label override

```gleam
// Good -- label is auto-inferred from the button's label prop
ui.button_("save", "Save document")

// Good -- terse label with explicit a11y override for clarity
ui.button("close", "X", [
  ui.a11y(a11y.new() |> a11y.label("Close dialog")),
])

// Bad -- screen reader just announces "button" with no name
ui.button_("do_thing", "")
```

### Use headings to create structure

Screen reader users navigate by headings. Use the `a11y` prop to mark
section titles:

<!-- test: a11y_heading_structure_test -- keep this code block in sync with the test -->
```gleam
fn view(model: Model) -> Node {
  ui.window("main", [ui.title("MyApp")], [
    ui.column("content", [], [
      ui.text("page_title", "Dashboard", [
        ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1)),
      ]),

      ui.text("h_recent", "Recent activity", [
        ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2)),
      ]),
      // ... activity list ...

      ui.text("h_actions", "Quick actions", [
        ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2)),
      ]),
      // ... action buttons ...
    ]),
  ])
}
```

### Use landmarks for page regions

Landmarks let screen reader users jump between major sections. Wrap
significant regions in containers with landmark roles:

<!-- test: a11y_navigation_landmark_test, a11y_search_landmark_test -- keep this code block in sync with the test -->
```gleam
ui.column("layout", [], [
  ui.container("nav", [
    ui.a11y(a11y.new() |> a11y.role(a11y.Navigation) |> a11y.label("Main navigation")),
  ], [
    ui.row("nav_buttons", [], [
      ui.button_("home", "Home"),
      ui.button_("settings", "Settings"),
      ui.button_("help", "Help"),
    ]),
  ]),

  ui.container("main_content", [
    ui.a11y(a11y.new() |> a11y.role(a11y.Region) |> a11y.label("Main content")),
  ], [
    // ...
  ]),

  ui.container("search_area", [
    ui.a11y(a11y.new() |> a11y.role(a11y.Search) |> a11y.label("Search")),
  ], [
    ui.text_input("query", model.query, [ui.placeholder("Search...")]),
    ui.button_("go", "Search"),
  ]),
])
```

### Live regions for dynamic content

When content changes and you want the screen reader to announce it
without the user navigating to it, use live regions:

- `"polite"` -- announced after the current speech finishes (status
  messages, save confirmations, non-urgent updates)
- `"assertive"` -- interrupts current speech (errors, urgent alerts)

<!-- test: a11y_live_polite_test, a11y_live_assertive_alert_test -- keep this code block in sync with the test -->
```gleam
// Status bar that announces changes
ui.text("status", model.status_message, [
  ui.a11y(a11y.new() |> a11y.live("polite")),
])

// Error message that interrupts (use list spreading for conditional nodes)
..case model.error {
  Some(err) -> [
    ui.text("error", err, [
      ui.a11y(a11y.new() |> a11y.live("assertive") |> a11y.role(a11y.Alert)),
    ]),
  ]
  None -> []
}

// Counter value announced on change
ui.text("counter", "Count: " <> int.to_string(model.count), [
  ui.a11y(a11y.new() |> a11y.live("polite")),
])
```

**Tip:** Only mark the element that changes as live, not its parent
container. Marking a large container as live causes the entire container's
text to be re-announced on every change.

### Forms

Label your inputs, mark required fields, and provide clear error feedback:

```gleam
ui.column("form", [ui.spacing(12)], [
  ui.text("form_heading", "Create account", [
    ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1)),
  ]),

  ui.column("username_group", [ui.spacing(4)], [
    ui.text_("username_label", "Username"),
    ui.text_input("username", model.username, [
      ui.a11y(a11y.new() |> a11y.required(True) |> a11y.label("Username")),
    ]),
  ]),

  ui.column("email_group", [ui.spacing(4)], [
    ui.text_("email_label", "Email"),
    ui.text_input("email", model.email, [
      ui.a11y(a11y.new() |> a11y.required(True) |> a11y.label("Email address")),
    ]),
    ..case model.email_error {
      Some(err) -> [
        ui.text("email_error", err, [
          ui.a11y(a11y.new() |> a11y.live("assertive") |> a11y.role(a11y.Alert)),
        ]),
      ]
      None -> []
    }
  ]),

  ui.button_("submit", "Create account"),
])
```

**Why the explicit `a11y.label("Username")` when there's a visible
`text_("username_label", "Username")` above?** Because plushie doesn't
automatically associate a text label with the input below it. The visible
text and the input are separate widgets in the tree. The `a11y` label
connects them for AT users.

#### Cross-widget relationships

Instead of duplicating label text in the `a11y` prop, you can point to
another widget by ID using `labelled_by`, `described_by`, and
`error_message`. The renderer resolves these to accesskit node
references so the screen reader follows the relationship automatically.

<!-- test: a11y_labelled_by_test -- keep this code block in sync with the test -->
```gleam
ui.column("form", [ui.spacing(12)], [
  ui.text("form_heading", "Create account", [
    ui.a11y(a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1)),
  ]),

  ui.column("email_group", [ui.spacing(4)], [
    ui.text_("email-label", "Email"),
    ui.text_("email-help", "We'll send a confirmation link"),
    ui.text_input("email", model.email, [
      ui.a11y(
        a11y.new()
        |> a11y.labelled_by("email-label")
        |> a11y.described_by("email-help")
        |> a11y.error_message("email-error"),
      ),
    ]),
    ..case model.email_error {
      Some(err) -> [
        ui.text("email-error", err, [
          ui.a11y(a11y.new() |> a11y.role(a11y.Alert) |> a11y.live("assertive")),
        ]),
      ]
      None -> []
    }
  ]),

  ui.button_("submit", "Create account"),
])
```

When the user focuses the email input, the screen reader announces the
label text from the `email-label` widget and the description from
`email-help`. If the field is invalid, it also announces the error text
from `email-error`.

Use `labelled_by` instead of `label` when a visible text widget already
provides the label -- it avoids duplicating the string and keeps the
label in sync if you change the visible text.

### Hiding decorative content

Decorative elements that add no information should be hidden from AT:

<!-- test: a11y_hidden_rule_test, a11y_decorative_image_hidden_test, a11y_space_hidden_test -- keep this code block in sync with the test -->
```gleam
// Decorative dividers
ui.rule("divider", [ui.a11y(a11y.new() |> a11y.hidden(True))])

// Decorative images
ui.image("hero", "/images/banner.png", [
  ui.a11y(a11y.new() |> a11y.hidden(True)),
])

// Spacing elements
ui.space("gap", [ui.a11y(a11y.new() |> a11y.hidden(True))])
```

Don't hide functional elements. If an image conveys information, give it
an `alt` prop instead:

```gleam
ui.image("status_icon", icon_path, [ui.alt("Status: online")])
```

### Canvas widgets

Canvas draws arbitrary shapes -- accesskit can't infer anything from raw
geometry. Always provide alternative text:

<!-- test: a11y_canvas_with_role_and_label_test -- keep this code block in sync with the test -->
```gleam
import plushie/widget/canvas
import plushie/prop/length.{Fill}

// Static chart -- describe the content
canvas.new("chart", Fill, Fill)
|> canvas.layer("data", chart_shapes)
|> canvas.a11y(
  a11y.new()
  |> a11y.role(a11y.Image)
  |> a11y.label("Sales chart: Q1 revenue up 15%, Q2 flat"),
)
|> canvas.build()

// Interactive canvas -- describe the interaction model
canvas.new("drawing", Fill, Fill)
|> canvas.layer("shapes", shapes)
|> canvas.a11y(
  a11y.new()
  |> a11y.role(a11y.Image)
  |> a11y.label("Drawing canvas, " <> int.to_string(list.length(shapes)) <> " shapes"),
)
|> canvas.build()
```

For complex interactive canvases, consider whether the canvas is the right
choice for AT users, or whether an alternative text-based representation
would work better.

### Interactive canvas shapes

When a canvas contains shapes with the `interactive` field, each
shape becomes a separate accessible node. The canvas widget itself
is the container; individual shapes are focusable children. Tab and
Arrow keys navigate between shapes. Enter/Space activates the focused
shape.

This is how you build accessible custom widgets from canvas
primitives. Without interactive shapes, a canvas is a single opaque
"image" node to screen readers.

```gleam
import plushie/canvas/shape
import plushie/widget/canvas
import plushie/prop/length.{Px}

canvas.new("color-picker", Px(200.0), Px(100.0))
|> canvas.layer("options",
  list.index_map(colors, fn(color, i) {
    shape.rect(0.0, int.to_float(i * 32), 200.0, 32.0)
    |> shape.fill(color.hex)
    |> shape.interactive(
      "color-" <> int.to_string(i),
      [
        shape.on_click(True),
        shape.hover_style([shape.stroke("#000"), shape.stroke_width(2.0)]),
        shape.a11y(
          a11y.new()
          |> a11y.role(a11y.RadioButton)
          |> a11y.label(color.name)
          |> a11y.selected(color == model.selected)
          |> a11y.position_in_set(i + 1)
          |> a11y.size_of_set(list.length(colors)),
        ),
      ],
    )
  }),
)
|> canvas.build()
```

Screen reader: "Red, radio button, 1 of 5, selected."

The `position_in_set` and `size_of_set` fields tell screen readers
where each shape sits in the group. Without them, the reader
announces each shape individually with no positional context.

### Custom widgets with state

When building custom widgets with canvas or other primitives, use `toggled`,
`selected`, `value`, and `orientation` to expose their state to AT users.
Without these, screen readers have no way to know the state of a custom
control drawn with raw shapes.

<!-- test: a11y_canvas_switch_toggled_test, a11y_canvas_meter_with_value_test -- keep this code block in sync with the test -->
```gleam
import plushie/widget/canvas
import plushie/prop/length.{Px}

// Custom toggle switch built with canvas
canvas.new("dark-mode-switch", Px(60.0), Px(30.0))
|> canvas.layer("switch", switch_shapes)
|> canvas.a11y(
  a11y.new()
  |> a11y.role(a11y.Switch)
  |> a11y.label("Dark mode")
  |> a11y.toggled(model.dark_mode),
)
|> canvas.build()

// Custom gauge showing percentage
canvas.new("cpu-gauge", Px(200.0), Px(40.0))
|> canvas.layer("gauge", gauge_shapes)
|> canvas.a11y(
  a11y.new()
  |> a11y.role(a11y.Meter)
  |> a11y.label("CPU usage")
  |> a11y.value(int.to_string(model.cpu_percent) <> "%")
  |> a11y.orientation(a11y.Horizontal),
)
|> canvas.build()
```

`toggled` and `selected` are booleans. Use `toggled` for on/off controls
(switches, checkboxes) and `selected` for selection state (list items, tabs).
`value` is a string describing the current value in human-readable form.
`orientation` tells AT users whether a control is horizontal or vertical,
which affects how they navigate it.

### Set position and popup hints

Use `position_in_set` / `size_of_set` when building composite widgets
from primitives (custom lists, tab bars, radio groups). Without these,
screen readers cannot announce position context like "Item 3 of 7".

```gleam
import plushie/widget/radio

// Radio group with position context
ui.container("colors", [
  ui.a11y(a11y.new() |> a11y.role(a11y.Group) |> a11y.label("Favorite color")),
], list.index_map(colors, fn(color, idx) {
  radio.new("color_" <> color, color, model.selected_color)
  |> radio.a11y(
    a11y.new()
    |> a11y.position_in_set(idx + 1)
    |> a11y.size_of_set(list.length(colors)),
  )
  |> radio.build()
}))

// Custom tab bar
ui.row("tabs", [], list.index_map(model.tabs, fn(tab, idx) {
  ui.button("tab_" <> tab.id, tab.label, [
    ui.a11y(
      a11y.new()
      |> a11y.role(a11y.Tab)
      |> a11y.selected(tab.id == model.active_tab)
      |> a11y.position_in_set(idx + 1)
      |> a11y.size_of_set(list.length(model.tabs)),
    ),
  ])
}))
```

Use `has_popup` to tell screen readers that activating a widget opens
a popup of a specific type:

<!-- test: a11y_has_popup_menu_test, a11y_has_popup_listbox_test -- keep this code block in sync with the test -->
```gleam
// Dropdown button
ui.button("menu_btn", "Options", [
  ui.a11y(
    a11y.new()
    |> a11y.has_popup(a11y.MenuPopup)
    |> a11y.expanded(model.menu_open),
  ),
])

// Combo box with listbox popup
ui.text_input("search", model.query, [
  ui.a11y(
    a11y.new()
    |> a11y.has_popup(a11y.ListboxPopup)
    |> a11y.expanded(model.suggestions_visible),
  ),
])
```

Use `disabled` to override the disabled state for AT when a widget
is visually disabled via custom styling but doesn't use the standard
`disabled` prop:

<!-- test: a11y_disabled_override_test -- keep this code block in sync with the test -->
```gleam
ui.button("submit", "Submit", [
  ui.a11y(a11y.new() |> a11y.disabled(!model.form_valid)),
])
```

### Expanded/collapsed state

For disclosure widgets, toggleable panels, and dropdown menus:

<!-- test: a11y_expanded_button_test -- keep this code block in sync with the test -->
```gleam
fn view(model: Model) -> Node {
  ui.column("layout", [], [
    ui.button(
      "toggle_details",
      case model.show_details {
        True -> "Hide details"
        False -> "Show details"
      },
      [ui.a11y(a11y.new() |> a11y.expanded(model.show_details))],
    ),

    ..case model.show_details {
      True -> [
        ui.container("details", [
          ui.a11y(a11y.new() |> a11y.role(a11y.Region) |> a11y.label("Details")),
        ], [
          // detail content
        ]),
      ]
      False -> []
    }
  ])
}
```

The `expanded` field tells AT whether the control is currently
expanded or collapsed, so screen readers can announce "Show details,
button, collapsed" or "Hide details, button, expanded".


## Widget-specific accessibility props

Some widgets accept accessibility props directly as top-level fields,
outside the `a11y` object. The Rust renderer reads these and maps them
to the appropriate accesskit node properties. They are simpler to use
than the full `a11y` builder for common cases.

### alt

An accessible label string. Used on visual content widgets where the
content itself is not textual. The renderer auto-populates the
accesskit label from this prop.

| Widget | Prop | Type |
|---|---|---|
| `image` | `alt` | `String` |
| `svg` | `alt` | `String` |
| `qr_code` | `alt` | `String` |
| `canvas` | `alt` | `String` |

<!-- test: a11y_image_alt_prop_test -- keep this code block in sync with the test -->
```gleam
import plushie/widget/svg
import plushie/widget/qr_code

ui.image("logo", "/images/logo.png", [ui.alt("Company logo")])

svg.new("icon", "/icons/search.svg")
|> svg.alt("Search")
|> svg.build()

qr_code.new("invite", invite_url)
|> qr_code.alt("QR code for invite link")
|> qr_code.build()

ui.canvas("chart", [ui.alt("Revenue chart")])
```

### label

An accessible label string for interactive widgets that don't have a
visible text label prop. The renderer auto-populates the accesskit
label from this prop.

| Widget | Prop | Type |
|---|---|---|
| `slider` | `label` | `String` |
| `vertical_slider` | `label` | `String` |
| `progress_bar` | `label` | `String` |

<!-- test: a11y_slider_label_prop_test, a11y_progress_bar_label_prop_test -- keep this code block in sync with the test -->
```gleam
ui.slider("volume", #(0.0, 100.0), model.volume, [ui.label("Volume")])
ui.vertical_slider("brightness", #(0.0, 100.0), model.brightness, [ui.label("Brightness")])
ui.progress_bar("upload", #(0.0, 100.0), model.progress, [ui.label("Upload progress")])
```

### description

An extended accessible description string. Announced as secondary
information after the label. Useful for providing additional context
that doesn't fit in a short label.

| Widget | Prop | Type |
|---|---|---|
| `image` | `description` | `String` |
| `svg` | `description` | `String` |
| `qr_code` | `description` | `String` |
| `canvas` | `description` | `String` |

<!-- test: a11y_image_description_prop_test -- keep this code block in sync with the test -->
```gleam
ui.image("photo", path, [ui.alt("Team photo"), ui.description("The engineering team at the 2025 offsite")])
ui.canvas("chart", [ui.alt("Sales chart"), ui.description("Q1 up 15%, Q2 flat, Q3 down 8%")])
```

### decorative

A boolean that hides visual content from assistive technology entirely.
Use this for images and SVGs that are purely decorative and convey no
information. This is a shorthand -- the equivalent using the `a11y`
builder would be `a11y.new() |> a11y.hidden(True)`.

| Widget | Prop | Type |
|---|---|---|
| `image` | `decorative` | `Bool` |
| `svg` | `decorative` | `Bool` |

<!-- test: a11y_image_decorative_prop_test -- keep this code block in sync with the test -->
```gleam
ui.image("divider", "/images/decorative-line.png", [ui.decorative(True)])
svg.new("flourish", "/icons/flourish.svg")
|> svg.decorative(True)
|> svg.build()
```

### Relationship to the a11y prop

These widget-specific props and the `a11y` prop are complementary. The
widget-specific props are read directly by the Rust renderer as
top-level node properties. The `a11y` prop provides the full set of
accesskit overrides via the `A11yOverride` wrapper widget.

If both are set (e.g. `alt("Photo")` and
`a11y.new() |> a11y.label("Team photo")`), the `a11y` override takes
precedence for the accesskit label since `A11yOverride` runs after the
widget's own `Accessible` implementation.


## Action handling

When an AT triggers an action, iced translates it to a native event. The
renderer maps it to a standard plushie event:

| AT action | Plushie event | Notes |
|---|---|---|
| Click | `WidgetClick(id: id, ..)` | Screen reader activate, switch press |
| SetValue | `WidgetInput(id: id, value: val, ..)` | AT sets an input value directly |
| Focus | (internal) | Focus tracking, no event emitted |
| Other | `A11yAction(id: id, action: name)` | Scroll, dismiss, etc. |

Your `update` already handles `WidgetClick` and `WidgetInput` --
AT actions produce identical events. The `A11yAction` event is
a catch-all for actions without a direct widget equivalent:

```gleam
fn update(model: Model, event: Event) {
  case event {
    A11yAction(action: "scroll_down", ..) -> scroll(model, Down)
    A11yAction(action: "dismiss", ..) -> close_dialog(model)
    A11yAction(..) -> #(model, command.none())
    // ...
  }
}
```


## Testing accessibility

The test framework provides assertions for verifying accessibility
semantics without running a screen reader.

### assert_role

Checks the inferred role for an element. This mirrors the role mapping,
so it catches mismatches between your widget type and the intended role:

```gleam
import plushie/test

pub fn heading_has_correct_role_test() {
  let session = test.start(my_app())
  test.assert_role(session, "#page_title", "heading")
}

pub fn nav_container_is_navigation_landmark_test() {
  let session = test.start(my_app())
  test.assert_role(session, "#nav", "navigation")
}
```

`assert_role` accounts for `a11y` role overrides -- if the element has
an `a11y` role set (e.g. `Heading`), that takes precedence over the
widget type.

### assert_a11y

Checks specific fields in the `a11y` prop:

```gleam
pub fn email_field_is_required_and_labelled_test() {
  let session = test.start(my_app())
  test.assert_a11y(session, "#email", [#("required", "true"), #("label", "Email address")])
}

pub fn status_has_live_region_test() {
  let session = test.start(my_app())
  test.assert_a11y(session, "#status", [#("live", "polite")])
}

pub fn decorative_image_is_hidden_test() {
  let session = test.start(my_app())
  test.assert_a11y(session, "#hero_image", [#("hidden", "true")])
}
```

Note: `assert_a11y` checks the raw `a11y` prop on the element -- it
doesn't verify auto-inferred values (those come from iced's `Accessible`
trait). If the element has no `a11y` prop set, the assertion fails with a
clear message.

### Element helpers

`plushie/test/element` provides lower-level accessors:

```gleam
import plushie/test
import plushie/test/element

pub fn element_accessors_test() {
  let session = test.start(my_app())
  let el = test.find(session, "#heading")

  // Get the raw a11y prop map
  let a11y_props = element.a11y(el)
  // => dict with "role" => "heading", "level" => 1

  // Get the inferred role (checks a11y override, then widget type)
  let role = element.inferred_role(el)
  // => "heading"
}
```

### Testing patterns

**Test the semantics, not the implementation.** Focus on what AT users
experience:

```gleam
pub fn todo_app_is_accessible_test() {
  let session = test.start(todo_app())

  // Headings provide structure
  test.assert_role(session, "#title", "heading")

  // Interactive widgets are labelled
  test.assert_a11y(session, "#new_todo", [#("label", "New todo")])

  // Status updates are announced
  test.type_text(session, "#new_todo", "Buy milk")
  test.submit(session, "#new_todo")
  test.assert_a11y(session, "#todo_count", [#("live", "polite")])

  // Form validation errors are assertive
  test.submit(session, "#new_todo")  // empty submit
  test.assert_a11y(session, "#error", [#("live", "assertive")])
}
```


## Building

Accessibility is included by default in both precompiled binaries
(`gleam run -m plushie/download`) and source builds (`gleam run -m plushie/build`).

The renderer uses an iced fork (`v0.14.0-a11y-accesskit` branch) that adds
native accessibility support. The fork is referenced via `[patch.crates-io]`
in the renderer's `Cargo.toml`. No vendored crates or local path overrides
are needed.

Accessibility support is provided by:

| Component | What it provides |
|---|---|
| plushie-iced fork | accesskit + accesskit_winit, TreeBuilder, per-window adapter management |
| `plushie-ext` | `A11yOverride` wrapper widget, `HiddenInterceptor`, AT action handling |


## Platform support

| Platform | AT | API | Status |
|---|---|---|---|
| Linux | Orca | AT-SPI2 | Supported |
| macOS | VoiceOver | NSAccessibility | Supported |
| Windows | NVDA, JAWS, Narrator | UI Automation | Supported |

All three platforms are supported via accesskit. The iced fork's a11y
integration creates platform adapters via accesskit_winit.


## Testing with a screen reader

To manually verify accessibility with a real screen reader:

### Linux (Orca)

```bash
# Build the renderer (a11y is included by default)
gleam run -m plushie/build

# Start Orca (usually Super+Alt+S, or from accessibility settings)
orca &

# Run your app
gleam run -m my_app
```

Orca should announce widget roles and labels as you navigate with Tab.
Activate buttons with Enter or Space.

### macOS (VoiceOver)

```bash
# Build the renderer (a11y is included by default)
gleam run -m plushie/build

# Toggle VoiceOver: Cmd+F5
# Run your app
gleam run -m my_app
```

Use VoiceOver keys (Ctrl+Option + arrow keys) to navigate. VoiceOver
should announce each widget's role and label.

### Windows (NVDA)

```bash
# Build the renderer (a11y is included by default)
gleam run -m plushie/build

# Start NVDA
# Run your app
gleam run -m my_app
```

Tab between widgets. NVDA should announce roles, labels, and state
(checked, disabled, expanded, etc.).


## Architecture details

For contributors working on the accessibility internals:

### iced fork (`v0.14.0-a11y-accesskit` branch)

The iced fork adds native accessibility support. Key additions:

- **`Accessible` trait** -- widgets implement this to report their role,
  label, and state to accesskit. Most built-in widgets already implement it.
- **`TreeBuilder`** in `iced_winit` -- walks the widget tree via `operate()`,
  collecting `Accessible` metadata and building an accesskit `TreeUpdate`.
- **Per-window adapters** -- each window gets an accesskit adapter connecting
  to the platform's AT layer.
- **AT action routing** -- AT actions are translated to native iced events,
  which the renderer maps to plushie wire events.

The fork is referenced via `[patch.crates-io]` in the renderer's
`Cargo.toml`.

### A11yOverride wrapper widget

`a11y_widget.rs` in plushie contains two wrapper widgets:

- **`A11yOverride`** -- wraps any iced `Element` and intercepts `operate()`
  to apply Gleam-side overrides from the `a11y` prop (role, label,
  description, live, expanded, required, level, busy, invalid, modal,
  read_only, mnemonic, toggled, selected, value, orientation, labelled_by,
  described_by, error_message).
- **`HiddenInterceptor`** -- wraps an `Element` and suppresses it from the
  accessibility tree when `hidden: True` is set.

These wrappers are applied automatically by the renderer when building the
iced widget tree from plushie's UI tree. No manual wrapping is needed from
Gleam.

### Renderer integration

When the renderer builds the iced widget tree from a plushie snapshot or
patch, it checks each node's `a11y` prop. If present (and not just
`hidden: True`), the rendered widget is wrapped in `A11yOverride`. If
`hidden: True`, it's wrapped in `HiddenInterceptor`. Nodes without an
`a11y` prop are rendered as-is -- iced's native `Accessible` trait provides
their baseline accessibility semantics.
