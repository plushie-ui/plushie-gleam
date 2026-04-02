# Styling

Plushie has a layered styling system: themes set the overall palette,
per-widget styles override individual elements, and prop modules like
`plushie/prop/border` and `plushie/prop/shadow` handle the details.

## Themes

Every window has a `theme` prop that sets the colour palette for all widgets
inside it:

```gleam
import plushie/prop/theme

ui.window_with("main", "My App", [window.Theme(theme.Dark)], [...])
```

Some popular options: `Dark`, `Light`, `Nord`, `Dracula`,
`CatppuccinMocha`, `TokyoNight`, `GruvboxDark`. Use `System` to follow
the OS light/dark preference.

## Custom themes

Create a custom theme by providing seed colours:

```gleam
let my_theme =
  theme.custom("My Theme", [
    theme.Primary("#3b82f6"),
    theme.Danger("#ef4444"),
    theme.Background("#1a1a2e"),
    theme.Text("#e0e0e8"),
  ])
```

Extend a built-in theme with `Base`:

```gleam
theme.custom("Nord+", [theme.Base(theme.Nord), theme.Primary("#88c0d0")])
```

## Subtree theming

The `themer` widget applies a different theme to its children:

```gleam
ui.themer("dark-section", [themer.Theme(theme.Dark)], [
  ui.container("sidebar", [container.Padding(12)], [
    ui.text("dark-text", "This section is dark"),
  ]),
])
```

## Per-widget styling with StyleMap

```gleam
import plushie/prop/style_map

let save_style =
  style_map.new()
  |> style_map.background("#3b82f6")
  |> style_map.text_color("#ffffff")
  |> style_map.hovered([style_map.Background("#2563eb")])
  |> style_map.pressed([style_map.Background("#1d4ed8")])

ui.button("save", "Save", [button.Style(style_map.Custom(save_style))])
```

Or use a preset atom directly:

```gleam
ui.button("save", "Save", [button.Style(style_map.Primary)])
```

## Borders and shadows

```gleam
import plushie/prop/border
import plushie/prop/shadow

let card_border =
  border.new()
  |> border.color("#e5e7eb")
  |> border.width(1)
  |> border.rounded(8)

let card_shadow =
  shadow.new()
  |> shadow.color("#0000001a")
  |> shadow.offset(0, 2)
  |> shadow.blur_radius(4)

ui.container("card", [
  container.Border(card_border),
  container.Shadow(card_shadow),
  container.Padding(16),
], [
  ui.text("content", "Card content"),
])
```

See the [Themes and Styling reference](../reference/themes-and-styling.md)
for full details.

---

Next: [Animation and Transitions](09-animation.md)
