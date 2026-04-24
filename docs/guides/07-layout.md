# Layout

The pad from chapter 6 works, but the layout could use some attention. The
sidebar, editor, and preview panes are functional but not well-proportioned,
and the spacing is inconsistent. In this chapter we will fix that by learning
Plushie's layout system.

We will cover the layout containers you use every day, how sizing works, and
how spacing and alignment give your UI structure. The full container catalog
is in the [Windows and Layout reference](../reference/windows-and-layout.md).
Here we focus on the ones that matter most.

## Layout containers

Plushie provides several layout containers. These are the workhorses:

### column

`plushie/widget/column`. Stacks children vertically, top to bottom. The
main opts are `Spacing` (gap between children), `Padding` (space inside
the container), `Width`, `Height`, and `AlignX`.

```gleam
import plushie/prop/padding
import plushie/ui
import plushie/widget/column

ui.column("numbers", [column.Spacing(12.0), column.Padding(padding.all(16.0))], [
  ui.text_("one", "First"),
  ui.text_("two", "Second"),
  ui.text_("three", "Third"),
])
```

### row

`plushie/widget/row`. Stacks children horizontally, left to right. Same
opts as `column`, except with `AlignY` instead of `AlignX`. Also supports
`Wrap(True)` to flow children to the next line when they overflow.

```gleam
import plushie/ui
import plushie/widget/row

ui.row("actions", [row.Spacing(8.0)], [
  ui.button_("a", "Left"),
  ui.button_("b", "Right"),
])
```

### container

`plushie/widget/container`. A single-child wrapper. Use it for styling
(background, border, shadow), for scoping (named containers give children
a scope for event IDs), or for alignment and padding.

```gleam
import plushie/prop/color
import plushie/prop/padding
import plushie/ui
import plushie/widget/container

ui.container("card", [
  container.Padding(padding.all(16.0)),
  container.BgColor(color.hex("#f5f5f5")),
], [
  ui.text_("content", "Inside the card"),
])
```

### scrollable

`plushie/widget/scrollable`. Adds scroll bars when content overflows.
`Direction` can be `Vertical` (default), `Horizontal`, or `Both`. Set a
fixed height to constrain the scrollable area.

```gleam
import gleam/list
import plushie/prop/direction.{Vertical}
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/column
import plushie/widget/scrollable

ui.scrollable("list", [scrollable.Height(Fixed(300.0)), scrollable.Direction(Vertical)], [
  ui.column("items", [column.Spacing(4.0)],
    list.map(model.items, fn(item) { ui.text_(item.id, item.name) }),
  ),
])
```

`scrollable` also supports `AutoScroll(True)` for chat-like behaviour
where new content scrolls into view automatically.

## Sizing: fill, shrink, and fixed

Every widget that participates in layout has `Width` and `Height` opts.
They accept four kinds of values from `plushie/prop/length`:

| Variant | Behaviour |
|---|---|
| `Fill` | Take all available space |
| `Shrink` | Take only as much as the content needs |
| `FillPortion(Int)` | Take a proportional share of available space |
| `Fixed(Float)` | Exact pixel size |

Most widgets default to `Shrink`. Layout containers grow to fit their
children.

### Fill vs Shrink

In a `row`, a `Fill` child takes all remaining space after `Shrink`
children are measured:

```gleam
import plushie/prop/length.{Fill}
import plushie/ui
import plushie/widget/row
import plushie/widget/text_input

ui.row("search-bar", [row.Width(Fill)], [
  ui.text_input("search", model.query, [
    text_input.Width(Fill),
    text_input.Placeholder("Search..."),
  ]),
  ui.button_("go", "Go"),
])
```

The button shrinks to fit its label. The text input fills the rest.

### FillPortion

When multiple children use `Fill`, they share space equally. Use
`FillPortion(n)` for proportional splits:

```gleam
import plushie/prop/length.{Fill, FillPortion}
import plushie/ui
import plushie/widget/container
import plushie/widget/row

ui.row("layout", [row.Width(Fill)], [
  ui.container("sidebar", [container.Width(FillPortion(1))], [
    ui.text_("nav", "Sidebar"),
  ]),
  ui.container("main", [container.Width(FillPortion(3))], [
    ui.text_("content", "Main content"),
  ]),
])
```

The sidebar gets 1/4 of the width, the main area gets 3/4. The numbers
are relative. `FillPortion(1)` and `FillPortion(3)` is the same ratio
as `FillPortion(2)` and `FillPortion(6)`. `Fill` is shorthand for
`FillPortion(1)`.

### Fixed size

A `Fixed(n)` length means exact pixels:

```gleam
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/container

ui.container("icon", [container.Width(Fixed(48.0)), container.Height(Fixed(48.0))], [
  ui.text_("x", "X"),
])
```

## Spacing and padding

**Spacing** is the gap between sibling children inside a container:

```gleam
import plushie/ui
import plushie/widget/column

ui.column("list", [column.Spacing(12.0)], [
  ui.text_("a", "First"),   // 12 px gap below
  ui.text_("b", "Second"),  // 12 px gap below
  ui.text_("c", "Third"),   // no gap after the last child
])
```

**Padding** is the space between a container's edges and its content.
The `Padding` record lives in `plushie/prop/padding` and provides three
convenience constructors:

```gleam
import plushie/prop/padding

// Uniform: 16 px on every side
padding.all(16.0)

// Vertical / horizontal: 8 px top / bottom, 16 px left / right
padding.xy(8.0, 16.0)

// No padding
padding.none()
```

For per-side values, use the record constructor directly:

```gleam
padding.Padding(top: 16.0, right: 12.0, bottom: 8.0, left: 12.0)
```

All four sides are always encoded. Negatives panic at build time.

## Alignment

`AlignX` and `AlignY` control how children are positioned within a
container's available space. Values come from `plushie/prop/alignment`:

| Opt | Container | Valid values |
|---|---|---|
| `AlignX` | `column`, `container` | `Left` (default), `Center`, `Right` |
| `AlignY` | `row`, `container` | `Top` (default), `Center`, `Bottom` |

```gleam
import plushie/prop/alignment.{Center}
import plushie/prop/length.{Fill, Fixed}
import plushie/ui
import plushie/widget/container

ui.container("hero", [
  container.Width(Fill),
  container.Height(Fixed(200.0)),
  container.AlignX(Center),
  container.AlignY(Center),
], [
  ui.text_("centered", "I am centred"),
])
```

The `Center(True)` opt on `container` is a shortcut that sets both axes
at once:

```gleam
ui.container("hero", [
  container.Width(Fill),
  container.Height(Fill),
  container.Center(True),
], [
  ui.text_("centered", "Centred both ways"),
])
```

## Max-width constraints

`MaxWidth(Float)` sets an upper bound on a `Fill` or `FillPortion`
container. Useful for keeping a reading column from stretching too wide
on a large window:

```gleam
ui.container("article", [
  container.Width(Fill),
  container.MaxWidth(720.0),
  container.Center(True),
], [
  // content expands with the window up to 720 px, then stops
])
```

`column`, `row`, `container`, and `keyed_column` all support `MaxWidth`.
`container` additionally supports `MaxHeight`.

## Other layout tools

These containers cover specialised needs. We will not use them in the
pad right now, but they are good to know about:

- **stack** layers children on top of each other (z-axis). Useful for
  overlays, badges, and loading spinners.
- **grid** CSS-like grid layout. Supports fixed column count
  (`NumColumns(3)`) or fluid mode (`Fluid(200.0)`) that auto-wraps.
- **pin** positions a child at exact `(x, y)` pixel coordinates.
- **floating** applies translate and scale transforms to a child.
- **responsive** adapts layout based on available size.
- **space** explicit empty space with configurable width and height.

See the [Windows and Layout reference](../reference/windows-and-layout.md)
for full prop tables on each.

## Applying it: the polished pad layout

With these layout tools, refine the pad into a clean three-pane layout.
Fix the sidebar width, give the editor and preview a proportional split,
and tighten up the toolbar and event log:

```gleam
import gleam/int
import gleam/list
import plushie/prop/font.{Monospace}
import plushie/prop/length.{Fill, FillPortion, Fixed}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/scrollable
import plushie/widget/text
import plushie/widget/text_editor
import plushie/widget/window

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("Plushie Pad")], [
      ui.column("root", [
        column.Width(Fill),
        column.Height(Fill),
        column.Spacing(0.0),
      ], [
        // Main area: sidebar + editor + preview
        ui.row("main-area", [
          row.Width(Fill),
          row.Height(Fill),
          row.Spacing(0.0),
        ], [
          file_list(model),
          ui.text_editor("editor", model.source, [
            text_editor.Width(FillPortion(1)),
            text_editor.Height(Fill),
            text_editor.HighlightSyntax("gleam"),
            text_editor.Font(Monospace),
          ]),
          ui.container("preview", [
            container.Width(FillPortion(1)),
            container.Height(Fill),
            container.Padding(padding.all(12.0)),
          ], [
            // ...preview content...
          ]),
        ]),

        // Toolbar: compact, horizontal
        ui.row("toolbar", [
          row.Padding(padding.xy(4.0, 8.0)),
          row.Spacing(8.0),
        ], [
          ui.button_("save", "Save"),
          ui.checkbox("auto-save", "Auto-save", model.auto_save, []),
        ]),

        // Event log: fixed height at the bottom
        ui.scrollable("log", [scrollable.Height(Fixed(100.0))], [
          ui.column("entries", [
            column.Spacing(2.0),
            column.Padding(padding.xy(2.0, 8.0)),
          ],
            list.index_map(model.event_log, fn(entry, i) {
              ui.text("log-" <> int.to_string(i), entry, [
                text.Size(11.0),
                text.Font(Monospace),
              ])
            }),
          ),
        ]),
      ]),
    ]),
  ]
}
```

Key changes. The root `column` uses `Spacing(0.0)` to eliminate unwanted
gaps between the main area, toolbar, and log. The sidebar uses a fixed
width (defined in `file_list`). The editor and preview each take
`FillPortion(1)`, giving them an equal split of the remaining width.
The toolbar uses `padding.xy(4.0, 8.0)` (vertical, horizontal) for a
compact look. The event log has a fixed height and tighter text. Each
section manages its own internal spacing.

The update logic is unchanged from chapter 6. Only the view and helper
functions changed.

## Verify it

Test that the three-pane layout renders with the expected structure:

```gleam
import plushie/testing

pub fn three_pane_layout_test() {
  let t = testing.start(app, [])
  testing.assert_exists(t, "#file-scroll")
  testing.assert_exists(t, "#editor")

  // Typing in the editor still works after layout changes
  testing.type_text(t, "#editor", "ui.text_(\"test\", \"hello\")")
  testing.click(t, "#save")
  testing.assert_text(t, "#preview/test", "hello")
  testing.stop(t)
}
```

This verifies the layout did not break the editing flow. The editor,
save button, and preview pane all still work together.

## Try it

Write a layout experiment in your pad:

- Build a sidebar plus content layout using `row` with a fixed-width
  `column` and a `Fill` container.
- Try different `FillPortion(n)` ratios. Give one pane `2` and another
  `1` to see the 2:1 split.
- Nest a `scrollable` inside a fixed-height container. Add enough items
  to trigger scrolling.
- Experiment with `AlignX(Center)` and `AlignY(Bottom)` on a container.
- Try `row` with `row.Wrap(True)` and enough buttons to overflow the
  width.

In the next chapter, we will style the pad with themes, colours, and
per-widget styling to make it look polished.

---

Next: [Styling](08-styling.md)
