# Themes and Styling

Plushie's visual styling works at three layers: **themes** set the
overall palette, **style maps** override individual widget appearance,
and **prop modules** (Color, Border, Shadow, Gradient) provide the
building blocks.

## Color

`plushie/prop/color`

Colors accept hex strings, named atoms, and float maps:

| Input | Example |
|---|---|
| Hex string | `"#3b82f6"` |
| Hex with alpha | `"#3b82f680"` |
| Named string | `"cornflowerblue"` |

## Theme

`plushie/prop/theme`

Every window has a `Theme` prop that sets the colour palette:

```gleam
ui.window_with("main", "App", [window.Theme(theme.Dark)], [...])
```

### Built-in themes

22 built-in themes: `Light`, `Dark`, `Nord`, `Dracula`,
`SolarizedLight`, `SolarizedDark`, `GruvboxLight`, `GruvboxDark`,
`CatppuccinLatte`, `CatppuccinFrappe`, `CatppuccinMacchiato`,
`CatppuccinMocha`, `TokyoNight`, `TokyoNightStorm`, `TokyoNightLight`,
`KanagawaWave`, `KanagawaDragon`, `KanagawaLotus`, `Moonfly`, `Nightfly`,
`Oxocarbon`, `Ferra`.

Use `System` to follow the OS light/dark preference.

### Custom themes

```gleam
let my_theme = theme.custom("My Brand", [
  theme.Primary("#3b82f6"),
  theme.Danger("#ef4444"),
  theme.Background("#1a1a2e"),
  theme.Text("#e0e0e8"),
])
```

Extend a built-in theme:

```gleam
theme.custom("Nord+", [theme.Base(theme.Nord), theme.Primary("#88c0d0")])
```

### Subtree theming

```gleam
ui.themer("sidebar-theme", [themer.Theme(theme.Dark)], [...])
```

## StyleMap

`plushie/prop/style_map`

```gleam
let style =
  style_map.new()
  |> style_map.base(style_map.Primary)
  |> style_map.background("#3b82f6")
  |> style_map.text_color("#ffffff")
  |> style_map.border(border.new() |> border.color("#2563eb") |> border.width(1))
  |> style_map.hovered([style_map.Background("#2563eb")])
  |> style_map.pressed([style_map.Background("#1d4ed8")])

ui.button("save", "Save", [button.Style(style_map.Custom(style))])
```

Or use a preset directly:

```gleam
ui.button("save", "Save", [button.Style(style_map.Primary)])
```

Common presets: `Primary`, `Secondary`, `Success`, `Danger`, `Warning`,
`Text`.

## Gradient

`plushie/prop/gradient`

```gleam
import plushie/prop/gradient

let bg = gradient.linear(90, [
  #(0.0, "#3b82f6"),
  #(1.0, "#1d4ed8"),
])

ui.container("card", [container.Background(gradient.Gradient(bg))], [...])
```

## Border

`plushie/prop/border`

```gleam
let card_border =
  border.new()
  |> border.color("#e5e7eb")
  |> border.width(1)
  |> border.rounded(8)
```

Per-corner radius:

```gleam
border.new()
|> border.rounded(border.radius(8, 8, 0, 0))
```

## Shadow

`plushie/prop/shadow`

```gleam
let card_shadow =
  shadow.new()
  |> shadow.color("#0000001a")
  |> shadow.offset(0, 4)
  |> shadow.blur_radius(8)
```

## See also

- [Styling guide](../guides/08-styling.md)
- [Built-in Widgets](built-in-widgets.md)
- [Canvas](canvas.md) - canvas fill and stroke colours
