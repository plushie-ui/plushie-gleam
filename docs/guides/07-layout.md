# Layout

Plushie provides several layout containers. These are the workhorses.

## Layout containers

### column

Stacks children vertically, top to bottom. Accepts `Spacing`, `Padding`,
`Width`, `Height`, and `AlignX`.

```gleam
ui.column("", "", [column.Spacing(12), column.Padding(16)], [
  ui.text("one", "First"),
  ui.text("two", "Second"),
])
```

### row

Stacks children horizontally, left to right. Same props as `column`, plus
`AlignY`. Also supports `Wrap(True)` to flow children to the next line
when they overflow.

### container

A single-child wrapper. Use it for styling (background, border, shadow),
for scoping (gives children a named ID scope), or for alignment and padding.

### scrollable

Adds scroll bars when content overflows. Direction can be `Vertical`
(default), `Horizontal`, or `Both`. Set a fixed height to constrain the
scrollable area.

## Sizing: fill, shrink, and fixed

Every widget has `Width` and `Height` props. They accept four kinds of
values from `plushie/prop/length`:

| Value | Behaviour |
|---|---|
| `Fill` | Take all available space |
| `Shrink` | Take only as much as the content needs |
| `FillPortion(n)` | Take a proportional share of available space |
| `Px(n)` | Exact pixel size |

### fill_portion

When multiple children use `Fill`, they share space equally. Use
`FillPortion(n)` for proportional splits:

```gleam
ui.row("", "", [row.Width(Fill)], [
  ui.container("sidebar", [container.Width(FillPortion(1))], [...]),
  ui.container("main", [container.Width(FillPortion(3))], [...]),
])
```

The sidebar gets 1/4 of the width, the main area gets 3/4.

## Spacing and padding

**Spacing** is the gap between sibling children. **Padding** is the space
between a container's edges and its content. Padding accepts several forms
from `plushie/prop/padding`:

```gleam
import plushie/prop/padding

// Uniform: 16px on all sides
column.Padding(16)

// Per-side
column.PaddingEach(padding.new(top: 16, bottom: 8, left: 12, right: 12))
```

## Alignment

`AlignX` and `AlignY` control how children are positioned within a
container. Values from `plushie/prop/alignment`:

| `AlignX` values | `AlignY` values |
|---|---|
| `Left` (default), `Center`, `Right` | `Top` (default), `Center`, `Bottom` |

## Other layout tools

- **stack** - layers children on top of each other (z-axis)
- **grid** - CSS-like grid layout with fixed columns or fluid auto-wrap
- **pin** - positions a child at exact `(x, y)` pixel coordinates
- **floating** - applies translate and scale transforms to a child
- **responsive** - adapts layout based on available size
- **space** - explicit empty space with configurable width and height

See the [Windows and Layout reference](../reference/windows-and-layout.md)
for full details.

---

Next: [Styling](08-styling.md)
