# Theming

Plushie exposes iced's theming system directly. No additional abstraction
layer, no token system, no design system framework. If you need those,
build them in your app.

## Setting a theme

Themes are set at the window level:

```gleam
import plushie/ui
import plushie/prop/theme

fn view(model) {
  ui.window("main", [ui.title("My App")], [
    ui.themer("theme", "catppuccin_mocha", [], [
      ui.column("content", [], [
        ui.text_("label", "Themed content"),
      ]),
    ]),
  ])
}
```

Or set the default theme in app settings:

<!-- test: theming_settings_theme_test -- keep this code block in sync with the test -->
```gleam
import plushie/app
import plushie/prop/theme.{CatppuccinMocha}
import gleam/option.{Some}

let settings = app.Settings(..app.default_settings(), theme: Some(CatppuccinMocha))
```

## Built-in themes

Iced 0.14 ships with 22 built-in themes. Plushie passes the theme name
string directly to the renderer, which resolves it to an iced `Theme`
variant.

All 22 built-in themes:

| Name | Constructor | Description |
|---|---|---|
| `light` | `Light` | Default light theme |
| `dark` | `Dark` | Default dark theme |
| `dracula` | `Dracula` | Dracula color scheme |
| `nord` | `Nord` | Nord color scheme |
| `solarized_light` | `SolarizedLight` | Solarized Light |
| `solarized_dark` | `SolarizedDark` | Solarized Dark |
| `gruvbox_light` | `GruvboxLight` | Gruvbox Light |
| `gruvbox_dark` | `GruvboxDark` | Gruvbox Dark |
| `catppuccin_latte` | `CatppuccinLatte` | Catppuccin Latte (light) |
| `catppuccin_frappe` | `CatppuccinFrappe` | Catppuccin Frappe |
| `catppuccin_macchiato` | `CatppuccinMacchiato` | Catppuccin Macchiato |
| `catppuccin_mocha` | `CatppuccinMocha` | Catppuccin Mocha (dark) |
| `tokyo_night` | `TokyoNight` | Tokyo Night |
| `tokyo_night_storm` | `TokyoNightStorm` | Tokyo Night Storm |
| `tokyo_night_light` | `TokyoNightLight` | Tokyo Night Light |
| `kanagawa_wave` | `KanagawaWave` | Kanagawa Wave |
| `kanagawa_dragon` | `KanagawaDragon` | Kanagawa Dragon |
| `kanagawa_lotus` | `KanagawaLotus` | Kanagawa Lotus |
| `moonfly` | `Moonfly` | Moonfly |
| `nightfly` | `Nightfly` | Nightfly |
| `oxocarbon` | `Oxocarbon` | Oxocarbon |
| `ferra` | `Ferra` | Ferra |

Unknown names fall back to `dark`.

## Custom themes

Custom themes are defined by providing a palette via `theme.custom`:

<!-- test: theming_custom_theme_test -- keep this code block in sync with the test -->
```gleam
import plushie/prop/theme
import plushie/node.{StringVal}
import gleam/dict

let my_theme = theme.custom("my_app", dict.from_list([
  #("background", StringVal("#1e1e2e")),
  #("text", StringVal("#cdd6f4")),
  #("primary", StringVal("#89b4fa")),
  #("success", StringVal("#a6e3a1")),
  #("danger", StringVal("#f38ba8")),
  #("warning", StringVal("#f9e2af")),
]))
```

The palette dict is passed to iced's `Theme::custom()` with Oklch-based
palette generation (plushie-iced). Only the colors you specify are overridden;
the rest are derived automatically.

## Extended palette shade overrides

When you set a custom theme, iced generates an "extended palette" of shade
variants from your six core colors. These shades (strong, weak, base, etc.)
control how widgets render their backgrounds, borders, and text in different
states. By default the shades are derived automatically using iced's
Oklch-based color math.

If the auto-generated shades don't match your design, you can override
individual shades by adding flat keys to the theme map. Only the shades
you specify are replaced -- the rest keep their generated values.

### Why override shades?

- Pin a specific button hover or pressed color
- Ensure WCAG contrast ratios on specific shade/text pairs
- Match an existing brand color system that doesn't follow iced's derivation

### Key naming convention

For the five color families (primary, secondary, success, warning, danger),
each has three shade levels:

| Key | What it controls |
|-----|------------------|
| `{family}_base` | Base shade background |
| `{family}_weak` | Weak shade background |
| `{family}_strong` | Strong shade background |
| `{family}_base_text` | Text color on the base shade |
| `{family}_weak_text` | Text color on the weak shade |
| `{family}_strong_text` | Text color on the strong shade |

Where `{family}` is one of: `primary`, `secondary`, `success`, `warning`,
`danger`.

The background family has eight levels:

| Key | What it controls |
|-----|------------------|
| `background_base` | Base background |
| `background_weakest` | Weakest background shade |
| `background_weaker` | Weaker background shade |
| `background_weak` | Weak background shade |
| `background_neutral` | Neutral background shade |
| `background_strong` | Strong background shade |
| `background_stronger` | Stronger background shade |
| `background_strongest` | Strongest background shade |

Each background key also supports a `_text` suffix (e.g.
`background_weakest_text`).

### Example

<!-- test: theming_custom_theme_shade_overrides_test -- keep this code block in sync with the test -->
```gleam
let branded_theme = theme.custom("branded", dict.from_list([
  #("background", StringVal("#1a1a2e")),
  #("text", StringVal("#e0e0e0")),
  #("primary", StringVal("#0f3460")),
  // Override the strong primary shade and its text color
  #("primary_strong", StringVal("#1a5276")),
  #("primary_strong_text", StringVal("#ffffff")),
  // Pin the weakest background for sidebar panels
  #("background_weakest", StringVal("#0d0d1a")),
]))
```

Shade overrides only apply to custom themes (dict values). Built-in theme
constructors like `Dark` or `Nord` are not affected.

## Per-subtree theme override

Themes can be overridden for a subtree using the `themer` widget:

```gleam
ui.column("layout", [], [
  ui.text_("label", "Uses window theme"),
  ui.themer("sidebar_theme", "nord", [], [
    ui.text_("nord_label", "Uses Nord theme"),
  ]),
])
```

This is useful for panels, modals, or sections that need a different
visual treatment.

## Widget-level styling

Individual widgets accept a `style` attr. This can be a named preset
string or a `StyleMap` for per-instance visual customization.

### Named presets

```gleam
ui.button("save", "Save", [ui.style("primary")])
ui.button("cancel", "Cancel", [ui.style("secondary")])
ui.button("delete", "Delete", [ui.style("danger")])
```

Style strings (`"primary"`, `"secondary"`, `"danger"`, etc.) map to iced's
built-in style functions. Available presets vary by widget.

### Style maps

Style maps let you fully customize widget appearance from Gleam without
writing Rust. They work on all 13 styleable widgets: button, container,
text_input, text_editor, checkbox, radio, toggler, pick_list, progress_bar,
rule, slider, vertical_slider, and tooltip.

<!-- test: theming_style_map_basic_test, theming_style_map_with_border_test, theming_style_map_with_shadow_test -- keep this code block in sync with the test -->
```gleam
import plushie/prop/style_map
import plushie/prop/border
import plushie/prop/shadow
import plushie/prop/color

let card_style =
  style_map.new()
  |> style_map.background("#ffffff")
  |> style_map.text_color("#1a1a1a")
  |> style_map.border(
    border.new()
    |> border.radius(8.0)
    |> border.width(1.0)
    |> border.color(color.from_hex_unsafe("#e0e0e0"))
    |> border.to_prop_value()
  )
  |> style_map.shadow(
    shadow.new()
    |> shadow.color(color.from_hex_unsafe("#00000020"))
    |> shadow.offset(0.0, 2.0)
    |> shadow.blur_radius(8.0)
    |> shadow.to_prop_value()
  )

// Use style_map.to_prop_value to pass as a prop
```

### Style map fields

- `background` -- hex color for the widget background
- `text_color` -- hex color for text
- `border` -- a `Border` PropValue (color, width, radius)
- `shadow` -- a `Shadow` PropValue (color, offset, blur_radius)

### Status overrides

Style maps support interaction state overrides. Each override is a
nested StyleMap that is merged on top of the base when the widget
enters that state:

<!-- test: theming_style_map_status_overrides_test -- keep this code block in sync with the test -->
```gleam
let nav_item_style =
  style_map.new()
  |> style_map.background("#00000000")
  |> style_map.text_color("#cccccc")
  |> style_map.hovered(
    style_map.new()
    |> style_map.background("#333333")
    |> style_map.text_color("#ffffff")
  )
  |> style_map.pressed(
    style_map.new()
    |> style_map.background("#222222")
  )
  |> style_map.disabled(
    style_map.new()
    |> style_map.text_color("#666666")
  )
```

Supported statuses: `hovered`, `pressed`, `disabled`, `focused`.

If you don't specify an override for a status, the renderer auto-derives:

- **hovered**: darkens background by 10%
- **pressed**: uses the base style (matching iced's own pattern)
- **disabled**: applies 50% alpha to background and text_color

This means hover and disabled states "just work" without explicit
overrides in most cases. You only need explicit overrides when you want
a specific look.

### Presets and style maps together

Style maps don't replace presets -- they complement them. Use presets
for standard looks and style maps when you need custom appearance:

```gleam
// Standard danger button
ui.button("delete", "Delete", [ui.style("danger")])

// Custom branded button (pass style_map as a prop via widget builder)
import plushie/widget/button

button.new("cta", "Get Started")
|> button.style_map(
  style_map.new()
  |> style_map.background("#7c3aed")
  |> style_map.text_color("#ffffff")
  |> style_map.border(
    border.new() |> border.radius(24.0) |> border.to_prop_value()
  )
)
|> button.build()
```

See `docs/composition-patterns.md` for concrete examples of building
polished UI patterns with style maps.

## System theme detection

The simplest way to follow the OS light/dark preference is to set the
theme to `SystemTheme`:

<!-- test: theming_system_theme_setting_test -- keep this code block in sync with the test -->
```gleam
let settings = app.Settings(..app.default_settings(), theme: Some(SystemTheme))
```

The renderer tracks the current OS mode and applies Light or Dark
automatically.

For manual control, subscribe to theme change events with
`subscription.on_theme_change`:

```gleam
import plushie/subscription

fn subscribe(_model) {
  [subscription.on_theme_change("theme_changed")]
}

fn update(model, event) {
  case event {
    event.SystemThemeChanged(mode:) -> {
      // mode is "light" or "dark"
      #(Model(..model, preferred_theme: mode), command.none())
    }
    _ -> #(model, command.none())
  }
}
```

Your app can use this to follow the system theme or ignore it entirely.

**Note:** The `themer` widget (per-subtree theme override) does not support
`"system"` as a theme value. Setting a themer's theme to `"system"` is
treated as "no override" (the parent theme passes through). Use
`SystemTheme` in app settings instead.

## Density

For apps that need density-aware spacing (compact, comfortable, roomy),
build a simple helper function in your app:

```gleam
fn spacing(density, size) {
  case density, size {
    Compact, Md -> 4
    Comfortable, Md -> 8
    Roomy, Md -> 12
    // ... etc.
  }
}

ui.column("col", [ui.spacing(spacing(Compact, Md))], [...])
```

There is no global density setting or built-in density module -- your app
decides how to handle it.
