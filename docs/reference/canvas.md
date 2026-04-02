# Canvas

The canvas system provides 2D drawing with typed shape functions,
transforms, interactive groups, and accessibility support.

For a narrative introduction, see the [Canvas guide](../guides/12-canvas.md).

## Canvas widget

```gleam
ui.canvas("chart", [canvas.Width(Px(400)), canvas.Height(Px(200))], [
  ui.layer("background", [...]),
  ui.layer("data", [...]),
])
```

| Prop | Default | Purpose |
|---|---|---|
| `Width` | `Fill` | Canvas width |
| `Height` | `Px(200)` | Canvas height |
| `OnPress` | `False` | Emit `WidgetPress` events |
| `OnRelease` | `False` | Emit `WidgetRelease` events |
| `OnMove` | `False` | Emit `WidgetMove` events |
| `OnScroll` | `False` | Emit `WidgetScroll` events |

## Shapes

All shapes are functions in `plushie/canvas/shape`:

| Function | Required args | Key options |
|---|---|---|
| `rect` | x, y, w, h | `Fill`, `Stroke`, `Opacity`, `Radius` |
| `circle` | x, y, r | `Fill`, `Stroke`, `Opacity` |
| `line` | x1, y1, x2, y2 | `Stroke`, `Opacity` |
| `text` | x, y, content | `Fill`, `Size`, `Font` |
| `path` | commands | `Fill`, `Stroke`, `FillRule` |
| `image` | source, x, y, w, h | `Rotation`, `Opacity` |
| `svg` | source, x, y, w, h | |

## Path commands

`move_to`, `line_to`, `bezier_to`, `quadratic_to`, `arc`, `arc_to`,
`ellipse`, `rounded_rect`, `close`.

## Transforms

Apply to groups only: `translate`, `rotate` (degrees by default),
`rotate_radians`, `scale`.

```gleam
shape.group("rotated", [shape.X(100.0), shape.Y(50.0)], [
  shape.rotate(45.0),
  rect(0.0, 0.0, 40.0, 40.0, [shape.Fill("#ef4444")]),
])
```

`rotate` accepts degrees by default. Use `rotate_radians` for radians.

## Interactive groups

| Prop | Purpose |
|---|---|
| `OnClick(True)` | Enable `WidgetClick` events |
| `OnHover(True)` | Enable `WidgetEnter`/`WidgetExit` events |
| `Draggable(True)` | Enable drag events |
| `Focusable(True)` | Add to Tab order |
| `Cursor(Pointer)` | Mouse cursor on hover |
| `HoverStyle([...])` | Visual override on hover |
| `PressedStyle([...])` | Visual override while pressed |

## Canvas events

Canvas-level events use the unified pointer model. Mouse, touch, and pen
input all produce the same event types (`WidgetPress`, `WidgetRelease`,
`WidgetMove`, `WidgetScroll`). The `pointer` field identifies the device.

Element-level events arrive as standard scoped events:

```gleam
WidgetClick(id: "handle", scope: ["my-canvas", ..], ..) -> ...
```

## See also

- `plushie/canvas/shape` - all builder functions
- [Canvas guide](../guides/12-canvas.md)
- [Accessibility reference](accessibility.md)
