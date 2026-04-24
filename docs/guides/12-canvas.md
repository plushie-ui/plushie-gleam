# Canvas

Canvas is a different paradigm from the widget tree. Instead of composing
layout containers and input widgets, you draw shapes on a 2D surface:
rectangles, circles, lines, paths, and text. Shapes can be grouped into
interactive elements with click handlers, hover effects, and
accessibility annotations.

In this chapter we build a custom save button for the pad: a styled,
interactive canvas widget that replaces the plain `ui.button("save", ...)`
call. Along the way we cover shapes, layers, transforms, gradients,
interactive groups, keyboard navigation, and an animated canvas driven
from the model. The full catalogue lives in the
[Canvas reference](../reference/canvas.md).

## Shapes

Shapes come from `plushie/canvas/shape`. Every constructor returns a
`PropValue` value that belongs inside a `canvas.Layer`. A minimal
canvas looks like this:

```gleam
import plushie/canvas/shape
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/canvas

ui.canvas("demo", Fixed(200.0), Fixed(100.0), [
  canvas.Layer("bg", [
    shape.rect(0.0, 0.0, 200.0, 100.0, [
      shape.Fill("#f0f0f0"),
      shape.Radius(shape.Uniform(8.0)),
    ]),
    shape.circle(100.0, 50.0, 20.0, [shape.Fill("#3b82f6")]),
    shape.line(10.0, 90.0, 190.0, 90.0, [
      shape.Stroke(shape.stroke("#cccccc", 1.0, [])),
    ]),
    shape.text(100.0, 50.0, "Hello", [
      shape.Size(14.0),
      shape.AlignX("center"),
      shape.Fill("#333333"),
    ]),
  ]),
])
```

`shape.rect` draws a rectangle, `shape.circle` a circle, `shape.line` a
line segment, and `shape.text` renders text at a position. Each accepts
a final `List(ShapeOpt)` for styling. `shape.Fill`, `shape.Stroke`, and
`shape.Opacity` cover the common cases.

### Strokes

`shape.stroke(color, width, opts)` builds a stroke descriptor. The opt
list accepts line cap, join, and dash segments. Pass the result to a
shape via `shape.Stroke(...)`.

```gleam
shape.stroke("#333333", 2.0, [shape.StrokeCapOpt(shape.RoundCap)])
shape.stroke("#333333", 2.0, [
  shape.StrokeDashOpt(segments: [5.0, 3.0], offset: 0.0),
])
```

### Gradients

`shape.linear_gradient(from, to, stops)` returns a fill usable through
`shape.GradientFill`:

```gleam
let fill =
  shape.linear_gradient(
    from: #(0.0, 0.0),
    to: #(100.0, 0.0),
    stops: [#(0.0, "#3b82f6"), #(1.0, "#1d4ed8")],
  )

shape.rect(0.0, 0.0, 100.0, 36.0, [
  shape.GradientFill(fill),
  shape.Radius(shape.Uniform(6.0)),
])
```

Stops are `#(offset, hex_color)` tuples where `offset` runs from 0.0 to
1.0.

### Paths

`shape.path(commands, opts)` draws an arbitrary outline from a list of
`PathCommand` variants:

```gleam
shape.path(
  [
    shape.MoveTo(10.0, 0.0),
    shape.LineTo(20.0, 20.0),
    shape.LineTo(0.0, 20.0),
    shape.Close,
  ],
  [shape.Fill("#22c55e")],
)
```

`MoveTo` moves the pen without drawing, `LineTo` adds a straight
segment, `BezierTo` adds a cubic bezier, and `Close` joins the current
sub-path back to its start. See the
[Canvas reference](../reference/canvas.md) for `QuadraticTo`, `Arc`,
`ArcTo`, `Ellipse`, and `RoundedRect`.

## Layers

Layers control drawing order. Earlier layers render behind later ones.
Add them by passing multiple `canvas.Layer` opts:

```gleam
import plushie/canvas/shape
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/canvas

ui.canvas("layered", Fixed(200.0), Fixed(100.0), [
  canvas.Layer("background", [
    shape.rect(0.0, 0.0, 200.0, 100.0, [shape.Fill("#f5f5f5")]),
  ]),
  canvas.Layer("foreground", [
    shape.circle(100.0, 50.0, 30.0, [shape.Fill("#3b82f6")]),
  ]),
])
```

A canvas with no named layers can use `canvas.Shapes(...)` for a single
flat list instead.

## Transforms

Transforms apply to groups, not individual shapes. Wrap shapes in
`shape.group(children, opts)` and pass a `shape.Transforms(...)` list:

```gleam
shape.group(
  [shape.rect(0.0, 0.0, 40.0, 40.0, [shape.Fill("#ef4444")])],
  [
    shape.Transforms([
      shape.translate(100.0, 50.0),
      shape.rotate(45.0),
    ]),
  ],
)
```

`shape.rotate` takes degrees. Use `shape.rotate_radians` when your math
is in radians. `shape.scale(x, y)` and `shape.scale_uniform(factor)`
cover scaling. As a shortcut, `shape.X(f)` and `shape.Y(f)` on a group
desugar to a leading translate.

A group can also clip its children to a rectangle via
`shape.ClipRect(shape.clip(x, y, w, h))`.

## Interactive groups

`shape.interactive_group(id, children, opts)` turns a group into a
clickable, hoverable, keyboard-reachable element. The `id` becomes the
element's `InteractiveId`; clicks on any child shape fire a
`Widget(Click(...))` event carrying that id.

```gleam
import plushie/canvas/shape

shape.interactive_group(
  "my-btn",
  [
    shape.rect(0.0, 0.0, 100.0, 36.0, [
      shape.Fill("#3b82f6"),
      shape.Radius(shape.Uniform(6.0)),
    ]),
    shape.text(50.0, 11.0, "Click me", [
      shape.Fill("#ffffff"),
      shape.Size(14.0),
      shape.AlignX("center"),
    ]),
  ],
  [shape.OnClick(True), shape.Cursor("pointer")],
)
```

`shape.HoverStyle(...)` and `shape.PressedStyle(...)` override visual
properties while the pointer is over or pressing the group. The
renderer applies them automatically; no event handling needed.

### Accessibility

Built-in widgets announce themselves to assistive tech automatically. A
canvas is a raw drawing surface, so you have to say what the group
represents. Pass `shape.Focusable(True)` to put the group in the
keyboard focus chain, and pass `shape.A11y(...)` with a role and label
if you want to override the defaults.

```gleam
shape.interactive_group(
  "save",
  [
    // shapes...
  ],
  [
    shape.OnClick(True),
    shape.Cursor("pointer"),
    shape.Focusable(True),
    shape.Tooltip("Save experiment"),
  ],
)
```

With `OnClick(True)` set the group infers a `"button"` role
automatically, and a tooltip propagates to the accessible label. See
the [Accessibility reference](../reference/accessibility.md) for the
full annotation vocabulary.

## Building the save button

Here is the full save button: a gradient-filled rectangle wrapped in an
interactive group with hover and press styles and keyboard focus.

```gleam
import gleam/dict
import plushie/canvas/shape
import plushie/node.{StringVal}
import plushie/prop/length.{Fixed}
import plushie/ui
import plushie/widget/canvas

fn save_button() {
  let fill =
    shape.linear_gradient(
      from: #(0.0, 0.0),
      to: #(100.0, 0.0),
      stops: [#(0.0, "#3b82f6"), #(1.0, "#2563eb")],
    )

  let hover = dict.from_list([#("fill", StringVal("#2563eb"))])
  let pressed = dict.from_list([#("fill", StringVal("#1d4ed8"))])

  ui.canvas("save-canvas", Fixed(100.0), Fixed(36.0), [
    canvas.Layer("button", [
      shape.interactive_group(
        "save",
        [
          shape.rect(0.0, 0.0, 100.0, 36.0, [
            shape.GradientFill(fill),
            shape.Radius(shape.Uniform(6.0)),
          ]),
          shape.text(50.0, 11.0, "Save", [
            shape.Fill("#ffffff"),
            shape.Size(14.0),
            shape.AlignX("center"),
          ]),
        ],
        [
          shape.OnClick(True),
          shape.Cursor("pointer"),
          shape.Focusable(True),
          shape.HoverStyle(node.DictVal(hover)),
          shape.PressedStyle(node.DictVal(pressed)),
        ],
      ),
    ]),
  ])
}
```

### Applying it: replace the plain save button

In the pad's `view`, swap the plain button for the canvas version:

```gleam
ui.row("actions", [row.Padding(padding.all(4.0)), row.Spacing(8.0)], [
  save_button(),
  ui.checkbox("auto-save", "Auto-save", model.auto_save, []),
])
```

The canvas button emits a regular click event. The `id` is `"save"`
(the `InteractiveId` from the group); `"save-canvas"` appears in the
target's scope because the canvas is the nearest named container.
Match on both to distinguish it from any other `"save"` widget in the
tree:

```gleam
import plushie/event.{EventTarget, Widget, Click}

case msg {
  Widget(Click(target: EventTarget(id: "save", scope: ["save-canvas", ..], ..))) ->
    #(compile_and_save(model), command.none())
  // ...
}
```

### Keyboard navigation

Focusable interactive groups join the canvas's own keyboard chain. Set
`canvas.ArrowMode("focus")` so arrow keys move focus between elements
within the canvas, and Space or Enter activates the focused group.
`ArrowMode("scroll")` is the alternative: arrow keys scroll the canvas
instead of moving focus, which is what you want for large canvases with
pannable content.

```gleam
ui.canvas("toolbar", Fixed(240.0), Fixed(48.0), [
  canvas.ArrowMode("focus"),
  canvas.Layer("buttons", [save_button_group(), clear_button_group()]),
])
```

## An animated canvas

Shape props are not tweened by the renderer animation system. Shapes
are plain data, rebuilt from the model on every render. To animate a
canvas, derive shape coordinates from your model and step the model on
every animation frame tick.

```gleam
import plushie/canvas/shape
import plushie/event.{System, AnimationFrame}
import plushie/prop/length.{Fixed}
import plushie/subscription
import plushie/ui
import plushie/widget/canvas

pub type Model {
  Model(angle: Float)
}

fn init(_opts) {
  #(Model(angle: 0.0), command.none())
}

fn subscriptions(_model) {
  [subscription.on_animation_frame()]
}

fn update(model: Model, msg) {
  case msg {
    System(AnimationFrame(..)) ->
      #(Model(angle: model.angle +. 2.0), command.none())
    _ -> #(model, command.none())
  }
}

fn view(model: Model) {
  ui.canvas("dial", Fixed(120.0), Fixed(120.0), [
    canvas.Layer("content", [
      shape.group(
        [shape.rect(-4.0, -40.0, 8.0, 40.0, [shape.Fill("#3b82f6")])],
        [
          shape.Transforms([
            shape.translate(60.0, 60.0),
            shape.rotate(model.angle),
          ]),
        ],
      ),
    ]),
  ])
}
```

`subscription.on_animation_frame()` emits an `AnimationFrame` system
event roughly every 16 ms while the window is visible. The `update`
bumps the angle, and `view` produces a new canvas with the rotated
group. The renderer applies the transform and redraws.

## Composing canvas with widgets

A canvas is just another widget in the tree. Mix it with anything:

```gleam
ui.column("root", [], [
  ui.row("actions", [row.Spacing(8.0)], [
    save_button(),
    ui.button("clear", "Clear", []),
  ]),
  ui.canvas("chart", Fill, Fixed(200.0), [
    canvas.Layer("bars", bar_shapes(model.series)),
  ]),
])
```

Use a canvas for custom visuals (charts, diagrams, badges, custom
controls); use built-in widgets everywhere else.

## Try it

Some quick experiments for the pad:

- Draw a gradient rectangle, a dashed circle, and a text label in one
  layer.
- Build a bar chart: one `shape.rect` per value in `model.series`, with
  height proportional to the value.
- Draw a star with `shape.path` and a list of `MoveTo` and `LineTo`
  commands.
- Add `shape.OnHover(True)` plus a `shape.HoverStyle` to an interactive
  group and watch it highlight on mouseover.
- Rotate a group with a transform, or clip a circle to a small
  rectangle.

---

Next: [Custom Widgets](13-custom-widgets.md)
