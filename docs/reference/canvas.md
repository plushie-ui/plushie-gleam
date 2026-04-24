# Canvas

The canvas widget lets you draw custom 2D graphics: shapes,
paths, transforms, gradients, text, and interactive elements. It
is the escape hatch when the built-in widget catalog does not
cover what you need to render.

## Canvas widget

`plushie/widget/canvas`

Declare a canvas by giving it a fixed or flexible size and adding
layers of shapes. Each layer is a named list of shape values.
Layers render in declaration order (first at the back).

```gleam
import plushie/canvas/shape
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/canvas

ui.canvas("drawing", Fixed(400.0), Fixed(300.0), [
  canvas.Layer("background", [
    shape.rect(0.0, 0.0, 400.0, 300.0, [shape.Fill("#ffffff")]),
  ]),
  canvas.Layer("content", [
    shape.circle(200.0, 150.0, 50.0, [shape.Fill("#3b82f6")]),
    shape.text("label", 200.0, 250.0, [
      shape.Size(14.0),
      shape.AlignX("center"),
    ]),
  ]),
])
```

### Canvas opts

| Opt | Type | Purpose |
|---|---|---|
| `Layers` | `Dict(String, List(PropValue))` | All layers as a dict |
| `Shapes` | `List(PropValue)` | Shorthand for a single unnamed layer |
| `Layer` | `String`, `List(PropValue)` | Add a single named layer (callable repeatedly) |
| `Background` | `Color` | Colour drawn beneath all layers |
| `Interactive` | `Bool` | Enable pointer event emission for interactive elements |
| `OnPress` | `Bool` | Enable canvas-level press events |
| `OnRelease` | `Bool` | Enable canvas-level release events |
| `OnMove` | `Bool` | Enable canvas-level move events |
| `OnScroll` | `Bool` | Enable canvas-level scroll events |
| `Alt` | `String` | Accessible name |
| `Description` | `String` | Longer description |
| `Role` | `String` | ARIA role |
| `ArrowMode` | `String` | `"focus"` or `"scroll"` (arrow key behaviour) |
| `EventRate` | `Int` | Max events / sec for coalescable pointer events |
| `A11y` | `A11y` | Accessibility overrides |

## Shapes

`plushie/canvas/shape`

Every shape is a plain `PropValue` dict produced by a constructor
function. All shape constructors take a final `List(ShapeOpt)` for
style and positioning.

### Basic shapes

| Function | Arguments |
|---|---|
| `shape.rect(x, y, w, h, opts)` | Rectangle at `(x, y)` with `w * h` |
| `shape.circle(x, y, r, opts)` | Circle centred at `(x, y)` with radius `r` |
| `shape.line(x1, y1, x2, y2, opts)` | Line segment |
| `shape.text(id, x, y, opts)` | Text anchored at `(x, y)`; use `shape.Content(String)` via `shape.set_text` or the `Size`, `Font`, `AlignX`, `AlignY` opts |
| `shape.path(commands, opts)` | Freeform path built from `PathCommand` variants |
| `shape.image(handle, x, y, w, h, opts)` | Image handle previously registered via `command.create_image` |
| `shape.svg(source, x, y, w, h)` | SVG string or path |

### Shape opts

`ShapeOpt` variants apply to every shape:

| Variant | Purpose |
|---|---|
| `Fill(String)` | Fill colour (hex string) |
| `Stroke(PropValue)` | Stroke descriptor built with `shape.stroke` |
| `Opacity(Float)` | 0.0-1.0 |
| `FillRule(String)` | `"nonzero"` or `"evenodd"` |
| `GradientFill(PropValue)` | Gradient built with `shape.linear_gradient` |
| `Size(Float)` | Text size |
| `Font(String)` | Font family name for text |
| `AlignX(String)` | `"left"`, `"center"`, `"right"` |
| `AlignY(String)` | `"top"`, `"center"`, `"bottom"` |
| `Rotation(Float)` | Degrees |
| `Radius(CornerRadius)` | Corner radius for rectangles (uniform or per-corner) |
| `X(Float)`, `Y(Float)` | Positional offset for group shapes (desugars to translate) |
| `Transforms(List(PropValue))` | Explicit transform list for groups |
| `ClipRect(PropValue)` | Clip rectangle for groups |

`CornerRadius` variants: `Uniform(Float)`, `PerCorner(top_left,
top_right, bottom_right, bottom_left)`.

### Strokes

`shape.stroke(color, width, opts)` produces a stroke descriptor:

```gleam
import plushie/canvas/shape

shape.stroke("#111111", 2.0, [
  shape.StrokeCapOpt(shape.RoundCap),
  shape.StrokeJoinOpt(shape.RoundJoin),
  shape.StrokeDashOpt(segments: [4.0, 2.0], offset: 0.0),
])
```

`StrokeCap` variants: `ButtCap`, `RoundCap`, `SquareCap`.
`StrokeJoin` variants: `MiterJoin`, `RoundJoin`, `BevelJoin`.

### Paths

Build a path from a list of `PathCommand` values:

| Variant | Purpose |
|---|---|
| `MoveTo(x, y)` | Move pen to `(x, y)` without drawing |
| `LineTo(x, y)` | Draw a line to `(x, y)` |
| `BezierTo(cp1x, cp1y, cp2x, cp2y, x, y)` | Cubic bezier to `(x, y)` |
| `QuadraticTo(cpx, cpy, x, y)` | Quadratic bezier |
| `Arc(x, y, radius, start_angle, end_angle)` | Arc in radians |
| `ArcTo(x1, y1, x2, y2, radius)` | Arc connecting two points |
| `Ellipse(cx, cy, rx, ry, rotation, start_angle, end_angle)` | Ellipse arc |
| `RoundedRect(x, y, w, h, radius)` | Rounded rectangle (closed path) |
| `Close` | Close the current sub-path back to its starting point |

```gleam
shape.path(
  [
    shape.MoveTo(10.0, 10.0),
    shape.LineTo(90.0, 10.0),
    shape.BezierTo(90.0, 50.0, 50.0, 90.0, 10.0, 90.0),
    shape.Close,
  ],
  [shape.Fill("#3b82f6")],
)
```

## Transforms

Transforms produce `PropValue` values that compose via
`shape.Transforms` on a group:

| Function | Purpose |
|---|---|
| `shape.translate(x, y)` | Translate by `(x, y)` |
| `shape.rotate(degrees)` | Rotate about the group origin |
| `shape.rotate_radians(radians)` | Rotate in radians |
| `shape.scale(x, y)` | Non-uniform scale |
| `shape.scale_uniform(factor)` | Uniform scale |
| `shape.clip(x, y, w, h)` | Rectangular clip region |

Apply them via a group:

```gleam
shape.group(
  [
    shape.circle(0.0, 0.0, 20.0, [shape.Fill("#3b82f6")]),
    shape.rect(30.0, -10.0, 40.0, 20.0, [shape.Fill("#ef4444")]),
  ],
  [
    shape.Transforms([
      shape.translate(100.0, 100.0),
      shape.rotate(45.0),
    ]),
  ],
)
```

## Groups

| Function | Purpose |
|---|---|
| `shape.group(children, opts)` | Non-interactive group (pure visual nesting) |
| `shape.interactive_group(id, children, opts, interactive_opts)` | Group that participates in pointer and keyboard events |

`interactive_group` takes an extra list of `InteractiveOpt`:

| Variant | Purpose |
|---|---|
| `OnClick(Bool)`, `OnHover(Bool)` | Enable click / hover tracking |
| `Draggable(Bool)` | Enable drag events |
| `DragAxis(String)` | `"x"`, `"y"`, or `"both"` |
| `DragBounds(x_min, x_max, y_min, y_max)` | Clamp drag position |
| `Cursor(String)` | Mouse cursor over the group |
| `HoverStyle(PropValue)`, `PressedStyle(PropValue)`, `FocusStyle(PropValue)` | Visual state overrides |
| `ShowFocusRing(Bool)`, `FocusRingRadius(Float)` | Focus-ring rendering |
| `Tooltip(String)` | Tooltip text shown on hover |
| `HitRect(x, y, w, h)` | Explicit hit-test rectangle |
| `Focusable(Bool)` | Include in the canvas's keyboard focus chain |
| `A11y(PropValue)` | Accessibility overrides (encoded A11y value) |

## Gradients

`shape.linear_gradient(from_x, from_y, to_x, to_y, stops)` builds
a gradient fill usable via `GradientFill`:

```gleam
let fill = shape.linear_gradient(
  from_x: 0.0,
  from_y: 0.0,
  to_x: 400.0,
  to_y: 300.0,
  stops: [#(0.0, "#3b82f6"), #(1.0, "#1d4ed8")],
)

shape.rect(0.0, 0.0, 400.0, 300.0, [shape.GradientFill(fill)])
```

Stops are `#(offset, hex_color)` tuples where offset is 0.0-1.0.

## Element-level events

Interactive groups emit events identified by their `InteractiveId`
on the target's `id` field; the canvas's own ID appears in the
`target.scope` chain. The event types are the standard
`WidgetEvent` variants:

| Event (under `Widget(...)`) | When it fires |
|---|---|
| `Click` | Interactive group was clicked |
| `Press`, `Release` | Pointer button down / up inside the group |
| `Enter`, `Exit` | Pointer entered / left the hit rectangle |
| `DoubleClick` | Double-click detected |
| `Drag`, `DragEnd` | During and after a drag operation |
| `Focused`, `Blurred` | Group gained / lost keyboard focus |
| `WidgetKeyPress`, `WidgetKeyRelease` | Key events routed to the focused group |

The canvas widget itself emits the canvas-level pointer events
(`Press`, `Release`, `Move`, `Scroll`, `Enter`, `Exit`) when the
corresponding `OnPress` / `OnRelease` / `OnMove` / `OnScroll`
opts are set.

## Accessibility

Pass text alternatives through the canvas opts (`Alt`,
`Description`, `Role`) and per-element via
`InteractiveOpt.A11y`. The canvas widget supports keyboard
navigation; `ArrowMode("focus")` moves focus between interactive
elements with arrow keys, `ArrowMode("scroll")` scrolls the
canvas instead. See the
[Accessibility reference](accessibility.md) for role vocabulary
and the accessible name computation rules.

## Animating canvas props

Shape props are not directly animated by the renderer animation
system; shapes are plain `PropValue` data reconstructed each
render. Animate a canvas by deriving shape coordinates from your
model and stepping the model on an
`subscription.on_animation_frame` tick (see
[Animation reference](animation.md), SDK-side tweens).

Canvas widgets themselves support the standard animated widget
props (opacity, scale, translate) through container widgets
around them.

## See also

- [Built-in Widgets reference](built-in-widgets.md) - the canvas
  widget in the broader catalog
- [Animation reference](animation.md) - SDK-side tweens for
  driving canvas coordinates
- [Events reference](events.md) - element-level event shapes
- [Commands reference](commands.md) - `command.focus`
  targeting canvas elements by scoped path
- [Accessibility reference](accessibility.md) - canvas keyboard
  navigation and focus rings
