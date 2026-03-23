//// Canvas shape primitives for drawing on canvas widgets.
////
//// Shapes are plain PropValue maps (DictVal) placed as children of a canvas
//// widget. The Rust binary interprets them as drawing instructions. Each
//// shape is a flat map with a "type" key and shape-specific properties.

import gleam/dict
import gleam/list
import plushie/node.{
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

/// Shape options for styling and positioning.
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
  /// Horizontal position offset (used by group shapes, desugared to translate).
  X(Float)
  /// Vertical position offset (used by group shapes, desugared to translate).
  Y(Float)
  /// Ordered list of transforms for a group (translate, rotate, scale).
  Transforms(List(PropValue))
  /// Clip rectangle for a group.
  ClipRect(PropValue)
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
/// Options for interactive groups (elements). These are top-level fields
/// on the group, not nested in an "interactive" sub-object.
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
  FocusStyle(PropValue)
  ShowFocusRing(Bool)
  Tooltip(String)
  A11y(PropValue)
  HitRect(x: Float, y: Float, w: Float, h: Float)
  Focusable(Bool)
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

// -- Group shape --------------------------------------------------------------

/// Create a group of shapes. Groups are the only container and interactive
/// unit in the canvas. A group with an `InteractiveId` becomes an
/// interactive element.
///
/// Use `X(f)` and `Y(f)` shape opts to position the group (desugared
/// to a leading translate in the transforms array).
pub fn group(children: List(PropValue), opts: List(ShapeOpt)) -> PropValue {
  make_shape("group", [
    #("children", ListVal(children)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create an interactive group with an id and options.
/// Sugar for `group(children, []) |> interactive(id, opts)`.
pub fn interactive_group(
  id: String,
  children: List(PropValue),
  opts: List(InteractiveOpt),
) -> PropValue {
  group(children, []) |> interactive(id, opts)
}

// -- Transform values ---------------------------------------------------------

/// Create a translation transform for a group's transforms list.
pub fn translate(x: Float, y: Float) -> PropValue {
  DictVal(
    dict.from_list([
      #("type", StringVal("translate")),
      #("x", FloatVal(x)),
      #("y", FloatVal(y)),
    ]),
  )
}

/// Create a rotation transform (angle in radians).
pub fn rotate(angle: Float) -> PropValue {
  DictVal(
    dict.from_list([#("type", StringVal("rotate")), #("angle", FloatVal(angle))]),
  )
}

/// Create a non-uniform scale transform.
pub fn scale(x: Float, y: Float) -> PropValue {
  DictVal(
    dict.from_list([
      #("type", StringVal("scale")),
      #("x", FloatVal(x)),
      #("y", FloatVal(y)),
    ]),
  )
}

/// Create a uniform scale transform.
pub fn scale_uniform(factor: Float) -> PropValue {
  DictVal(
    dict.from_list([
      #("type", StringVal("scale")),
      #("factor", FloatVal(factor)),
    ]),
  )
}

// -- Clip value ---------------------------------------------------------------

/// Create a clip rectangle for a group.
pub fn clip(x: Float, y: Float, w: Float, h: Float) -> PropValue {
  DictVal(
    dict.from_list([
      #("x", FloatVal(x)),
      #("y", FloatVal(y)),
      #("w", FloatVal(w)),
      #("h", FloatVal(h)),
    ]),
  )
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

// -- Interactive elements -----------------------------------------------------

/// Make a group interactive by adding an id and interactive fields
/// at the group's top level. Only works on group shapes.
///
/// In the new wire format, interactive fields are top-level on the
/// group (no nested "interactive" sub-object).
pub fn interactive(
  shape: PropValue,
  id: String,
  opts: List(InteractiveOpt),
) -> PropValue {
  let assert DictVal(shape_dict) = shape
  let props =
    list.fold(opts, [#("id", StringVal(id))], fn(acc, opt) {
      case opt {
        InteractiveId(id2) -> [#("id", StringVal(id2)), ..acc]
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
        FocusStyle(s) -> [#("focus_style", s), ..acc]
        ShowFocusRing(v) -> [#("show_focus_ring", BoolVal(v)), ..acc]
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
        Focusable(v) -> [#("focusable", BoolVal(v)), ..acc]
      }
    })
  // Merge interactive props directly into the group dict.
  let merged = list.fold(props, shape_dict, fn(d, pair) {
    dict.insert(d, pair.0, pair.1)
  })
  DictVal(merged)
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
      X(x) -> [#("x", FloatVal(x))]
      Y(y) -> [#("y", FloatVal(y))]
      Transforms(ts) -> [#("transforms", ListVal(ts))]
      ClipRect(c) -> [#("clip", c)]
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
