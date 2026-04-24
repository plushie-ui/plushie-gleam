# Windows and Layout

Every Plushie app starts with a window. Inside it, you compose layout
containers to arrange widgets.

## Window

`plushie/widget/window`

```gleam
ui.window("main", [window.Title("My App")], [main_content(model)])
ui.window("main", [window.Title("My App"), window.Theme(theme.Dark)], [...])
```

### Window props

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `Title` | String | | Title bar text |
| `Size` | #(Int, Int) | | Initial size in pixels |
| `Position` | #(Int, Int) | | Initial position |
| `MinSize` | #(Int, Int) | | Minimum dimensions |
| `MaxSize` | #(Int, Int) | | Maximum dimensions |
| `Maximized` | Bool | False | Start maximized |
| `Fullscreen` | Bool | False | Start fullscreen |
| `Visible` | Bool | True | Whether window is visible |
| `Resizable` | Bool | True | Allow resizing |
| `Decorations` | Bool | True | Show title bar and borders |
| `Transparent` | Bool | False | Transparent window background |
| `Level` | WindowLevel | Normal | Stacking level |
| `ExitOnCloseRequest` | Bool | True | Close exits the app |
| `Theme` | Theme | | Per-window theme |

### Multi-window

`view` returns a list of top-level window nodes. The runtime opens,
closes, and updates windows based on what is in the list on each render.

On native targets any number of peer windows is supported. On the WASM
target (`plushie_web`), the platform has no OS-level multi-window
capability; the runtime logs a `MultipleTopLevelWindows` diagnostic and
collapses the list. Design multi-window apps around native transports.

```gleam
fn view(model: Model) {
  case model.show_settings {
    True -> [
      ui.window("main", [window.Title("App")], [main_content(model)]),
      ui.window("settings", [
        window.Title("Settings"),
        window.ExitOnCloseRequest(False),
      ], [settings_content(model)]),
    ]
    False -> [
      ui.window("main", [window.Title("App")], [main_content(model)]),
    ]
  }
}
```

## Sizing

`plushie/prop/length`

| Value | Behaviour |
|---|---|
| `Shrink` | Content size (default) |
| `Fill` | All available space |
| `FillPortion(n)` | Proportional share |
| `Fixed(n)` | Exact pixels |

## Padding

`plushie/prop/padding`

```gleam
// Uniform
column.Padding(padding.all(16.0))

// Per-side
column.Padding(padding.Padding(top: 16.0, right: 12.0, bottom: 8.0, left: 12.0))
```

## Alignment

`plushie/prop/alignment`

| AlignX values | AlignY values |
|---|---|
| `Left` (default), `Center`, `Right` | `Top` (default), `Center`, `Bottom` |

No `Start`/`End` variants, only `Left`/`Right`/`Top`/`Bottom`/`Center`.

## Layout containers

### column

Vertical stack. Props: `Spacing`, `Padding`, `Width`, `Height`,
`MaxWidth`, `AlignX`, `Clip`, `Wrap`.

### row

Horizontal stack. Props: `Spacing`, `Padding`, `Width`, `Height`,
`MaxWidth`, `AlignY`, `Clip`, `Wrap`.

### container

Single-child wrapper. Props: `Padding`, `Width`, `Height`, `MaxWidth`,
`MaxHeight`, `AlignX`, `AlignY`, `Center`, `Clip`, `Background`,
`Border`, `Shadow`, `Style`.

### scrollable

Scrollable viewport. Requires explicit ID. Props: `Width`, `Height`,
`Direction` (Vertical, Horizontal, Both), `AutoScroll`, `Anchor`,
`OnScroll`.

### keyed_column

Like `column` but diffs by child ID. Use for dynamic lists.

### stack

Z-axis layering. First child is back, last is front.

### grid

Fixed columns (`Columns(3)`) or fluid (`Fluid(200)`).

### pin

Absolute positioning: `X`, `Y`.

### floating

Visual transforms: `TranslateX`, `TranslateY`, `Scale`.

### responsive

Emits `WidgetResize` events on size change.

### space

Invisible spacer.

### pane_grid

Resizable tiled panes. Requires explicit ID. Emits pane events.

## See also

- [Layout guide](../guides/07-layout.md)
- [Themes and Styling](themes-and-styling.md)
- [Scoped IDs](scoped-ids.md)
- [Built-in Widgets](built-in-widgets.md)
