# Built-in Widgets

All built-in widgets are available via the `plushie/ui` module as
convenience functions, and via per-widget builder modules under
`plushie/widget/*` for programmatic use. The two forms produce the
same nodes and can be mixed freely:

```gleam
import plushie/ui
import plushie/widget/button
import plushie/prop/length.{Fill}

// Convenience function with an opt list:
ui.button("save", "Save", [button.Width(Fill)])

// Typed builder with chainable setters:
button.new("save", "Save")
|> button.width(Fill)
|> button.build()
```

Each widget page below lists the module path. Prop names on the wire
follow snake_case; Gleam builder setters use snake_case, and the
`Opt` variants use PascalCase.

## Widget catalog

### Layout

| Function | Module | Description |
|---|---|---|
| `ui.window` | `plushie/widget/window` | Top-level window with title, size, position, theme |
| `ui.column` | `plushie/widget/column` | Arranges children vertically |
| `ui.row` | `plushie/widget/row` | Arranges children horizontally |
| `ui.container` | `plushie/widget/container` | Single-child wrapper for styling, scoping, alignment |
| `ui.scrollable` | `plushie/widget/scrollable` | Scrollable viewport around child content |
| `ui.stack` | `plushie/widget/stack` | Layers children on top of each other (z-axis) |
| `ui.grid` | `plushie/widget/grid` | Fixed-column or fluid grid layout |
| `ui.pane_grid` | `plushie/widget/pane_grid` | Resizable tiled pane layout |
| `ui.keyed_column` | `plushie/widget/keyed_column` | Vertical layout with ID-based diffing for dynamic lists |
| `ui.responsive` | `plushie/widget/responsive` | Emits resize events for adaptive layouts |
| `ui.pin` | `plushie/widget/pin` | Positions child at absolute coordinates |
| `ui.floating` | `plushie/widget/floating` | Applies translate/scale transforms to child |
| `ui.space` | `plushie/widget/space` | Invisible spacer |

Full prop tables for all layout containers are in the
[Layout reference](windows-and-layout.md).

### Input

| Function | Signature | Events (under `Widget(...)`) |
|---|---|---|
| `ui.button` | `button(id, label, opts)` | `Click` |
| `ui.text_input` | `text_input(id, value, opts)` | `Input`, `Submit`, `Paste` |
| `ui.text_editor` | `text_editor(id, content, opts)` | `Input` |
| `ui.checkbox` | `checkbox(id, label, is_toggled, opts)` | `Toggle` (Bool) |
| `ui.toggler` | `toggler(id, label, is_toggled, opts)` | `Toggle` (Bool) |
| `ui.radio` | `radio(id, value, selected, label, opts)` | `Select` |
| `ui.slider` | `slider(id, range, value, opts)` | `Slide`, `SlideRelease` |
| `ui.vertical_slider` | `vertical_slider(id, range, value, opts)` | `Slide`, `SlideRelease` |
| `ui.pick_list` | `pick_list(id, options, selected, opts)` | `Select`, `Open`, `Close` |
| `ui.combo_box` | `combo_box(id, options, value, opts)` | `Input`, `Select`, `Open`, `Close` |

Every widget-level interaction delivers an `Event` value whose
outer variant is `Widget(WidgetEvent)`. The event tables throughout
this page list the inner `WidgetEvent` constructor. See the
[Events reference](events.md) for the full type and pattern-matching
guide.

**button** is the simplest interactive widget. The label is the
second positional argument. Emits `Click` on press.

**text_input** is a single-line editable field. Emits `Input` on
every keystroke with the full text as the value. Emits `Submit` on
Enter when `text_input.OnSubmit(True)` is configured. `Paste` fires
when the user pastes into the field.

**text_editor** is a multi-line editable area with syntax
highlighting support via `text_editor.HighlightSyntax("gleam")`.
The `content` argument seeds the initial text. Holds renderer-side
state (cursor, selection, scroll).

**checkbox** / **toggler** are boolean toggles. Both emit
`Toggle(Bool)` with the new value. `checkbox` shows a box;
`toggler` shows a switch. Both take a label as their second
argument.

**slider** / **vertical_slider** take a `#(Float, Float)` range
tuple and a current value. Emits `Slide` continuously while
dragging and `SlideRelease` when the drag ends with the final
value.

**pick_list** is a dropdown selection. `options` is a list of
strings. `selected` is the currently selected value (`Some(value)`
or `None`). Emits `Select` when an option is chosen.

**combo_box** is a searchable dropdown. Combines a text input with
a filtered option list. Takes `options` and the current `value`
(the string displayed / committed). Holds renderer-side state
(search text, open state). Emits `Input` on typing and `Select` on
option selection.

**radio** is a one-of-many selection. `value` is the option this
radio represents; `selected` is the currently selected value from
the model. The radio is checked when `selected` equals `Some(value)`.
Emits `Select` with the radio's value.

### Display

| Function | Signature | Description |
|---|---|---|
| `ui.text` / `ui.text_` | `text(id, content, opts)` / `text_(id, content)` | Static text display |
| `ui.rich_text` | `rich_text(id, opts)` | Styled text with per-span formatting |
| `ui.rule` | `rule(id, opts)` | Horizontal or vertical divider |
| `ui.progress_bar` | `progress_bar(id, range, value, opts)` | Progress indicator |
| `ui.tooltip` | `tooltip(id, tip, opts, child)` | Popup tip on hover |
| `ui.image` | `image(id, source, opts)` | Raster image from file path or handle |
| `ui.svg` | `svg(id, source, opts)` | Vector image from SVG file |
| `ui.qr_code` | `qr_code(id, data, opts)` | QR code from a data string |
| `ui.markdown` | `markdown(id, content, opts)` | Rendered markdown |
| `ui.canvas` | `canvas(id, width, height, opts)` | Drawing surface with named layers |

**text** supports an opts list; `text_` is a shortcut for the
opts-free case. Key opts: `Size(Float)`, `Color(Color)`,
`Font(Font)`, `Wrapping(Wrapping)`, `Shaping(Shaping)`,
`AlignX(Alignment)`, `AlignY(Alignment)`.

**rich_text** displays styled text with individually formatted
spans. Each span is built with `rich_text.span(text)` and chainable
setters for `size`, `color`, `font`, `link`, `underline`,
`strikethrough`, `line_height`, `padding`, and `highlight`. Example:

```gleam
import plushie/ui
import plushie/widget/rich_text
import plushie/prop/color

ui.rich_text("greeting", [
  rich_text.Spans([
    rich_text.span("Hello, ") |> rich_text.span_size(16.0),
    rich_text.span("world")
      |> rich_text.span_size(16.0)
      |> rich_text.span_color(color.hex("#3b82f6"))
      |> rich_text.span_underline(True),
    rich_text.span("!") |> rich_text.span_size(16.0),
  ]),
])
```

`rich_text` itself also emits `LinkClicked(link)` when a span with
a `span_link` setter is activated.

**tooltip** wraps a child widget. The child is the anchor; `tip` is
the tooltip text. Opts: `Position(TooltipPosition)`, `Gap(Float)`.

**image** renders a raster image. Two source modes, both via the
single `source` argument:

- **Path-based** (preferred): `ui.image("photo", "path/to/file.png", [])`.
  The renderer loads the file directly. No wire transfer.
- **Handle-based**: pass a handle name previously registered via
  `command.create_image`. References an in-memory image.

Key opts: `ContentFit(ContentFit)`, `FilterMethod(FilterMethod)`,
`Width(Length)`, `Height(Length)`, `Opacity(Float)`,
`Rotation(Float)`, `BorderRadius(Float)`, `Scale(Float)`,
`Crop(Crop)`, `Alt(String)`.

**In-memory image handles:**

```gleam
// Create from encoded PNG/JPEG bytes:
command.create_image("avatar", png_bytes)

// Create from raw RGBA pixels:
command.create_image_rgba("avatar", 512, 512, rgba_pixels)

// Reference in view:
ui.image("display", "avatar", [])

// Update pixels:
command.update_image("avatar", new_pixels)

// Delete:
command.delete_image("avatar")
```

Handle-based images send the entire payload over the wire in a
single message, which blocks all other protocol traffic for large
images. Prefer path-based loading when the file exists on disk.

**canvas** contains named layers of shapes. See the
[Canvas reference](canvas.md).

## Table

`plushie/widget/table`

Displays structured data in rows and columns with sortable headers
and optional separators. Rows are real tree children, so adding,
removing, or reordering rows produces minimal wire patches
(LIS-based diffing) instead of re-sending the entire dataset.

Two row-construction paths are supported. Use the `Rows` convenience
prop for simple text-only tables, or `with_children` (and
`table.table_row` / `table.table_cell`) for rich cells containing
arbitrary widgets. The two are mutually exclusive; setting both
panics at build time.

### Simple text-only rows

```gleam
import gleam/dict
import plushie/node.{StringVal}
import plushie/ui
import plushie/widget/table

let cols = [
  table.column("name", "Name") |> table.column_sortable(True),
  table.column("email", "Email"),
]

let rows = [
  dict.from_list([
    #("name", StringVal("Ada")),
    #("email", StringVal("ada@example.com")),
  ]),
  dict.from_list([
    #("name", StringVal("Grace")),
    #("email", StringVal("grace@example.com")),
  ]),
]

ui.table("users", [
  table.Columns(cols),
  table.Rows(rows),
  table.SortBy("name"),
  table.SortOrder(table.Asc),
])
```

### Rich cells

When cells need widgets other than plain text (buttons, progress
bars, styled content), drop the `Rows` prop and construct children
directly:

```gleam
import plushie/ui
import plushie/widget/table

table.new("users")
|> table.columns([
  table.column("name", "Name"),
  table.column("progress", "Progress"),
  table.column("actions", "Actions"),
])
|> table.with_children(
  list.map(model.users, fn(user) {
    table.table_row(user.id, [
      table.table_cell("name", ui.text_("label", user.name)),
      table.table_cell(
        "progress",
        ui.progress_bar("prog", #(0.0, 100.0), user.progress, []),
      ),
      table.table_cell("actions", ui.button_("del-" <> user.id, "Delete")),
    ])
  }),
)
|> table.build()
```

### Columns

Column definitions are `table.Column` records, built with
`table.column(key, label)` and chainable setters. Every column
needs a `key` matching the row data field and a `label` for the
header text:

| Setter | Type | Description |
|---|---|---|
| `table.column_sortable` | `Bool` | Header clickable for sort |
| `table.column_width` | `Length` | Column width |
| `table.column_align` | `String` (`"left"`, `"center"`, `"right"`) | Cell alignment |

### Sorting

Mark columns as sortable via `column_sortable(True)`. Clicking a
sortable header emits `Widget(Sort(target, value))`, where `value`
is the column key. The table displays the sort indicator but does
not reorder rows. Sort in your model:

```gleam
case event {
  Widget(Sort(target: EventTarget(id: "users", ..), value: col)) -> {
    let order = case model.sort_by, model.sort_order {
      Some(current), table.Asc if current == col -> table.Desc
      _, _ -> table.Asc
    }
    let sorted = sort_users_by(model.users, col, order)
    #(
      Model(..model, users: sorted, sort_by: Some(col), sort_order: order),
      command.none(),
    )
  }
  _ -> #(model, command.none())
}
```

### Props

| Opt | Type | Description |
|---|---|---|
| `Columns` | `List(Column)` | Column definitions |
| `Rows` | `List(Dict(String, PropValue))` | Data shorthand for text-only rows |
| `Header` | `Bool` | Show header row (default `True`) |
| `Separator` | `Bool` | Enable row separators |
| `SeparatorThickness` | `Float` | Divider thickness in pixels |
| `SeparatorColor` | `Color` | Divider colour |
| `SortBy` | `String` | Currently sorted column key |
| `SortOrder` | `SortOrder` (`Asc` / `Desc`) | Sort direction |
| `Width` | `Length` | Table width |
| `Height` | `Length` | Table height (scrollable when set) |
| `Padding` | `Padding` | Cell internal padding |
| `HeaderTextSize` | `Float` | Header font size |
| `RowTextSize` | `Float` | Body font size (data shorthand) |
| `CellSpacing` | `Float` | Horizontal spacing between cells |
| `RowSpacing` | `Float` | Vertical spacing between rows |

## Pane grid

`plushie/widget/pane_grid`

Resizable tiled pane layout. Children are keyed by their node ID
and rendered as individual panes. The renderer manages internal
pane sizes and arrangement, persisted across re-renders by the
widget's ID.

```gleam
import plushie/ui
import plushie/widget/pane_grid
import plushie/widget/text_editor

ui.pane_grid("editor", [
  pane_grid.Panes(["left", "right"]),
  pane_grid.Spacing(2.0),
], [
  ui.text_editor("left", model.left_source, []),
  ui.text_editor("right", model.right_source, []),
])
```

### Pane grid props

| Opt | Type | Description |
|---|---|---|
| `Panes` | `List(String)` | List of pane identifiers |
| `Spacing` | `Float` | Space between panes in pixels |
| `Width` | `Length` | Grid width |
| `Height` | `Length` | Grid height |
| `MinSize` | `Float` | Minimum pane size in pixels |
| `DividerColor` | `Color` | Colour for the split divider |
| `DividerWidth` | `Float` | Divider thickness in pixels |
| `Leeway` | `Float` | Grabbable area around dividers |
| `SplitAxis` | `String` (`"horizontal"` or `"vertical"`) | Initial split direction |
| `EventRate` | `Int` | Max events/sec for coalescable pane events |

### Pane grid events

Pane grid events arrive as dedicated constructors under the
`WidgetEvent` umbrella. See the [Events reference](events.md) for
the full list. In summary:

| Event (under `Widget(...)`) | Fields | Description |
|---|---|---|
| `PaneClicked` | `target`, `pane` | A pane was selected |
| `PaneResized` | `target`, `split`, `ratio` | A split divider was moved |
| `PaneDragged` | `target`, `pane`, `drop_target`, `action`, `region`, `edge` | Drag in progress |
| `PaneFocusCycle` | `target`, `pane` | F6 / Shift+F6 focus cycling |

### Usage patterns

Pane identifiers in the `Panes` list determine which children map
to which pane. Each child's ID must match a pane identifier.

The pane grid holds renderer-side state (pane sizes, arrangement).
If the widget's ID changes, this state resets. An explicit string
ID is required; passing `""` (auto-ID) is a runtime error.

For accessibility, wrap the pane grid in a container with an
explicit role and label (see the [Accessibility
reference](accessibility.md)).

## Interaction wrappers

### pointer_area

`plushie/widget/pointer_area`

Wraps a single child and captures pointer events from mouse, touch,
and pen input. Use for right-click menus, hover detection, drag
tracking, scroll capture, and custom cursor styles. All events use
the unified pointer model: the `pointer` field (`Mouse`, `Touch`,
`Pen`) identifies the device, and `modifiers` carries the current
modifier key state for shift-click, ctrl-drag, and similar
patterns.

| Opt | Type | Purpose |
|---|---|---|
| `Cursor` | `Cursor` | Mouse cursor on hover |
| `OnPress` | `String` | Left button press event tag |
| `OnRelease` | `String` | Left button release event tag |
| `OnRightPress` | `Bool` | Enable right button press |
| `OnRightRelease` | `Bool` | Enable right button release |
| `OnMiddlePress` | `Bool` | Enable middle button press |
| `OnMiddleRelease` | `Bool` | Enable middle button release |
| `OnDoubleClick` | `Bool` | Enable double-click |
| `OnEnter` | `Bool` | Enable cursor enter |
| `OnExit` | `Bool` | Enable cursor exit |
| `OnMove` | `Bool` | Enable cursor move (coalescable) |
| `OnScroll` | `Bool` | Enable scroll wheel (coalescable) |
| `EventRate` | `Int` | Max events/sec for move and scroll |
| `A11y` | `A11y` | Accessibility overrides |

`Cursor` values: `Pointer`, `Grab`, `Grabbing`, `Crosshair`,
`CursorText`, `CursorMove`, `NotAllowed`, `Progress`, `Wait`,
`Help`, `Cell`, `Copy`, `CursorAlias`, `NoDrop`, `AllScroll`,
`ZoomIn`, `ZoomOut`, `ContextMenu`, `ResizingHorizontally`,
`ResizingVertically`, `ResizingDiagonallyUp`,
`ResizingDiagonallyDown`, `ResizingColumn`, `ResizingRow`.

Move and scroll events carry `pointer` (device type) and
`modifiers` (current modifier key state):

```gleam
import plushie/event.{
  EventTarget, Mouse, Move, Press, Scroll, Widget,
}
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/pointer_area

ui.pointer_area("canvas-area", [
  pointer_area.OnMove(True),
  pointer_area.OnPress("area_press"),
  pointer_area.OnScroll(True),
  pointer_area.Cursor(pointer_area.Crosshair),
], [
  ui.canvas("drawing", Fixed(400.0), Fixed(300.0), []),
])

case event {
  // Shift-click for multi-select
  Widget(Press(
    target: EventTarget(id: "canvas-area", ..),
    pointer: Mouse,
    modifiers: m,
    ..,
  )) if m.shift -> add_to_selection(model)

  // Ctrl-drag for panning
  Widget(Move(
    target: EventTarget(id: "canvas-area", ..),
    x: x,
    y: y,
    modifiers: m,
    ..,
  )) if m.ctrl -> pan_canvas(model, x, y)

  // Scroll with pointer type
  Widget(Scroll(
    target: EventTarget(id: "canvas-area", ..),
    delta_y: dy,
    pointer: Mouse,
    ..,
  )) -> zoom(model, dy)

  _ -> model
}
```

### sensor

`plushie/widget/sensor`

Wraps a single child and emits events when the child's size
changes. Useful for responsive layouts and intersection-style
observation.

| Opt | Type | Purpose |
|---|---|---|
| `Delay` | `Int` | Delay (ms) before emitting events |
| `Anticipate` | `Float` | Distance (px) to anticipate visibility |
| `OnResize` | `String` | Event tag for resize events |
| `EventRate` | `Int` | Max events/sec for resize |
| `A11y` | `A11y` | Accessibility overrides |

Emits `Widget(Resize(target, width, height))` when the wrapped
child's rendered size changes.

### overlay

`plushie/widget/overlay`

Positions the second child as a floating overlay relative to the
first child (anchor). Exactly two children required; fewer or more
panics at build time.

| Opt | Type | Default | Purpose |
|---|---|---|---|
| `Position` | `OverlayPosition` (`Below`, `Above`, `OverlayLeft`, `OverlayRight`) | `Below` | Overlay position |
| `Gap` | `Float` | `0.0` | Space between anchor and overlay |
| `OffsetX` | `Float` | `0.0` | Horizontal offset after positioning |
| `OffsetY` | `Float` | `0.0` | Vertical offset after positioning |
| `Flip` | `Bool` | `False` | Auto-flip when overlay overflows viewport |
| `Align` | `OverlayAlign` (`AlignStart`, `AlignCenter`, `AlignEnd`) | `AlignCenter` | Cross-axis alignment |
| `Width` | `Length` | — | Overlay container width |
| `A11y` | `A11y` | — | Accessibility overrides |

The overlay renders above all other content at the positioned
location. See the [Composition Patterns
reference](composition-patterns.md) for a popover menu example.

### themer

`plushie/widget/themer`

Applies a different theme to its children. Constructor takes the
theme positionally. A themer takes exactly one child.

```gleam
import plushie/prop/padding
import plushie/prop/theme.{Dark}
import plushie/widget/container
import plushie/widget/themer

themer.new("dark-section", Dark)
|> themer.push(
  ui.container("body", [container.Padding(padding.all(12.0))], [
    ui.text_("info", "This section uses the dark theme"),
  ]),
)
|> themer.build()
```

## Common props

Most widgets support a subset of these cross-cutting props:

- **Style** (`button.Style`, `text.Style`, etc.) - visual appearance.
  Each widget exposes its own style sum type (`ButtonStyle`,
  `TextStyle`, ...) with preset variants and a `Custom(StyleMap)`
  variant for reusable theming. See the [Styling
  reference](themes-and-styling.md).
- **A11y** - accessibility attributes. See the [Accessibility
  reference](accessibility.md).
- **Width / Height** - sizing. Accepts `Fill`, `Shrink`,
  `FillPortion(Int)`, or `Fixed(Float)` from `plushie/prop/length`.
  See the [Layout reference](windows-and-layout.md).
- **EventRate** - max events per second for high-frequency events.
  Supported on widgets that emit coalescable events
  (`slider`, `vertical_slider`, `pointer_area`, `sensor`,
  `canvas`, `pane_grid`).

## Renderer-side state

Some widgets hold state in the renderer that persists across
re-renders. If their ID changes, this state resets:

- **`text_input`** - cursor position, selection, undo history
- **`text_editor`** - cursor, selection, scroll position, undo
- **`combo_box`** - search text, open/closed state
- **`scrollable`** - scroll position
- **`pane_grid`** - pane sizes and arrangement

Give these widgets explicit string IDs. Auto-IDs (passing `""`)
derive from the node's position in its parent's children, so any
reorder or insertion resets renderer state. An explicit ID keeps
state stable across list edits.

## keyed_column vs column

Use `ui.column` for static layouts. Use `ui.keyed_column` when
children are dynamic (added, removed, reordered). It diffs by
child ID instead of position, preserving widget state across
list changes. Same props as `column` minus `AlignX`, `Clip`, and
`Wrap`.

## Auto-ID vs explicit ID

Every widget constructor takes an `id` argument. Passing the empty
string `""` requests an auto-generated ID of the form
`"auto:<kind>:<index>"`, where `<index>` is the child's position
among its parent's children. Auto-IDs skip the user-ID validation
rules and are transparent to event scoping.

Auto-IDs are appropriate for purely structural nodes that you
never need to reference: a `column` grouping two labels, a
throwaway `container` for padding, a `space` widget. Use an
explicit string ID whenever you plan to match events to that
widget, apply a scope name, or reach for
[runtime state queries](app-lifecycle.md).

Avoid auto-IDs on widgets with renderer-side state (listed above).
The ID depends on the node's position in its parent's children, so
any reorder or insertion causes the state to reset.

## Animatable props

Numeric props on supported widgets can drive renderer-side
animations via pre-encoded descriptors from
`plushie/animation/transition`, `plushie/animation/spring`, and
`plushie/animation/sequence`. The widget module exposes a parallel
`_animated` setter per animatable prop (e.g. `button.width_animated`,
`image.opacity_animated`). See the [Animation
reference](animation.md) for descriptor construction and the full
list of animatable props per widget.

## Prop value types

These prop types are used across multiple widgets. The full
styling types (`Color`, `Theme`, `StyleMap`, `Border`, `Shadow`,
`Gradient`) are in the [Styling reference](themes-and-styling.md).
Layout types (`Length`, `Padding`, `Alignment`) are in the [Layout
reference](windows-and-layout.md).

### Font

Module `plushie/prop/font`. Used by: `text`, `rich_text`,
`text_input`, `text_editor`.

| Value | Meaning |
|---|---|
| `DefaultFont` | System default proportional font |
| `Monospace` | System monospace font |
| `Family("Family Name")` | Specific font family (must be loaded via app settings) |
| `CustomFont(family, weight, style, stretch)` | Explicit weight / style / stretch |

`CustomFont` takes a `FontWeight` (`Thin`, `ExtraLight`, `Light`,
`Normal`, `Medium`, `SemiBold`, `Bold`, `ExtraBold`, `Black`), a
`FontStyle` (`NormalStyle`, `Italic`, `Oblique`), and a
`FontStretch` (`UltraCondensed` through `UltraExpanded`).

### Shaping

Module `plushie/prop/shaping`. Used by: `text`, `rich_text`,
`text_input`, `text_editor`.

| Value | Meaning |
|---|---|
| `Basic` | Simple left-to-right shaping (fastest) |
| `Advanced` | Full Unicode shaping (ligatures, RTL, complex scripts) |
| `Auto` | Let the renderer decide based on content |

### Text direction

Module `plushie/prop/text_direction`. Used by: `text`,
`text_input`, `text_editor`.

| Value | Meaning |
|---|---|
| `Auto` | Let the renderer use its default direction handling |
| `Ltr` | Treat logical text layout and movement as left-to-right |
| `Rtl` | Treat logical text layout and movement as right-to-left |

Placeholder text uses the same direction hint as the input or editor
value.

### Wrapping

Module `plushie/prop/wrapping`. Used by: `text`, `rich_text`.

| Value | Meaning |
|---|---|
| `NoWrap` | No wrapping (text overflows) |
| `Word` | Break at word boundaries |
| `Glyph` | Break at any character |
| `WordOrGlyph` | Try word boundaries first, fall back to glyph |

### Content fit

Module `plushie/prop/content_fit`. Used by: `image`, `svg`.

| Value | Meaning |
|---|---|
| `Contain` | Scale to fit within bounds, preserving aspect ratio |
| `Cover` | Scale to fill bounds, cropping if needed |
| `FitFill` | Stretch to fill bounds exactly (may distort) |
| `NoFit` | No scaling (original size) |
| `ScaleDown` | Like `Contain` but never scales up |

### Filter method

Module `plushie/prop/filter_method`. Used by: `image`.

| Value | Meaning |
|---|---|
| `Nearest` | Pixel-perfect interpolation (blocky, good for pixel art) |
| `Linear` | Smooth interpolation (good for photos) |

### Tooltip position

Module `plushie/prop/position`. Used by: `tooltip`.

| Value | Meaning |
|---|---|
| `Top` | Above the widget |
| `Bottom` | Below the widget |
| `PositionLeft` | Left of the widget |
| `PositionRight` | Right of the widget |
| `FollowCursor` | Follows the mouse cursor |

### Scroll direction

Module `plushie/prop/direction`. Used by: `scrollable`.

| Value | Meaning |
|---|---|
| `Vertical` | Vertical scrolling (default) |
| `Horizontal` | Horizontal scrolling |
| `Both` | Bidirectional scrolling |

### Scroll anchor

Module `plushie/prop/anchor`. Used by: `scrollable`.

| Value | Meaning |
|---|---|
| `AnchorStart` | Anchor at the top/left (default) |
| `AnchorEnd` | Anchor at the bottom/right |

### Auto scroll

When `scrollable.AutoScroll(True)` is set, the scrollable
automatically scrolls to reveal new content appended at the anchor
end. This is useful for chat logs, terminal output, and other
append-only content where the user expects to see the latest
entries without manual scrolling.

```gleam
import plushie/prop/anchor.{AnchorEnd}
import plushie/prop/direction.{Vertical}
import plushie/ui
import plushie/widget/column
import plushie/widget/scrollable

ui.scrollable("log", [
  scrollable.Direction(Vertical),
  scrollable.Anchor(AnchorEnd),
  scrollable.AutoScroll(True),
], [
  ui.column(
    "entries",
    [column.Spacing(4.0)],
    list.map(model.log_entries, fn(entry) { ui.text_(entry.id, entry.text) }),
  ),
])
```

When the user manually scrolls away from the anchor, auto-scroll
pauses to avoid fighting the user's position. It resumes when the
user scrolls back to the anchor end.

## See also

- [Layout reference](windows-and-layout.md) - sizing, alignment,
  and all layout containers with full prop tables
- [Styling reference](themes-and-styling.md) - `Color`, `Theme`,
  `StyleMap`, `Border`, `Shadow`, `Gradient`
- [Canvas reference](canvas.md) - shapes, layers, interactive
  elements
- [Accessibility reference](accessibility.md) - the `A11y` prop,
  roles, and keyboard navigation
- [Events reference](events.md) - all event types delivered by
  widgets
- [Animation reference](animation.md) - transition, spring, loop
  descriptors
- [Custom widgets reference](custom-widgets.md) - writing your
  own widgets in pure Gleam or as native Rust crates
