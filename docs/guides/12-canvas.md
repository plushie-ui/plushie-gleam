# Canvas

Canvas draws shapes on a 2D surface: rectangles, circles, lines, paths,
and text. Shapes can be grouped into interactive elements with click
handlers, hover effects, and accessibility annotations.

## Shapes

```gleam
import plushie/ui
import plushie/canvas/shape.{rect, circle, line, text, stroke}

ui.canvas("demo", [canvas.Width(Px(200)), canvas.Height(Px(100))], [
  ui.layer("bg", [
    rect(0.0, 0.0, 200.0, 100.0, [shape.Fill("#f0f0f0"), shape.Radius(8.0)]),
    circle(100.0, 50.0, 20.0, [shape.Fill("#3b82f6")]),
    line(10.0, 90.0, 190.0, 90.0, [shape.Stroke(stroke("#ccc", 1.0))]),
    text(100.0, 50.0, "Hello", [shape.Fill("#333"), shape.Size(14.0)]),
  ]),
])
```

## Interactive groups

Groups become interactive when you add event props:

```gleam
shape.group("my-btn", [
  shape.OnClick(True),
  shape.Cursor(Pointer),
  shape.HoverStyle([shape.Fill("#2563eb")]),
  shape.PressedStyle([shape.Fill("#1d4ed8")]),
], [
  rect(0.0, 0.0, 100.0, 36.0, [shape.Fill("#3b82f6"), shape.Radius(6.0)]),
  text(50.0, 11.0, "Save", [shape.Fill("#fff"), shape.Size(14.0)]),
])
```

## Transforms

Transforms apply to groups: `translate`, `rotate` (degrees by default),
and `scale`. Use `rotate_radians` for radians.

```gleam
shape.group("rotated", [shape.X(100.0), shape.Y(50.0)], [
  shape.rotate(45.0),
  rect(0.0, 0.0, 40.0, 40.0, [shape.Fill("#ef4444")]),
])
```

## Canvas events

Canvas-level events use the unified pointer model. Mouse, touch, and pen
input all produce the same event types (`WidgetPress`, `WidgetRelease`,
`WidgetMove`, `WidgetScroll`). The `pointer` field identifies the device.

Element-level events from interactive groups arrive as standard scoped
events:

```gleam
WidgetClick(id: "save", scope: ["save-canvas", ..], ..) -> save(model)
```

## Accessibility

Canvas elements need explicit accessibility annotations:

```gleam
shape.group("save-btn", [
  shape.OnClick(True),
  shape.Focusable(True),
  shape.A11y(a11y.new() |> a11y.role(a11y.Button) |> a11y.label("Save")),
], [...])
```

See the [Canvas reference](../reference/canvas.md) for the full shape
catalogue and path commands.

---

Next: [Custom Widgets](13-custom-widgets.md)
