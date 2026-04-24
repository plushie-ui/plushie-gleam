# Themes and Styling

Plushie's visual styling works at three layers: **themes** set the
overall palette, **style maps** override individual widget
appearance, and **prop modules** (`Color`, `Border`, `Shadow`,
`Gradient`) provide the building blocks.

## Color

`plushie/prop/color`

Colours appear throughout the styling system: themes, style maps,
borders, shadows, gradients, and widget props like `Color` and
`BgColor`. The `Color` type is opaque; construct values through
one of the builders:

| Constructor | Accepts | Purpose |
|---|---|---|
| `color.from_hex(String)` | `"#rgb"`, `"#rgba"`, `"#rrggbb"`, `"#rrggbbaa"` (with or without `#`) | Validated hex; returns `Result(Color, Nil)` |
| `color.from_rgb(Int, Int, Int)` | 0-255 channels | Opaque RGB |
| `color.from_rgba(Int, Int, Int, Float)` | 0-255 channels, 0.0-1.0 alpha | RGBA |
| `color.from_rgb_float(Float, Float, Float)` | 0.0-1.0 channels | Clamped float RGB |
| `color.from_rgba_float(Float, Float, Float, Float)` | 0.0-1.0 channels and alpha | Clamped float RGBA |

All constructors normalise to a canonical lowercase hex string
(`#rrggbb` or `#rrggbbaa`). `color.to_hex(c)` returns that string;
`color.to_prop_value(c)` encodes it for the wire.

Invalid hex input returns `Error(Nil)`. Integer constructors clamp
channels to 0-255 and alpha to 0.0-1.0 before assembling.

## Theme

`plushie/prop/theme`

Every window has a `WindowTheme` opt that sets the colour palette
for all widgets inside it. Themes control button colours, input
field backgrounds, scrollbar tints, text colours - everything
visual adapts to the active theme.

### Built-in themes

`Theme` is a sum type; pass a variant directly:

```gleam
import plushie/prop/theme.{Dark}
import plushie/ui
import plushie/widget/window

ui.window("main", [window.Title("App"), window.WindowTheme(Dark)], [
  // app content
])
```

| Variant | Description |
|---|---|
| `Light`, `Dark` | Default light and dark themes |
| `Nord` | [Nord](https://www.nordtheme.com/) palette |
| `Dracula` | [Dracula](https://draculatheme.com/) palette |
| `SolarizedLight`, `SolarizedDark` | [Solarized](https://ethanschoonover.com/solarized/) |
| `GruvboxLight`, `GruvboxDark` | [Gruvbox](https://github.com/morhetz/gruvbox) |
| `CatppuccinLatte`, `CatppuccinFrappe`, `CatppuccinMacchiato`, `CatppuccinMocha` | [Catppuccin](https://catppuccin.com/) |
| `TokyoNight`, `TokyoNightStorm`, `TokyoNightLight` | [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) |
| `KanagawaWave`, `KanagawaDragon`, `KanagawaLotus` | [Kanagawa](https://github.com/rebelot/kanagawa.nvim) |
| `Moonfly`, `Nightfly` | [moonfly / nightfly](https://github.com/bluz71) |
| `Oxocarbon` | [Oxocarbon](https://github.com/nyoom-engineering/oxocarbon.nvim) |
| `Ferra` | [Ferra](https://github.com/casperstorm/ferra) |
| `SystemTheme` | Follow the operating system's light / dark preference |

`theme.to_string(t)` returns the wire name for a built-in theme.
`theme.from_string(name)` parses built-in wire names and returns
`Error(Nil)` for unknown names or `"custom"`. For OS theme events,
use `theme.system_theme_from_string(name)`, which accepts only
`"light"` and `"dark"` because the renderer may also report `"none"`.

### Custom themes

`theme.custom(name, palette)` creates a custom palette from seed
colours. `palette` is a `Dict(String, PropValue)` mapping seed
keys to encoded values.

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
```

| Seed key | Purpose |
|---|---|
| `"background"` | Page / window background |
| `"text"` | Default text colour |
| `"primary"` | Primary accent (buttons, links, focus rings) |
| `"success"` | Success indicators |
| `"danger"` | Error / destructive actions |
| `"warning"` | Warning indicators |

The secondary palette is auto-derived from `"background"` and
`"text"`. Customise it through shade overrides rather than a core
seed.

`theme.custom` validates the palette keys at construction and
panics on unknown keys to catch typos early.

### Extending built-in themes

Provide a `"base"` key to start from an existing theme and
override only what you want:

```gleam
theme.custom(
  "Nord+",
  dict.from_list([
    theme.base(theme.Nord),
    theme.primary("#88c0d0"),
  ]),
)
```

The helper functions above return `#(String, PropValue)` entries for
common keys. Use raw pairs for shade override keys that do not have a
dedicated helper.

### Shade overrides

For fine-grained control, themes support shade override keys that
target specific levels in the generated palette.

**Colour families** (primary, secondary, success, warning, danger):

Each family has three base shades and matching text variants:

- `primary_base`, `primary_weak`, `primary_strong`
- `primary_base_text`, `primary_weak_text`, `primary_strong_text`

Same pattern for `secondary_*`, `success_*`, `warning_*`, `danger_*`.

**Background family** (eight levels with text variants):

- `background_base`, `background_weakest`, `background_weaker`,
  `background_weak`, `background_neutral`, `background_strong`,
  `background_stronger`, `background_strongest`
- Each has a `_text` variant (e.g. `background_base_text`).

Pass shade overrides as additional keys in the palette dict. Any
key outside the recognised set panics at construction.

### Subtree theming

The `themer` widget applies a different theme to a subtree without
affecting the rest of the window:

```gleam
import plushie/prop/theme.{Dark}
import plushie/widget/themer

themer.new("sidebar-theme", Dark)
|> themer.push(
  ui.container("body", [container.Padding(padding.all(12.0))], [
    // all widgets here use the dark theme
  ]),
)
|> themer.build()
```

`themer` takes exactly one child. See the
[Built-in Widgets reference](built-in-widgets.md) for usage.

## StyleMap

`plushie/prop/style_map`

`StyleMap` overrides the appearance of individual widget
instances. Themes set the baseline; `StyleMap` customises specific
widgets. Style-aware widgets expose a `Custom(StyleMap)` variant
on their own style sum type (e.g. `button.Custom`, `text.Custom`).

### Builder API

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/prop/shadow
import plushie/prop/style_map

let assert Ok(bg) = color.from_hex("#2563eb")
let assert Ok(border_color) = color.from_hex("#1d4ed8")
let assert Ok(shadow_color) = color.from_hex("#0000001a")

let style =
  style_map.new()
  |> style_map.base("#3b82f6")
  |> style_map.background("#3b82f6")
  |> style_map.text_color("#ffffff")
  |> style_map.border(
    border.new()
    |> border.color(border_color)
    |> border.width(1.0)
    |> border.to_prop_value()
  )
  |> style_map.shadow(
    shadow.new()
    |> shadow.color(shadow_color)
    |> shadow.blur_radius(4.0)
    |> shadow.to_prop_value()
  )
  |> style_map.hovered(style_map.new() |> style_map.background("#2563eb"))
  |> style_map.pressed(style_map.new() |> style_map.background("#1d4ed8"))
  |> style_map.disabled(
    style_map.new()
    |> style_map.background("#9ca3af")
    |> style_map.text_color("#6b7280"),
  )

ui.button("save", "Save", [button.Style(button.Custom(style))])
```

| Function | Purpose |
|---|---|
| `style_map.new()` | Empty style map |
| `style_map.base(String)` | Base colour (hex string) |
| `style_map.background(String)` | Background colour (hex string) |
| `style_map.gradient_background(Gradient)` | Background gradient |
| `style_map.text_color(String)` | Text colour (hex string) |
| `style_map.border(PropValue)` | Encoded border (use `border.to_prop_value`) |
| `style_map.shadow(PropValue)` | Encoded shadow (use `shadow.to_prop_value`) |
| `style_map.hovered(StyleMap)` | Overrides when hovered |
| `style_map.pressed(StyleMap)` | Overrides when pressed |
| `style_map.disabled(StyleMap)` | Overrides when disabled |
| `style_map.focused(StyleMap)` | Overrides when focused |
| `style_map.set(String, PropValue)` | Arbitrary key / value override |

Colour setters (`base`, `background`, `text_color`) accept raw
hex strings. Use `color.to_hex(c)` to convert a `Color` value
when needed.

### Status overrides

Each status override (`hovered`, `pressed`, `disabled`, `focused`)
accepts another `StyleMap` whose fields override the base while
the widget is in that state. Only the fields you set are
overridden; the rest inherit from the base style.

### Named presets

Each style-aware widget module exposes its own style sum type
with preset variants plus a `Custom(StyleMap)` escape hatch.
Preset variants encode to the renderer's built-in preset names:

```gleam
import plushie/widget/button.{Primary, Custom}

ui.button("save", "Save", [button.Style(Primary)])
ui.button("save", "Save", [button.Style(Custom(my_style_map))])
```

Common presets include `Primary`, `Secondary`, `Success`,
`Warning`, `Danger`, and style-specific variants like
`TextStyle`, `BackgroundStyle`. See each widget's module for its
exact variant set.

### Container style presets

`container.Style(String)` takes a named preset string directly:
`"transparent"`, `"rounded_box"`, `"bordered_box"`, `"dark"`,
`"primary"`, `"secondary"`, `"success"`, `"danger"`, `"warning"`.

## Gradient

`plushie/prop/gradient`

Linear gradients for use as background fills in widgets and style
maps. Two constructors cover the common shapes:

```gleam
import plushie/prop/color
import plushie/prop/gradient

let assert Ok(start) = color.from_hex("#3b82f6")
let assert Ok(end) = color.from_hex("#1d4ed8")

// Coordinate-based (unit square 0.0 to 1.0):
gradient.linear(
  from: #(0.0, 0.0),
  to: #(1.0, 1.0),
  stops: [gradient.stop(0.0, start), gradient.stop(1.0, end)],
)

// Angle-based (degrees, 0 = left to right, 90 = top to bottom):
gradient.linear_from_angle(
  135.0,
  [gradient.stop(0.0, start), gradient.stop(1.0, end)],
)
```

`gradient.stop(offset, color)` builds a `GradientStop` with a
0.0-1.0 offset and a `Color`.

Use gradients in container backgrounds via `container.BgGradient`
or in style maps via `style_map.gradient_background`.

## Border

`plushie/prop/border`

Border specifications for containers and style maps.

### Builder API

```gleam
import plushie/prop/border
import plushie/prop/color

let assert Ok(c) = color.from_hex("#e5e7eb")

let b =
  border.new()
  |> border.color(c)
  |> border.width(1.0)
  |> border.radius(8.0)
```

| Function | Purpose |
|---|---|
| `border.new()` | Border with defaults (no colour, zero width, zero radius) |
| `border.color(Color)` | Border colour |
| `border.width(Float)` | Border width in pixels |
| `border.radius(Float)` | Uniform corner radius |
| `border.radius_corners(tl, tr, br, bl)` | Per-corner radius |

`border.to_prop_value(b)` encodes to the wire format. Negative
widths or radii panic at encode time.

### Per-corner radius

```gleam
border.new()
|> border.width(1.0)
|> border.color(c)
|> border.radius_corners(8.0, 8.0, 0.0, 0.0)  // rounded top, square bottom
```

The corner order is `top_left, top_right, bottom_right,
bottom_left`.

## Shadow

`plushie/prop/shadow`

Drop shadow specifications for containers and style maps.

### Builder API

```gleam
import plushie/prop/color
import plushie/prop/shadow

let assert Ok(c) = color.from_hex("#0000001a")

let s =
  shadow.new()
  |> shadow.color(c)
  |> shadow.offset(0.0, 4.0)
  |> shadow.blur_radius(8.0)
```

| Function | Purpose |
|---|---|
| `shadow.new()` | Shadow with defaults |
| `shadow.color(Color)` | Shadow colour |
| `shadow.offset(Float, Float)` | X and Y offset in pixels |
| `shadow.offset_x(Float)` | X offset only |
| `shadow.offset_y(Float)` | Y offset only |
| `shadow.blur_radius(Float)` | Blur radius in pixels |

`shadow.to_prop_value(s)` encodes to the wire format.

## Encoding

All styling types expose a `to_prop_value/1` that encodes to the
wire format. Widget builders call these helpers during
`build()`, so by the time a node reaches tree normalisation its
props are already wire-compatible. You work with typed records
in view code, not with `PropValue` dictionaries.

## See also

- [Built-in Widgets reference](built-in-widgets.md) - which
  widgets accept `Style`, `Border`, `Shadow`, and `BgColor` opts
- [Canvas reference](canvas.md) - fill and stroke colours in
  canvas shapes
- [Windows and Layout reference](windows-and-layout.md) -
  `container` style presets and alignment
- [Accessibility reference](accessibility.md) - colour contrast
  and high-contrast modes
