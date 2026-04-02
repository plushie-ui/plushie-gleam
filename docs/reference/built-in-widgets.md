# Built-in Widgets

All built-in widgets are available via `plushie/ui`. Each widget has a
corresponding typed builder module under `plushie/widget/*`.

## Layout

| Function | Module | Description |
|---|---|---|
| `ui.window` | `plushie/widget/window` | Top-level window |
| `ui.column` | `plushie/widget/column` | Vertical layout |
| `ui.row` | `plushie/widget/row` | Horizontal layout |
| `ui.container` | `plushie/widget/container` | Single-child wrapper |
| `ui.scrollable` | `plushie/widget/scrollable` | Scrollable viewport |
| `ui.stack` | `plushie/widget/stack` | Z-axis layering |
| `ui.grid` | `plushie/widget/grid` | Grid layout |
| `ui.keyed_column` | `plushie/widget/keyed_column` | ID-based diffing for dynamic lists |
| `ui.responsive` | `plushie/widget/responsive` | Resize-aware container |
| `ui.pin` | `plushie/widget/pin` | Absolute positioning |
| `ui.floating` | `plushie/widget/floating` | Translate/scale transforms |
| `ui.space` | `plushie/widget/space` | Invisible spacer |

## Input

| Function | Events |
|---|---|
| `ui.button` | `WidgetClick` |
| `ui.text_input` | `WidgetInput`, `WidgetSubmit`, `WidgetPaste` |
| `ui.text_editor` | `WidgetInput` |
| `ui.checkbox` | `WidgetToggle` (Bool) |
| `ui.toggler` | `WidgetToggle` (Bool) |
| `ui.radio` | `WidgetSelect` |
| `ui.slider` | `WidgetSlide`, `WidgetSlideRelease` |
| `ui.vertical_slider` | `WidgetSlide`, `WidgetSlideRelease` |
| `ui.pick_list` | `WidgetSelect`, `WidgetOpen`, `WidgetClose` |
| `ui.combo_box` | `WidgetInput`, `WidgetSelect` |

## Display

| Function | Description |
|---|---|
| `ui.text` | Static text display |
| `ui.rich_text` | Styled text with per-span formatting |
| `ui.rule` | Horizontal or vertical divider |
| `ui.progress_bar` | Progress indicator |
| `ui.tooltip` | Popup tip on hover |
| `ui.image` | Raster image |
| `ui.svg` | Vector image |
| `ui.qr_code` | QR code from data string |
| `ui.markdown` | Rendered markdown |
| `ui.canvas` | Drawing surface with layers |

## Interaction wrappers

### pointer_area

Wraps a single child and captures pointer events. Uses the unified pointer
model: `WidgetPress`, `WidgetRelease`, `WidgetMove`, `WidgetScroll`,
`WidgetEnter`, `WidgetExit`. The `pointer` field identifies the device
(Mouse, Touch, Pen).

### sensor

Emits `WidgetResize` events when the child's size changes.

### overlay

Positions a floating child relative to an anchor. First child is anchor,
second is overlay.

### themer

Applies a different theme to its children.

## Table

```gleam
ui.table("users", [
  table.Columns([
    table.column("name", "Name", [table.Sortable(True)]),
    table.column("email", "Email", [table.ColumnWidth(FillPortion(2))]),
  ]),
  table.Rows(rows),
  table.SortBy(model.sort_by),
  table.SortOrder(model.sort_order),
])
```

The table emits `WidgetSort` events when a sortable header is clicked.
The table does not sort itself; sort in your model or use `plushie/data`.

## Renderer-side state

These widgets hold state in the renderer. If their ID changes, the state
resets: `text_input`, `text_editor`, `combo_box`, `scrollable`, `pane_grid`.

## See also

- [Windows and Layout](windows-and-layout.md)
- [Themes and Styling](themes-and-styling.md)
- [Canvas](canvas.md)
- [Events](events.md)
- [Animation](animation.md)
