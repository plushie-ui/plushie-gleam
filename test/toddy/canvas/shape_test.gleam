import gleam/dict
import toddy/canvas/shape
import toddy/node.{DictVal, FloatVal, ListVal, StringVal}

pub fn rect_builds_correct_node_test() {
  let node = shape.rect(10.0, 20.0, 100.0, 50.0, [])

  assert node.kind == "rect"
  assert node.id == ""
  assert node.children == []
  assert dict.get(node.props, "x") == Ok(FloatVal(10.0))
  assert dict.get(node.props, "y") == Ok(FloatVal(20.0))
  assert dict.get(node.props, "width") == Ok(FloatVal(100.0))
  assert dict.get(node.props, "height") == Ok(FloatVal(50.0))
}

pub fn rect_with_fill_test() {
  let node = shape.rect(0.0, 0.0, 50.0, 50.0, [shape.Fill("#ff0000")])

  assert dict.get(node.props, "fill") == Ok(StringVal("#ff0000"))
}

pub fn rect_with_stroke_test() {
  let node =
    shape.rect(0.0, 0.0, 50.0, 50.0, [shape.Stroke(color: "black", width: 2.0)])

  assert dict.get(node.props, "stroke_color") == Ok(StringVal("black"))
  assert dict.get(node.props, "stroke_width") == Ok(FloatVal(2.0))
}

pub fn rect_with_opacity_test() {
  let node = shape.rect(0.0, 0.0, 10.0, 10.0, [shape.Opacity(0.5)])

  assert dict.get(node.props, "opacity") == Ok(FloatVal(0.5))
}

pub fn circle_builds_correct_node_test() {
  let node = shape.circle(50.0, 50.0, 25.0, [])

  assert node.kind == "circle"
  assert dict.get(node.props, "cx") == Ok(FloatVal(50.0))
  assert dict.get(node.props, "cy") == Ok(FloatVal(50.0))
  assert dict.get(node.props, "radius") == Ok(FloatVal(25.0))
}

pub fn line_builds_correct_node_test() {
  let node = shape.line(0.0, 0.0, 100.0, 100.0, [])

  assert node.kind == "line"
  assert dict.get(node.props, "x1") == Ok(FloatVal(0.0))
  assert dict.get(node.props, "y1") == Ok(FloatVal(0.0))
  assert dict.get(node.props, "x2") == Ok(FloatVal(100.0))
  assert dict.get(node.props, "y2") == Ok(FloatVal(100.0))
}

pub fn text_builds_correct_node_test() {
  let node = shape.text(10.0, 20.0, "hello", [])

  assert node.kind == "text"
  assert dict.get(node.props, "x") == Ok(FloatVal(10.0))
  assert dict.get(node.props, "y") == Ok(FloatVal(20.0))
  assert dict.get(node.props, "content") == Ok(StringVal("hello"))
}

pub fn path_with_commands_test() {
  let node =
    shape.path([shape.MoveTo(0.0, 0.0), shape.LineTo(100.0, 0.0), shape.Close], [
      shape.Fill("blue"),
    ])

  assert node.kind == "path"
  assert dict.get(node.props, "fill") == Ok(StringVal("blue"))

  let assert Ok(ListVal(commands)) = dict.get(node.props, "commands")
  let assert [DictVal(move_cmd), DictVal(line_cmd), DictVal(close_cmd)] =
    commands
  assert dict.get(move_cmd, "cmd") == Ok(StringVal("move_to"))
  assert dict.get(move_cmd, "x") == Ok(FloatVal(0.0))
  assert dict.get(line_cmd, "cmd") == Ok(StringVal("line_to"))
  assert dict.get(line_cmd, "x") == Ok(FloatVal(100.0))
  assert dict.get(close_cmd, "cmd") == Ok(StringVal("close"))
}

pub fn path_bezier_command_test() {
  let node =
    shape.path([shape.BezierTo(10.0, 20.0, 30.0, 40.0, 50.0, 60.0)], [])

  let assert Ok(ListVal([DictVal(cmd)])) = dict.get(node.props, "commands")
  assert dict.get(cmd, "cmd") == Ok(StringVal("bezier_to"))
  assert dict.get(cmd, "cp1x") == Ok(FloatVal(10.0))
  assert dict.get(cmd, "cp2y") == Ok(FloatVal(40.0))
  assert dict.get(cmd, "x") == Ok(FloatVal(50.0))
}

pub fn path_quadratic_command_test() {
  let node = shape.path([shape.QuadraticTo(10.0, 20.0, 30.0, 40.0)], [])

  let assert Ok(ListVal([DictVal(cmd)])) = dict.get(node.props, "commands")
  assert dict.get(cmd, "cmd") == Ok(StringVal("quadratic_to"))
  assert dict.get(cmd, "cpx") == Ok(FloatVal(10.0))
  assert dict.get(cmd, "cpy") == Ok(FloatVal(20.0))
}

pub fn path_arc_command_test() {
  let node = shape.path([shape.Arc(50.0, 50.0, 25.0, 0.0, 3.14)], [])

  let assert Ok(ListVal([DictVal(cmd)])) = dict.get(node.props, "commands")
  assert dict.get(cmd, "cmd") == Ok(StringVal("arc"))
  assert dict.get(cmd, "radius") == Ok(FloatVal(25.0))
  assert dict.get(cmd, "start_angle") == Ok(FloatVal(0.0))
  assert dict.get(cmd, "end_angle") == Ok(FloatVal(3.14))
}

pub fn fill_rule_option_test() {
  let node = shape.rect(0.0, 0.0, 10.0, 10.0, [shape.FillRule("evenodd")])

  assert dict.get(node.props, "fill_rule") == Ok(StringVal("evenodd"))
}

pub fn multiple_opts_combine_test() {
  let node =
    shape.circle(0.0, 0.0, 10.0, [
      shape.Fill("red"),
      shape.Stroke(color: "black", width: 1.0),
      shape.Opacity(0.8),
    ])

  assert dict.get(node.props, "fill") == Ok(StringVal("red"))
  assert dict.get(node.props, "stroke_color") == Ok(StringVal("black"))
  assert dict.get(node.props, "stroke_width") == Ok(FloatVal(1.0))
  assert dict.get(node.props, "opacity") == Ok(FloatVal(0.8))
}
