//// Canvas shape primitives for drawing on canvas widgets.
////
//// Shapes are Nodes placed as children of a canvas widget.
//// The Rust binary interprets them as drawing instructions.

import gleam/dict
import gleam/list
import toddy/node.{
  type Node, type PropValue, DictVal, FloatVal, ListVal, Node, StringVal,
}

/// Shape options for styling.
pub type ShapeOpt {
  Fill(String)
  Stroke(color: String, width: Float)
  Opacity(Float)
  FillRule(String)
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
  Close
}

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
    Close -> DictVal(dict.from_list([#("cmd", StringVal("close"))]))
  }
}

fn shape_opts_to_props(opts: List(ShapeOpt)) -> List(#(String, PropValue)) {
  list.flat_map(opts, fn(opt) {
    case opt {
      Fill(color) -> [#("fill", StringVal(color))]
      Stroke(color:, width:) -> [
        #("stroke_color", StringVal(color)),
        #("stroke_width", FloatVal(width)),
      ]
      Opacity(o) -> [#("opacity", FloatVal(o))]
      FillRule(r) -> [#("fill_rule", StringVal(r))]
    }
  })
}

fn make_shape(shape_type: String, props: List(#(String, PropValue))) -> Node {
  Node(id: "", kind: shape_type, props: dict.from_list(props), children: [])
}
