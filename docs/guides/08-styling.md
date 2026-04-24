# Styling

With the layout in place, it is time to make the pad look good. Plushie
has a layered styling system: themes set the overall palette, per-widget
style presets override individual elements, and prop modules like
`plushie/prop/border` and `plushie/prop/shadow` handle the details.

This chapter covers the parts you will use most often. The full theme
list, shade override keys, and every prop option are in the
[Themes and Styling reference](../reference/themes-and-styling.md).

## Themes

Every window has a `WindowTheme` opt that sets the colour palette for
all widgets inside it. Plushie ships with a set of built-in themes:

```gleam
import plushie/prop/theme.{Dark}
import plushie/ui
import plushie/widget/window

ui.window("main", [window.Title("Plushie Pad"), window.WindowTheme(Dark)], [
  // all widgets inside use the dark palette
])
```

Some popular options: `Light`, `Dark`, `Nord`, `Dracula`,
`CatppuccinMocha`, `TokyoNight`, `GruvboxDark`, `Oxocarbon`. See the
`Theme` type in `plushie/prop/theme` for the complete list.

Use `SystemTheme` to follow the operating system's light / dark
preference:

```gleam
import plushie/prop/theme.{SystemTheme}

ui.window("main", [window.Title("Plushie Pad"), window.WindowTheme(SystemTheme)], [
  // follows OS theme
])
```

Try a few variants on the pad's window to see how the entire UI adapts.
Buttons, text inputs, scrollbars, and the editor all respond.

## Custom themes

`theme.custom(name, palette)` generates a full palette from a handful of
seed colours. `palette` is a `Dict(String, PropValue)` mapping seed keys
to encoded hex strings:

```gleam
import gleam/dict
import plushie/prop/theme

let my_theme =
  theme.custom(
    "My Brand",
    dict.from_list([
      theme.primary("#3b82f6"),
      theme.danger("#ef4444"),
      theme.background("#1a1a2e"),
      theme.text("#e0e0e8"),
    ]),
  )

ui.window("main", [window.WindowTheme(my_theme)], [/* ... */])
```

Add a `"base"` key to extend a built-in theme, then override only the
colours you want to change:

```gleam
theme.custom(
  "Nord+",
  dict.from_list([
    theme.base(theme.Nord),
    theme.primary("#88c0d0"),
  ]),
)
```

The helpers return palette dict entries. For less common shade override
keys, use raw `#(String, PropValue)` pairs.

For fine-grained control, the theme system supports shade overrides
(keys like `primary_strong`, `background_weakest`, `danger_base_text`)
that target specific shade levels. See the
[Themes and Styling reference](../reference/themes-and-styling.md) for
the full key list. Unknown keys panic at construction time, which
catches typos early.

## Subtree theming

The `themer` widget applies a different theme to a subtree without
affecting the rest of the window:

```gleam
import plushie/prop/theme.{Dark}
import plushie/widget/themer

themer.new("dark-section", Dark)
|> themer.push(
  ui.container("sidebar", [container.Padding(padding.all(12.0))], [
    ui.text("dark-text", "This section is dark", []),
  ]),
)
|> themer.build()
```

This is useful for dark sidebars in a light app, brand-specific
sections, or any case where part of the UI needs a different palette.
`themer` takes exactly one child and changes the theme context for
everything inside it. You can give the preview pane a different theme
from the rest of the pad so experiments render in a distinct palette.

## Per-widget styling with StyleMap

Themes set the baseline palette. `StyleMap` overrides the appearance of
individual widget instances. Style-aware widgets expose a `Custom`
variant on their style sum type that takes a `StyleMap`:

```gleam
import plushie/prop/style_map
import plushie/ui
import plushie/widget/button.{Custom}

let save_style =
  style_map.new()
  |> style_map.background("#3b82f6")
  |> style_map.text_color("#ffffff")
  |> style_map.hovered(style_map.new() |> style_map.background("#2563eb"))
  |> style_map.pressed(style_map.new() |> style_map.background("#1d4ed8"))

ui.button("save", "Save", [button.Style(Custom(save_style))])
```

Colour setters on `StyleMap` (`background`, `text_color`, `base`)
accept raw hex strings today, not `Color` values. When you already have
a `Color` in hand, call `color.to_hex(c)` to convert it before passing
it in. The `border` and `shadow` setters take encoded `PropValue`, so
run the typed builder through `border.to_prop_value` or
`shadow.to_prop_value` first.

### Status overrides

`hovered`, `pressed`, `disabled`, and `focused` each take another
`StyleMap` whose fields override the base while the widget is in that
state. Only the fields you set are overridden; the rest inherit from
the base style. The `save_style` example above uses `hovered` and
`pressed` overrides to change just the background colour.

### Named presets

Most style-aware widgets expose a style sum type with preset variants
alongside the `Custom(StyleMap)` escape hatch. For buttons the presets
are `Primary`, `Secondary`, `Success`, `Warning`, `Danger`, `TextStyle`,
`BackgroundStyle`, and `Subtle`:

```gleam
import plushie/widget/button.{Primary, Subtle}

ui.button("save", "Save", [button.Style(Primary)])
ui.button("cancel", "Cancel", [button.Style(Subtle)])
```

Presets encode to the renderer's built-in preset names, so they follow
whichever theme is active. `container.Style` takes a preset name
string instead (`"rounded_box"`, `"bordered_box"`, `"dark"`, and so on);
see the [Themes and Styling reference](../reference/themes-and-styling.md)
for the full list.

## Borders and shadows

`plushie/prop/border` and `plushie/prop/shadow` build specifications
used by containers and style maps. Both follow the same builder
pattern: construct with `new()`, chain setters, pass directly to a
container opt or encode with `to_prop_value` for a style map:

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/prop/padding
import plushie/prop/shadow
import plushie/widget/container

let assert Ok(border_color) = color.from_hex("#e5e7eb")
let assert Ok(shadow_color) = color.from_hex("#0000001a")

let card_border =
  border.new()
  |> border.color(border_color)
  |> border.width(1.0)
  |> border.radius(8.0)

let card_shadow =
  shadow.new()
  |> shadow.color(shadow_color)
  |> shadow.offset(0.0, 2.0)
  |> shadow.blur_radius(4.0)

ui.container(
  "card",
  [
    container.Border(card_border),
    container.Shadow(card_shadow),
    container.Padding(padding.all(16.0)),
  ],
  [ui.text("content", "Card content", [])],
)
```

`color.from_hex` validates its input and returns `Result(Color, Nil)`,
so the `let assert Ok(c) = color.from_hex(...)` pattern is the norm
for hex literals known-good at compile time. For runtime input,
pattern-match on the result.

Borders support per-corner radius via `border.radius_corners(tl, tr,
br, bl)`.

## Gradients

`plushie/prop/gradient` builds linear gradients for container
backgrounds and style map backgrounds. Two constructors cover the
common shapes:

```gleam
import plushie/prop/color
import plushie/prop/gradient

let assert Ok(start) = color.from_hex("#3b82f6")
let assert Ok(end) = color.from_hex("#1d4ed8")

let header_gradient =
  gradient.linear_from_angle(
    135.0,
    [gradient.stop(0.0, start), gradient.stop(1.0, end)],
  )
```

Use the gradient in a container via `container.BgGradient(header_gradient)`
or in a style map via `style_map.gradient_background(sm, header_gradient)`.

## Design tokens

Plushie does not ship a design system framework. Gleam's module system
is enough: define a helper module with functions that return consistent
values, then import it where you need them. A `plushie_pad/design`
module works well:

```gleam
import plushie/prop/border
import plushie/prop/color.{type Color}
import plushie/prop/style_map.{type StyleMap}

pub fn spacing_xs() -> Float { 4.0 }
pub fn spacing_sm() -> Float { 8.0 }
pub fn spacing_md() -> Float { 16.0 }
pub fn spacing_lg() -> Float { 24.0 }

pub fn font_sm() -> Float { 12.0 }
pub fn font_md() -> Float { 14.0 }
pub fn font_lg() -> Float { 18.0 }

pub fn color_accent() -> Color {
  let assert Ok(c) = color.from_hex("#3b82f6")
  c
}

pub fn color_border() -> Color {
  let assert Ok(c) = color.from_hex("#e5e7eb")
  c
}

pub fn card_style() -> StyleMap {
  style_map.new()
  |> style_map.background("#ffffff")
  |> style_map.border(
    border.new()
    |> border.color(color_border())
    |> border.width(1.0)
    |> border.radius(8.0)
    |> border.to_prop_value(),
  )
}
```

Then use the helpers in your views:

```gleam
import plushie_pad/design

ui.column("body", [column.Spacing(design.spacing_md())], [
  ui.text("title", "Experiments", [text.Size(design.font_lg())]),
])
```

This is ordinary Gleam module design, no Plushie magic. As the pad
grows, a design module prevents gradual drift toward inconsistent
spacing, sizes, and colours.

## Fonts

`plushie/prop/font` supports a system default proportional font, a
system monospace font, and specific family names loaded via app
settings. Font files declared on the `app.Settings` passed to
`plushie.start` are available by family name in any widget's `font`
opt.

## Applying it: the styled pad

Put it all together. Set a dark theme on the main window, surround the
sidebar with a border for visual separation, and style buttons with
presets to highlight the active file and quiet the inactive ones:

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/prop/theme.{Dark}
import plushie/widget/button.{Primary, Subtle}
import plushie/widget/container
import plushie/widget/window

let assert Ok(divider) = color.from_hex("#333333")

let sidebar_border =
  border.new()
  |> border.color(divider)
  |> border.width(1.0)

ui.window("main", [window.Title("Plushie Pad"), window.WindowTheme(Dark)], [
  ui.row("body", [], [
    ui.container("sidebar-wrap", [container.Border(sidebar_border)], [
      file_list(model),
    ]),
    editor_pane(model),
    preview_pane(model),
  ]),
  ui.row("toolbar", [], [
    file_button(model, "notes.md"),
    file_button(model, "todo.md"),
    ui.button("save", "Save", [button.Style(Primary)]),
  ]),
])

fn file_button(model: Model, name: String) -> Node {
  let preset = case name == model.active_file {
    True -> Primary
    False -> Subtle
  }
  ui.button("file-" <> name, name, [button.Style(preset)])
}
```

The dark theme transforms the entire pad. The primary save button
stands out. The sidebar border creates visual separation. Small
adjustments, dramatic result.

## Verify it

Test that the styled pad still works end-to-end:

```gleam
import plushie/testing

pub fn styled_pad_test() {
  let session = testing.start(my_app, [])
  testing.click(session, "#save")
  testing.assert_text(session, "#preview/greeting", "Hello, Plushie!")
  testing.assert_not_exists(session, "#error")
}
```

Styling is visual, but this confirms the theme, borders, and style
changes did not break the compilation and preview flow.

## Try it

Write a styling experiment in your pad:

- Build a card: container with a border, shadow, rounded corners, and
  padding.
- Try `StyleMap` with status overrides: a button that changes colour on
  hover and press.
- Apply different themes to nested `themer` widgets to see how palettes
  compose.
- Build a design token module for your experiments with a spacing
  scale, a palette, and reusable styles.

In the next chapter, we will add animations and transitions to make
the pad feel alive.

---

Next: [Animation and Transitions](09-animation.md)
