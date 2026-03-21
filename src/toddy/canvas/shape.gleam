//// Canvas shape primitives for drawing on canvas widgets.
////
//// Shapes are plain PropValue maps (DictVal) placed as children of a canvas
//// widget. The Rust binary interprets them as drawing instructions. Each
//// shape is a flat map with a "type" key and shape-specific properties.

import gleam/dict
import gleam/list
import toddy/node.{
  type PropValue, BoolVal, DictVal, FloatVal, ListVal, StringVal,
}

/// Stroke line cap style.
pub type StrokeCap {
  ButtCap
  RoundCap
  SquareCap
}

/// Stroke line join style.
pub type StrokeJoin {
  MiterJoin
  RoundJoin
  BevelJoin
}

/// Shape options for styling.
pub type ShapeOpt {
  Fill(String)
  Stroke(stroke: PropValue)
  Opacity(Float)
  FillRule(String)
  GradientFill(PropValue)
  Size(Float)
  Font(String)
  AlignX(String)
  AlignY(String)
  Rotation(Float)
}

/// Path commands for constructing freeform shapes.
pub type PathCommand {
  MoveTo(x: Float, y: Float)
  LineTo(x: Float, y: Float)
  BezierTo(
    cp1x: Float,
    cp1y: Float,
    cp2x: Float,
    cp2y: Float,
    x: Float,
    y: Float,
  )
  QuadraticTo(cpx: Float, cpy: Float, x: Float, y: Float)
  Arc(x: Float, y: Float, radius: Float, start_angle: Float, end_angle: Float)
  ArcTo(x1: Float, y1: Float, x2: Float, y2: Float, radius: Float)
  Ellipse(
    cx: Float,
    cy: Float,
    rx: Float,
    ry: Float,
    rotation: Float,
    start_angle: Float,
    end_angle: Float,
  )
  RoundedRect(x: Float, y: Float, w: Float, h: Float, radius: Float)
  Close
}

/// Interactive shape options for hit testing and event handling.
pub type InteractiveOpt {
  InteractiveId(String)
  OnClick(Bool)
  OnHover(Bool)
  Draggable(Bool)
  DragAxis(String)
  DragBounds(x_min: Float, x_max: Float, y_min: Float, y_max: Float)
  Cursor(String)
  HoverStyle(PropValue)
  PressedStyle(PropValue)
  Tooltip(String)
  A11y(PropValue)
  HitRect(x: Float, y: Float, w: Float, h: Float)
}

// -- Stroke builder -----------------------------------------------------------

/// Build a stroke descriptor as a nested PropValue map.
///
/// Options: StrokeCap, StrokeJoin, StrokeDash.
pub fn stroke(
  color: String,
  width: Float,
  opts: List(StrokeDetailOpt),
) -> PropValue {
  let base = [
    #("color", StringVal(color)),
    #("width", FloatVal(width)),
  ]
  let props =
    list.fold(opts, base, fn(acc, opt) {
      case opt {
        StrokeCapOpt(cap) -> [#("cap", StringVal(cap_to_string(cap))), ..acc]
        StrokeJoinOpt(join) -> [
          #("join", StringVal(join_to_string(join))),
          ..acc
        ]
        StrokeDashOpt(segments:, offset:) -> [
          #(
            "dash",
            DictVal(
              dict.from_list([
                #("segments", ListVal(list.map(segments, FloatVal))),
                #("offset", FloatVal(offset)),
              ]),
            ),
          ),
          ..acc
        ]
      }
    })
  DictVal(dict.from_list(props))
}

/// Options for stroke detail (cap, join, dash).
pub type StrokeDetailOpt {
  StrokeCapOpt(StrokeCap)
  StrokeJoinOpt(StrokeJoin)
  StrokeDashOpt(segments: List(Float), offset: Float)
}

// -- Basic shapes -------------------------------------------------------------

/// Create a rectangle shape.
pub fn rect(
  x: Float,
  y: Float,
  w: Float,
  h: Float,
  opts: List(ShapeOpt),
) -> PropValue {
  make_shape("rect", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("w", FloatVal(w)),
    #("h", FloatVal(h)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a circle shape.
pub fn circle(x: Float, y: Float, r: Float, opts: List(ShapeOpt)) -> PropValue {
  make_shape("circle", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("r", FloatVal(r)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a line shape.
pub fn line(
  x1: Float,
  y1: Float,
  x2: Float,
  y2: Float,
  opts: List(ShapeOpt),
) -> PropValue {
  make_shape("line", [
    #("x1", FloatVal(x1)),
    #("y1", FloatVal(y1)),
    #("x2", FloatVal(x2)),
    #("y2", FloatVal(y2)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a text shape positioned at the given coordinates.
pub fn text(
  x: Float,
  y: Float,
  content: String,
  opts: List(ShapeOpt),
) -> PropValue {
  make_shape("text", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("content", StringVal(content)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a path from a list of path commands.
pub fn path(commands: List(PathCommand), opts: List(ShapeOpt)) -> PropValue {
  let cmd_values = list.map(commands, path_command_to_prop_value)
  make_shape("path", [
    #("commands", ListVal(cmd_values)),
    ..shape_opts_to_props(opts)
  ])
}

// -- Transform commands -------------------------------------------------------

/// Push (save) the current transform state onto the stack.
pub fn push_transform() -> PropValue {
  make_shape("push_transform", [])
}

/// Pop (restore) the previously saved transform state from the stack.
pub fn pop_transform() -> PropValue {
  make_shape("pop_transform", [])
}

/// Translate the canvas coordinate system.
pub fn translate(x: Float, y: Float) -> PropValue {
  make_shape("translate", [#("x", FloatVal(x)), #("y", FloatVal(y))])
}

/// Rotate the canvas coordinate system (angle in radians).
pub fn rotate(angle: Float) -> PropValue {
  make_shape("rotate", [#("angle", FloatVal(angle))])
}

/// Scale the canvas coordinate system.
pub fn scale(x: Float, y: Float) -> PropValue {
  make_shape("scale", [#("x", FloatVal(x)), #("y", FloatVal(y))])
}

// -- Clipping commands --------------------------------------------------------

/// Push a clipping rectangle. All shapes until the matching pop_clip
/// are clipped to this region. Clip regions nest via intersection.
pub fn push_clip(x: Float, y: Float, w: Float, h: Float) -> PropValue {
  make_shape("push_clip", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("w", FloatVal(w)),
    #("h", FloatVal(h)),
  ])
}

/// Pop the most recent clipping rectangle.
pub fn pop_clip() -> PropValue {
  make_shape("pop_clip", [])
}

// -- Image / SVG on canvas ----------------------------------------------------

/// Draw a raster image on the canvas at the given position and size.
pub fn image(
  source: String,
  x: Float,
  y: Float,
  w: Float,
  h: Float,
  opts: List(ShapeOpt),
) -> PropValue {
  make_shape("image", [
    #("source", StringVal(source)),
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("w", FloatVal(w)),
    #("h", FloatVal(h)),
    ..shape_opts_to_props(opts)
  ])
}

/// Draw an SVG on the canvas at the given position and size.
pub fn svg(source: String, x: Float, y: Float, w: Float, h: Float) -> PropValue {
  make_shape("svg", [
    #("source", StringVal(source)),
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("w", FloatVal(w)),
    #("h", FloatVal(h)),
  ])
}

// -- Gradient builder ---------------------------------------------------------

/// Create a linear gradient fill value usable with GradientFill.
/// Points are (x, y) tuples for start and end positions.
/// Stops are (offset, color) tuples where offset is 0.0 to 1.0.
pub fn linear_gradient(
  from: #(Float, Float),
  to: #(Float, Float),
  stops: List(#(Float, String)),
) -> PropValue {
  let stop_values =
    list.map(stops, fn(stop) { ListVal([FloatVal(stop.0), StringVal(stop.1)]) })
  DictVal(
    dict.from_list([
      #("type", StringVal("linear")),
      #("start", ListVal([FloatVal(from.0), FloatVal(from.1)])),
      #("end", ListVal([FloatVal(to.0), FloatVal(to.1)])),
      #("stops", ListVal(stop_values)),
    ]),
  )
}

// -- Interactive shapes -------------------------------------------------------

/// Mark a shape as interactive by adding an "interactive" field.
/// The id option is required.
pub fn interactive(shape: PropValue, opts: List(InteractiveOpt)) -> PropValue {
  let assert DictVal(shape_dict) = shape
  let interactive_props =
    list.fold(opts, [], fn(acc, opt) {
      case opt {
        InteractiveId(id) -> [#("id", StringVal(id)), ..acc]
        OnClick(v) -> [#("on_click", BoolVal(v)), ..acc]
        OnHover(v) -> [#("on_hover", BoolVal(v)), ..acc]
        Draggable(v) -> [#("draggable", BoolVal(v)), ..acc]
        DragAxis(axis) -> [#("drag_axis", StringVal(axis)), ..acc]
        DragBounds(x_min:, x_max:, y_min:, y_max:) -> [
          #(
            "drag_bounds",
            DictVal(
              dict.from_list([
                #("min_x", FloatVal(x_min)),
                #("max_x", FloatVal(x_max)),
                #("min_y", FloatVal(y_min)),
                #("max_y", FloatVal(y_max)),
              ]),
            ),
          ),
          ..acc
        ]
        Cursor(c) -> [#("cursor", StringVal(c)), ..acc]
        HoverStyle(s) -> [#("hover_style", s), ..acc]
        PressedStyle(s) -> [#("pressed_style", s), ..acc]
        Tooltip(t) -> [#("tooltip", StringVal(t)), ..acc]
        A11y(a) -> [#("a11y", a), ..acc]
        HitRect(x:, y:, w:, h:) -> [
          #(
            "hit_rect",
            DictVal(
              dict.from_list([
                #("x", FloatVal(x)),
                #("y", FloatVal(y)),
                #("w", FloatVal(w)),
                #("h", FloatVal(h)),
              ]),
            ),
          ),
          ..acc
        ]
      }
    })
  let interactive_val = DictVal(dict.from_list(interactive_props))
  DictVal(dict.insert(shape_dict, "interactive", interactive_val))
}

// -- Path command encoding ----------------------------------------------------

fn path_command_to_prop_value(cmd: PathCommand) -> PropValue {
  case cmd {
    MoveTo(x:, y:) -> ListVal([StringVal("move_to"), FloatVal(x), FloatVal(y)])
    LineTo(x:, y:) -> ListVal([StringVal("line_to"), FloatVal(x), FloatVal(y)])
    BezierTo(cp1x:, cp1y:, cp2x:, cp2y:, x:, y:) ->
      ListVal([
        StringVal("bezier_to"),
        FloatVal(cp1x),
        FloatVal(cp1y),
        FloatVal(cp2x),
        FloatVal(cp2y),
        FloatVal(x),
        FloatVal(y),
      ])
    QuadraticTo(cpx:, cpy:, x:, y:) ->
      ListVal([
        StringVal("quadratic_to"),
        FloatVal(cpx),
        FloatVal(cpy),
        FloatVal(x),
        FloatVal(y),
      ])
    Arc(x:, y:, radius:, start_angle:, end_angle:) ->
      ListVal([
        StringVal("arc"),
        FloatVal(x),
        FloatVal(y),
        FloatVal(radius),
        FloatVal(start_angle),
        FloatVal(end_angle),
      ])
    ArcTo(x1:, y1:, x2:, y2:, radius:) ->
      ListVal([
        StringVal("arc_to"),
        FloatVal(x1),
        FloatVal(y1),
        FloatVal(x2),
        FloatVal(y2),
        FloatVal(radius),
      ])
    Ellipse(cx:, cy:, rx:, ry:, rotation:, start_angle:, end_angle:) ->
      ListVal([
        StringVal("ellipse"),
        FloatVal(cx),
        FloatVal(cy),
        FloatVal(rx),
        FloatVal(ry),
        FloatVal(rotation),
        FloatVal(start_angle),
        FloatVal(end_angle),
      ])
    RoundedRect(x:, y:, w:, h:, radius:) ->
      ListVal([
        StringVal("rounded_rect"),
        FloatVal(x),
        FloatVal(y),
        FloatVal(w),
        FloatVal(h),
        FloatVal(radius),
      ])
    Close -> StringVal("close")
  }
}

// -- Shape option encoding ----------------------------------------------------

fn shape_opts_to_props(opts: List(ShapeOpt)) -> List(#(String, PropValue)) {
  list.flat_map(opts, fn(opt) {
    case opt {
      Fill(color) -> [#("fill", StringVal(color))]
      Stroke(s) -> [#("stroke", s)]
      Opacity(o) -> [#("opacity", FloatVal(o))]
      FillRule(r) -> [#("fill_rule", StringVal(r))]
      GradientFill(grad) -> [#("fill", grad)]
      Size(s) -> [#("size", FloatVal(s))]
      Font(f) -> [#("font", StringVal(f))]
      AlignX(a) -> [#("align_x", StringVal(a))]
      AlignY(a) -> [#("align_y", StringVal(a))]
      Rotation(r) -> [#("rotation", FloatVal(r))]
    }
  })
}

fn cap_to_string(cap: StrokeCap) -> String {
  case cap {
    ButtCap -> "butt"
    RoundCap -> "round"
    SquareCap -> "square"
  }
}

fn join_to_string(join: StrokeJoin) -> String {
  case join {
    MiterJoin -> "miter"
    RoundJoin -> "round"
    BevelJoin -> "bevel"
  }
}

fn make_shape(
  shape_type: String,
  props: List(#(String, PropValue)),
) -> PropValue {
  DictVal(dict.from_list([#("type", StringVal(shape_type)), ..props]))
}
