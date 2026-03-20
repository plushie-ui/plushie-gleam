//// Canvas shape primitives for drawing on canvas widgets.
////
//// Shapes are Nodes placed as children of a canvas widget.
//// The Rust binary interprets them as drawing instructions.

import gleam/dict
import gleam/list
import toddy/node.{
  type Node, type PropValue, DictVal, FloatVal, ListVal, Node, StringVal,
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
  Stroke(color: String, width: Float)
  StrokeColor(String)
  StrokeWidth(Float)
  StrokeCap(StrokeCap)
  StrokeJoin(StrokeJoin)
  StrokeDash(pattern: List(Float), offset: Float)
  Opacity(Float)
  FillRule(String)
  GradientFill(PropValue)
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
  RoundedRect(x: Float, y: Float, width: Float, height: Float, radius: Float)
  Close
}

// -- Basic shapes -------------------------------------------------------------

/// Create a rectangle shape.
pub fn rect(
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  opts: List(ShapeOpt),
) -> Node {
  make_shape("rect", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("width", FloatVal(width)),
    #("height", FloatVal(height)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a circle shape.
pub fn circle(x: Float, y: Float, radius: Float, opts: List(ShapeOpt)) -> Node {
  make_shape("circle", [
    #("cx", FloatVal(x)),
    #("cy", FloatVal(y)),
    #("radius", FloatVal(radius)),
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
) -> Node {
  make_shape("line", [
    #("x1", FloatVal(x1)),
    #("y1", FloatVal(y1)),
    #("x2", FloatVal(x2)),
    #("y2", FloatVal(y2)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a text shape positioned at the given coordinates.
pub fn text(x: Float, y: Float, content: String, opts: List(ShapeOpt)) -> Node {
  make_shape("text", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("content", StringVal(content)),
    ..shape_opts_to_props(opts)
  ])
}

/// Create a path from a list of path commands.
pub fn path(commands: List(PathCommand), opts: List(ShapeOpt)) -> Node {
  let cmd_values = list.map(commands, path_command_to_prop_value)
  make_shape("path", [
    #("commands", ListVal(cmd_values)),
    ..shape_opts_to_props(opts)
  ])
}

// -- Transform commands -------------------------------------------------------

/// Push (save) the current transform state onto the stack.
pub fn push_transform() -> Node {
  make_shape("push_transform", [])
}

/// Pop (restore) the previously saved transform state from the stack.
pub fn pop_transform() -> Node {
  make_shape("pop_transform", [])
}

/// Translate the canvas coordinate system.
pub fn translate(x: Float, y: Float) -> Node {
  make_shape("translate", [#("x", FloatVal(x)), #("y", FloatVal(y))])
}

/// Rotate the canvas coordinate system (angle in radians).
pub fn rotate(angle: Float) -> Node {
  make_shape("rotate", [#("angle", FloatVal(angle))])
}

/// Scale the canvas coordinate system.
pub fn scale(x: Float, y: Float) -> Node {
  make_shape("scale", [#("x", FloatVal(x)), #("y", FloatVal(y))])
}

// -- Clipping commands --------------------------------------------------------

/// Push a clipping rectangle. All shapes until the matching pop_clip
/// are clipped to this region. Clip regions nest via intersection.
pub fn push_clip(x: Float, y: Float, width: Float, height: Float) -> Node {
  make_shape("push_clip", [
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("width", FloatVal(width)),
    #("height", FloatVal(height)),
  ])
}

/// Pop the most recent clipping rectangle.
pub fn pop_clip() -> Node {
  make_shape("pop_clip", [])
}

// -- Image / SVG on canvas ----------------------------------------------------

/// Draw a raster image on the canvas at the given position and size.
pub fn draw_image(
  handle: String,
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  opts: List(ShapeOpt),
) -> Node {
  make_shape("image", [
    #("handle", StringVal(handle)),
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("width", FloatVal(width)),
    #("height", FloatVal(height)),
    ..shape_opts_to_props(opts)
  ])
}

/// Draw an SVG on the canvas at the given position and size.
pub fn draw_svg(
  source: String,
  x: Float,
  y: Float,
  width: Float,
  height: Float,
) -> Node {
  make_shape("svg", [
    #("source", StringVal(source)),
    #("x", FloatVal(x)),
    #("y", FloatVal(y)),
    #("width", FloatVal(width)),
    #("height", FloatVal(height)),
  ])
}

// -- Gradient builder ---------------------------------------------------------

/// Create a linear gradient fill value usable with GradientFill.
/// Stops are (offset, color) tuples where offset is 0.0 to 1.0.
pub fn linear_gradient(angle: Float, stops: List(#(Float, String))) -> PropValue {
  let stop_values =
    list.map(stops, fn(stop) {
      DictVal(
        dict.from_list([
          #("offset", FloatVal(stop.0)),
          #("color", StringVal(stop.1)),
        ]),
      )
    })
  DictVal(
    dict.from_list([
      #("type", StringVal("linear")),
      #("angle", FloatVal(angle)),
      #("stops", ListVal(stop_values)),
    ]),
  )
}

// -- Path command encoding ----------------------------------------------------

fn path_command_to_prop_value(cmd: PathCommand) -> PropValue {
  case cmd {
    MoveTo(x:, y:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("move_to")),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ]),
      )
    LineTo(x:, y:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("line_to")),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ]),
      )
    BezierTo(cp1x:, cp1y:, cp2x:, cp2y:, x:, y:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("bezier_to")),
          #("cp1x", FloatVal(cp1x)),
          #("cp1y", FloatVal(cp1y)),
          #("cp2x", FloatVal(cp2x)),
          #("cp2y", FloatVal(cp2y)),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ]),
      )
    QuadraticTo(cpx:, cpy:, x:, y:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("quadratic_to")),
          #("cpx", FloatVal(cpx)),
          #("cpy", FloatVal(cpy)),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ]),
      )
    Arc(x:, y:, radius:, start_angle:, end_angle:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("arc")),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
          #("radius", FloatVal(radius)),
          #("start_angle", FloatVal(start_angle)),
          #("end_angle", FloatVal(end_angle)),
        ]),
      )
    ArcTo(x1:, y1:, x2:, y2:, radius:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("arc_to")),
          #("x1", FloatVal(x1)),
          #("y1", FloatVal(y1)),
          #("x2", FloatVal(x2)),
          #("y2", FloatVal(y2)),
          #("radius", FloatVal(radius)),
        ]),
      )
    Ellipse(cx:, cy:, rx:, ry:, rotation:, start_angle:, end_angle:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("ellipse")),
          #("cx", FloatVal(cx)),
          #("cy", FloatVal(cy)),
          #("rx", FloatVal(rx)),
          #("ry", FloatVal(ry)),
          #("rotation", FloatVal(rotation)),
          #("start_angle", FloatVal(start_angle)),
          #("end_angle", FloatVal(end_angle)),
        ]),
      )
    RoundedRect(x:, y:, width:, height:, radius:) ->
      DictVal(
        dict.from_list([
          #("cmd", StringVal("rounded_rect")),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
          #("width", FloatVal(width)),
          #("height", FloatVal(height)),
          #("radius", FloatVal(radius)),
        ]),
      )
    Close -> DictVal(dict.from_list([#("cmd", StringVal("close"))]))
  }
}

// -- Shape option encoding ----------------------------------------------------

fn shape_opts_to_props(opts: List(ShapeOpt)) -> List(#(String, PropValue)) {
  list.flat_map(opts, fn(opt) {
    case opt {
      Fill(color) -> [#("fill", StringVal(color))]
      Stroke(color:, width:) -> [
        #("stroke_color", StringVal(color)),
        #("stroke_width", FloatVal(width)),
      ]
      StrokeColor(color) -> [#("stroke_color", StringVal(color))]
      StrokeWidth(w) -> [#("stroke_width", FloatVal(w))]
      StrokeCap(cap) -> [#("stroke_cap", StringVal(cap_to_string(cap)))]
      StrokeJoin(join) -> [#("stroke_join", StringVal(join_to_string(join)))]
      StrokeDash(pattern:, offset:) -> [
        #("stroke_dash", ListVal(list.map(pattern, FloatVal))),
        #("stroke_dash_offset", FloatVal(offset)),
      ]
      Opacity(o) -> [#("opacity", FloatVal(o))]
      FillRule(r) -> [#("fill_rule", StringVal(r))]
      GradientFill(grad) -> [#("fill", grad)]
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

fn make_shape(shape_type: String, props: List(#(String, PropValue))) -> Node {
  Node(id: "", kind: shape_type, props: dict.from_list(props), children: [])
}
