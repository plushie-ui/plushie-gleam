# Windows and Layout

Every Plushie app starts with one or more windows. Inside each, you
compose layout containers to arrange widgets on screen. This page
covers windows, sizing, spacing, alignment, and all layout
containers.

## Window

`plushie/widget/window`

The top-level container. Every `view` must return a list of window
nodes (or a single window node inside a one-element list). Windows
map to native OS windows, each with its own title bar, size,
position, and optional theme.

```gleam
import plushie/prop/length.{Fill}
import plushie/prop/theme.{Dark}
import plushie/ui
import plushie/widget/column
import plushie/widget/window

ui.window("main", [window.Title("My App"), window.WindowTheme(Dark)], [
  ui.column("root", [column.Width(Fill), column.Height(Fill)], [
    // app content
  ]),
])
```

### Window opts

| Opt | Type | Purpose |
|---|---|---|
| `Title` | `String` | Title bar text |
| `Size` | `Float`, `Float` | Initial size in pixels |
| `Width` | `Length` | Width (alternative to `Size`) |
| `Height` | `Length` | Height (alternative to `Size`) |
| `Position` | `Float`, `Float` | Initial position |
| `MinSize` | `Float`, `Float` | Minimum dimensions |
| `MaxSize` | `Float`, `Float` | Maximum dimensions |
| `Maximized` | `Bool` | Start maximized |
| `Fullscreen` | `Bool` | Start fullscreen |
| `Visible` | `Bool` | Whether window is visible |
| `Resizable` | `Bool` | Allow resizing |
| `Closeable` | `Bool` | Show close button |
| `Minimizable` | `Bool` | Allow minimizing |
| `Decorations` | `Bool` | Show title bar and borders |
| `Transparent` | `Bool` | Transparent window background |
| `Blur` | `Bool` | Blur window background |
| `Level` | `WindowLevel` | Stacking level |
| `ExitOnCloseRequest` | `Bool` | Whether closing exits the app |
| `ScaleFactor` | `Float` | DPI scale override |
| `WindowTheme` | `Theme` | Per-window theme |
| `A11y` | `A11y` | Accessibility overrides |

`WindowLevel` variants: `Normal`, `AlwaysOnTop`, `AlwaysOnBottom`.

### Multi-window

Return multiple windows from `view`:

```gleam
fn view(model: Model) -> List(Node) {
  let windows = [
    ui.window("main", [window.Title("App")], [main_content(model)]),
  ]

  case model.show_settings {
    True -> [
      ..windows,
      ui.window("settings", [
        window.Title("Settings"),
        window.ExitOnCloseRequest(False),
      ], [settings_content(model)]),
    ]
    False -> windows
  }
}
```

`ExitOnCloseRequest(False)` on secondary windows means closing
them removes the window without exiting the app. Window IDs must
be stable strings; changing the ID causes a close and re-open.

See the [App Lifecycle reference](app-lifecycle.md) for daemon
mode (keep running after all windows close) and for how the
runtime syncs window state.

## Sizing

Every widget that participates in layout has `Width` and `Height`
opts that control how much space it occupies. Four value forms
are supported via the `Length` type in `plushie/prop/length`:

| Variant | Behaviour |
|---|---|
| `Shrink` | Take only as much space as the content needs. Default for most widgets. |
| `Fill` | Take all available space in the parent container. |
| `FillPortion(Int)` | Take a proportional share of available space relative to siblings |
| `Fixed(Float)` | Exact pixel size |

`length.to_prop_value` panics on `Fixed` values less than `0.0` or
`FillPortion` values less than `1`. Both are programming errors, not
runtime conditions.

### How FillPortion works

When multiple siblings use `Fill` or `FillPortion(n)`, the
available space (after fixed-size and `Shrink` siblings are
measured) is divided proportionally. The numbers are relative
ratios:

```gleam
ui.row("layout", [row.Width(Fill)], [
  ui.container("sidebar", [container.Width(FillPortion(1))], [...]),
  ui.container("main", [container.Width(FillPortion(3))], [...]),
])
```

Sidebar gets 1/4 of the width, main gets 3/4. `FillPortion(1)`
plus `FillPortion(3)` is the same ratio as `FillPortion(2)` plus
`FillPortion(6)`.

`Fill` is shorthand for `FillPortion(1)`. Two `Fill` siblings
split space equally.

### Sizing resolution order

The layout engine processes siblings in this order:

1. **Fixed-size** children (`Fixed(n)`) are measured first.
2. **Shrink** children are measured at their intrinsic content
   size.
3. **Fill / FillPortion** children divide the remaining space.

A fixed-width sidebar always gets its pixels, a shrink button
takes what it needs, and fill containers expand to use whatever
is left.

### Constraints

`MaxWidth(Float)` and `MaxHeight(Float)` set upper bounds. A
`Fill` child with `MaxWidth(600.0)` expands to fill available
space but never exceeds 600 pixels. These are available on
`column`, `row`, `container`, and `keyed_column`.

## Padding

`plushie/prop/padding`

Padding is the space between a container's edges and its content.
The `Padding` record has four fields (`top`, `right`, `bottom`,
`left`) and three convenience constructors:

| Constructor | Result |
|---|---|
| `padding.all(16.0)` | 16 px on every side |
| `padding.xy(8.0, 16.0)` | 8 px top / bottom, 16 px left / right |
| `padding.none()` | 0 on every side |

Construct a per-side value directly with the record constructor:

```gleam
padding.Padding(top: 16.0, right: 8.0, bottom: 4.0, left: 8.0)
```

`padding.to_prop_value` always encodes all four sides and panics
on negatives.

Padding reduces the space available to children. A 200 px wide
container with `padding.all(16.0)` has 168 px of content space.

## Spacing

Spacing is the gap between sibling children inside a container.
Set via `Spacing(Float)` on `column`, `row`, `grid`,
`keyed_column`, and `pane_grid`:

```gleam
ui.column("items", [column.Spacing(12.0)], [
  ui.text_("a", "First"),    // 12 px gap below
  ui.text_("b", "Second"),   // 12 px gap below
  ui.text_("c", "Third"),    // no gap after the last child
])
```

Spacing applies between children, not before the first or after
the last. It does not interact with padding; they are independent.

## Alignment

`plushie/prop/alignment`

Alignment controls how children are positioned within a
container's available space. `Alignment` variants: `Left`,
`Center`, `Right`, `Top`, `Bottom`.

| Opt | Container | Valid values |
|---|---|---|
| `AlignX` | `column`, `container` | `Left` (default), `Center`, `Right` |
| `AlignY` | `row`, `container` | `Top` (default), `Center`, `Bottom` |

`column` aligns children horizontally (they already stack
vertically). `row` aligns children vertically (they already flow
horizontally). `container` supports both axes since it has a
single child.

The `Center(True)` opt on `container` is a shortcut that sets
both `AlignX(Center)` and `AlignY(Center)`.

## Layout containers

### column

`plushie/widget/column`. Arranges children vertically, top to
bottom.

| Opt | Type | Default | Purpose |
|---|---|---|---|
| `Spacing` | `Float` | `0.0` | Vertical gap between children |
| `Padding` | `Padding` | `none()` | Inner padding |
| `Width` | `Length` | `Shrink` | Column width |
| `Height` | `Length` | `Shrink` | Column height |
| `MaxWidth` | `Float` | — | Maximum width in pixels |
| `AlignX` | `Alignment` | `Left` | Horizontal alignment of children |
| `Clip` | `Bool` | `False` | Clip children that overflow |
| `Wrap` | `Bool` | `False` | Wrap children to next column on overflow |
| `A11y` | `A11y` | — | Accessibility overrides |

`Wrap(True)` enables multi-column flow layout. When children
exceed the column height, they wrap to a new column to the right
(like CSS `flex-wrap`).

### row

`plushie/widget/row`. Arranges children horizontally, left to
right.

| Opt | Type | Default | Purpose |
|---|---|---|---|
| `Spacing` | `Float` | `0.0` | Horizontal gap between children |
| `Padding` | `Padding` | `none()` | Inner padding |
| `Width` | `Length` | `Shrink` | Row width |
| `Height` | `Length` | `Shrink` | Row height |
| `MaxWidth` | `Float` | — | Maximum width in pixels |
| `AlignY` | `Alignment` | `Top` | Vertical alignment of children |
| `Clip` | `Bool` | `False` | Clip children that overflow |
| `Wrap` | `Bool` | `False` | Wrap children to next row on overflow |
| `A11y` | `A11y` | — | Accessibility overrides |

`Wrap(True)` enables multi-row flow layout. Useful for tag
clouds, toolbar buttons, or any content that should reflow at
different widths.

### container

`plushie/widget/container`. Single-child wrapper for styling,
scoping, and alignment.

| Opt | Type | Purpose |
|---|---|---|
| `Padding` | `Padding` | Inner padding |
| `Width` | `Length` | Container width |
| `Height` | `Length` | Container height |
| `MaxWidth` | `Float` | Maximum width |
| `MaxHeight` | `Float` | Maximum height |
| `AlignX` | `Alignment` | Horizontal child alignment |
| `AlignY` | `Alignment` | Vertical child alignment |
| `Center` | `Bool` | Center child in both axes |
| `Clip` | `Bool` | Clip child that overflows |
| `BgColor` | `Color` | Background colour |
| `BgGradient` | `Gradient` | Background gradient |
| `TextColor` | `Color` | Text colour for descendants |
| `Border` | `Border` | Border specification |
| `Shadow` | `Shadow` | Drop shadow |
| `Style` | `String` | Named style preset |
| `A11y` | `A11y` | Accessibility overrides |

Container style presets (`Style(String)` values):
`"transparent"`, `"rounded_box"`, `"bordered_box"`, `"dark"`,
`"primary"`, `"secondary"`, `"success"`, `"danger"`, `"warning"`.

Container serves three roles: **styling** (background, border,
shadow, text colour), **scoping** (named containers create ID
scopes for their children; see the
[Scoped IDs reference](scoped-ids.md)), and **alignment**
(positioning a child within available space).

### scrollable

`plushie/widget/scrollable`. Adds scroll bars when content
overflows. Give this widget an explicit string ID; renderer-side
scroll state is keyed by the ID and resets if the ID changes.

| Opt | Type | Purpose |
|---|---|---|
| `Width` | `Length` | Scrollable area width |
| `Height` | `Length` | Scrollable area height |
| `Direction` | `Direction` | Scroll axis (`Vertical` default, `Horizontal`, `Both`) |
| `Spacing` | `Float` | Gap between scrollbar and content |
| `ScrollbarWidth` | `Float` | Scrollbar track width |
| `ScrollbarMargin` | `Float` | Margin around scrollbar |
| `ScrollerWidth` | `Float` | Scroller handle width |
| `ScrollbarColor` | `Color` | Scrollbar track colour |
| `ScrollerColor` | `Color` | Scroller thumb colour |
| `Anchor` | `Anchor` | `AnchorStart` (default) or `AnchorEnd` |
| `OnScroll` | `Bool` | Emit `Scrolled` events with viewport data |
| `AutoScroll` | `Bool` | Auto-scroll to show new content |
| `A11y` | `A11y` | Accessibility overrides |

`AutoScroll(True)` is useful for chat-style interfaces where new
messages should scroll into view. Combine with `Anchor(AnchorEnd)`
to start scrolled to the bottom.

When `OnScroll(True)`, each `Widget(Scrolled(target, data))`
event carries a `ScrollData` record with `absolute_x`,
`absolute_y`, `relative_x`, `relative_y`, `bounds_width`,
`bounds_height`, `content_width`, `content_height`.

### keyed_column

`plushie/widget/keyed_column`. Like `column`, but uses each
child's ID as a diffing key for the renderer. Supports
`Spacing`, `Padding`, `Width`, `Height`, `MaxWidth`, `AlignX`,
`A11y`. Does not support `Clip` or `Wrap`.

Use `keyed_column` for dynamic lists where items are added,
removed, or reordered. A plain `column` diffs by position index,
so inserting at the top shifts every child's state down by one.
`keyed_column` matches by ID, preserving widget state (focus,
scroll position, cursor) regardless of position.

### stack

`plushie/widget/stack`. Layers children on top of each other on
the z-axis. First child is at the back, last child is at the
front.

| Opt | Type | Purpose |
|---|---|---|
| `Width` | `Length` | Stack width |
| `Height` | `Length` | Stack height |
| `Clip` | `Bool` | Clip children that overflow |
| `A11y` | `A11y` | Accessibility overrides |

Use for overlays, badges, loading spinners, or any situation
where elements need to be layered.

### grid

`plushie/widget/grid`. Arranges children in a grid.

| Opt | Type | Purpose |
|---|---|---|
| `NumColumns` | `Int` | Number of columns (fixed mode) |
| `Spacing` | `Float` | Gap between cells |
| `Width` | `Length` | Grid width |
| `Height` | `Length` | Grid height |
| `ColumnWidth` | `Length` | Width of each column |
| `RowHeight` | `Length` | Height of each row |
| `Fluid` | `Float` | Max cell width for fluid auto-wrap mode |
| `A11y` | `A11y` | Accessibility overrides |

Two modes: **fixed columns** (`NumColumns(3)`) and **fluid**
(`Fluid(200.0)`). In fluid mode the grid auto-wraps columns
based on available width, fitting as many cells of the specified
max width as possible.

### pin

`plushie/widget/pin`. Positions a child at exact pixel
coordinates within a container.

| Opt | Type | Purpose |
|---|---|---|
| `X` | `Float` | X position in pixels |
| `Y` | `Float` | Y position in pixels |
| `Width` | `Length` | Pin container width |
| `Height` | `Length` | Pin container height |
| `A11y` | `A11y` | Accessibility overrides |

Pin does not participate in flow layout; the child is positioned
absolutely. Useful for tooltips, popovers, or custom positioning.

### floating

`plushie/widget/floating`. Applies translate and scale transforms
to a child without removing it from flow layout.

| Opt | Type | Purpose |
|---|---|---|
| `TranslateX` | `Float` | Horizontal translation in pixels |
| `TranslateY` | `Float` | Vertical translation in pixels |
| `Scale` | `Float` | Scale factor |
| `Width` | `Length` | Container width |
| `Height` | `Length` | Container height |
| `A11y` | `A11y` | Accessibility overrides |

Unlike `pin`, floating applies visual transforms while the child
still occupies its original space. The transform is visual only.

### responsive

`plushie/widget/responsive`. Adapts layout based on available size
by emitting resize events.

| Opt | Type | Purpose |
|---|---|---|
| `Width` | `Length` | Container width (default `Fill`) |
| `Height` | `Length` | Container height (default `Fill`) |
| `A11y` | `A11y` | Accessibility overrides |

When the responsive container's size changes, it emits
`Widget(Resize(target, width, height))`. Use this in `update` to
store the measured size and adjust your `view` based on it (for
example, switching from a sidebar layout to a stacked layout
below a certain width).

### space

`plushie/widget/space`. Invisible spacer widget. No children, no
visual output.

| Opt | Type | Purpose |
|---|---|---|
| `Width` | `Length` | Space width |
| `Height` | `Length` | Space height |
| `A11y` | `A11y` | Accessibility overrides |

Use for explicit gaps, alignment tricks, or pushing siblings
apart in a row or column.

### pane_grid

`plushie/widget/pane_grid`. Resizable tiled panes with split,
close, swap, and drag. Give this widget an explicit ID; it holds
renderer-side state for pane sizes and arrangement.

| Opt | Type | Purpose |
|---|---|---|
| `Panes` | `List(String)` | Pane identifiers |
| `Spacing` | `Float` | Space between panes |
| `Width` | `Length` | Grid width |
| `Height` | `Length` | Grid height |
| `MinSize` | `Float` | Minimum pane size in pixels |
| `Leeway` | `Float` | Grabbable area around dividers |
| `DividerColor` | `Color` | Divider colour |
| `DividerWidth` | `Float` | Divider thickness |
| `SplitAxis` | `String` | `"horizontal"` or `"vertical"` |
| `EventRate` | `Int` | Max events/sec for coalescable pane events |
| `A11y` | `A11y` | Accessibility overrides |

Pane grid events (under `Widget(...)`): `PaneClicked`,
`PaneResized`, `PaneDragged`, `PaneFocusCycle`. See the
[Events reference](events.md) for field shapes. Manage pane
layout with commands: `command.pane_split`, `command.pane_close`,
`command.pane_swap`, `command.pane_maximize`,
`command.pane_restore`.

## Composition patterns

### Sidebar + content

```gleam
ui.row("layout", [row.Width(Fill), row.Height(Fill)], [
  ui.column("sidebar", [
    column.Width(Fixed(200.0)),
    column.Height(Fill),
    column.Padding(padding.all(8.0)),
  ], [
    // fixed-width sidebar
  ]),
  ui.container("main", [
    container.Width(Fill),
    container.Height(Fill),
    container.Padding(padding.all(16.0)),
  ], [
    // content fills remaining space
  ]),
])
```

### Header / body / footer

```gleam
ui.column("page", [column.Width(Fill), column.Height(Fill)], [
  ui.row("header", [row.Padding(padding.all(8.0))], [
    // header (shrinks to content)
  ]),
  ui.container("body", [
    container.Width(Fill),
    container.Height(Fill),
  ], [
    // body fills remaining space
  ]),
  ui.row("footer", [row.Padding(padding.all(8.0))], [
    // footer (shrinks to content)
  ]),
])
```

### Centred content

```gleam
ui.container("hero", [
  container.Width(Fill),
  container.Height(Fill),
  container.Center(True),
], [
  ui.text_("msg", "Centred in both axes"),
])
```

### Scrollable list

```gleam
ui.scrollable("items", [
  scrollable.Height(Fixed(400.0)),
], [
  ui.keyed_column("list", [keyed_column.Spacing(4.0)],
    list.map(model.items, fn(item) {
      ui.container(item.id, [container.Padding(padding.all(8.0))], [
        ui.text_(item.id <> "-name", item.name),
      ])
    }),
  ),
])
```

### Overlay / badge

```gleam
ui.stack("hero", [], [
  ui.container("back", [container.Width(Fill), container.Height(Fill)], [
    // main content underneath
  ]),
  ui.pin("badge", [pin.X(10.0), pin.Y(10.0)], [
    ui.text("label", "NEW", [text.Size(10.0)]),
  ]),
])
```

## See also

- [Built-in Widgets reference](built-in-widgets.md) - full widget
  catalog including non-layout widgets
- [Themes and Styling reference](themes-and-styling.md) -
  `Color`, `Border`, `Shadow`, `Gradient`, and the container
  style presets in detail
- [Scoped IDs reference](scoped-ids.md) - how named containers
  create ID scopes
- [Events reference](events.md) - `Scrolled` and `Resize` event
  shapes
- [Commands reference](commands.md) - window operations and pane
  grid management commands
