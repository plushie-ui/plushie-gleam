import gleam/dict
import plushie/canvas/shape
import plushie/node.{BoolVal, DictVal, FloatVal, ListVal, StringVal}

// -- Helper to extract a key from a shape DictVal -----------------------------

fn get(shape: node.PropValue, key: String) -> Result(node.PropValue, Nil) {
  let assert DictVal(d) = shape
  dict.get(d, key)
}

// -- rect ---------------------------------------------------------------------

pub fn rect_produces_flat_dict_test() {
  let s = shape.rect(10.0, 20.0, 100.0, 50.0, [])

  assert get(s, "type") == Ok(StringVal("rect"))
  assert get(s, "x") == Ok(FloatVal(10.0))
  assert get(s, "y") == Ok(FloatVal(20.0))
  assert get(s, "w") == Ok(FloatVal(100.0))
  assert get(s, "h") == Ok(FloatVal(50.0))
}

pub fn rect_with_fill_test() {
  let s = shape.rect(0.0, 0.0, 50.0, 50.0, [shape.Fill("#ff0000")])

  assert get(s, "fill") == Ok(StringVal("#ff0000"))
}

pub fn rect_with_stroke_test() {
  let stroke_val = shape.stroke("black", 2.0, [])
  let s = shape.rect(0.0, 0.0, 50.0, 50.0, [shape.Stroke(stroke_val)])

  let assert Ok(DictVal(stroke_dict)) = get(s, "stroke")
  assert dict.get(stroke_dict, "color") == Ok(StringVal("black"))
  assert dict.get(stroke_dict, "width") == Ok(FloatVal(2.0))
}

pub fn rect_with_opacity_test() {
  let s = shape.rect(0.0, 0.0, 10.0, 10.0, [shape.Opacity(0.5)])

  assert get(s, "opacity") == Ok(FloatVal(0.5))
}

// -- circle -------------------------------------------------------------------

pub fn circle_uses_x_y_r_keys_test() {
  let s = shape.circle(50.0, 50.0, 25.0, [])

  assert get(s, "type") == Ok(StringVal("circle"))
  assert get(s, "x") == Ok(FloatVal(50.0))
  assert get(s, "y") == Ok(FloatVal(50.0))
  assert get(s, "r") == Ok(FloatVal(25.0))
}

// -- line ---------------------------------------------------------------------

pub fn line_produces_correct_keys_test() {
  let s = shape.line(0.0, 0.0, 100.0, 100.0, [])

  assert get(s, "type") == Ok(StringVal("line"))
  assert get(s, "x1") == Ok(FloatVal(0.0))
  assert get(s, "y1") == Ok(FloatVal(0.0))
  assert get(s, "x2") == Ok(FloatVal(100.0))
  assert get(s, "y2") == Ok(FloatVal(100.0))
}

// -- text ---------------------------------------------------------------------

pub fn text_produces_correct_keys_test() {
  let s = shape.text(10.0, 20.0, "hello", [])

  assert get(s, "type") == Ok(StringVal("text"))
  assert get(s, "x") == Ok(FloatVal(10.0))
  assert get(s, "y") == Ok(FloatVal(20.0))
  assert get(s, "content") == Ok(StringVal("hello"))
}

pub fn text_with_size_and_font_test() {
  let s =
    shape.text(0.0, 0.0, "styled", [
      shape.Size(16.0),
      shape.Font("monospace"),
      shape.AlignX("center"),
      shape.AlignY("top"),
    ])

  assert get(s, "size") == Ok(FloatVal(16.0))
  assert get(s, "font") == Ok(StringVal("monospace"))
  assert get(s, "align_x") == Ok(StringVal("center"))
  assert get(s, "align_y") == Ok(StringVal("top"))
}

// -- path commands as flat arrays ---------------------------------------------

pub fn path_commands_are_flat_arrays_test() {
  let s =
    shape.path([shape.MoveTo(0.0, 0.0), shape.LineTo(100.0, 0.0), shape.Close], [
      shape.Fill("blue"),
    ])

  assert get(s, "type") == Ok(StringVal("path"))
  assert get(s, "fill") == Ok(StringVal("blue"))

  let assert Ok(ListVal(commands)) = get(s, "commands")
  let assert [move_cmd, line_cmd, close_cmd] = commands

  // move_to is a flat array: ["move_to", x, y]
  assert move_cmd
    == ListVal([StringVal("move_to"), FloatVal(0.0), FloatVal(0.0)])

  // line_to is a flat array: ["line_to", x, y]
  assert line_cmd
    == ListVal([StringVal("line_to"), FloatVal(100.0), FloatVal(0.0)])

  // close is a bare string
  assert close_cmd == StringVal("close")
}

pub fn path_bezier_command_test() {
  let s = shape.path([shape.BezierTo(10.0, 20.0, 30.0, 40.0, 50.0, 60.0)], [])

  let assert Ok(ListVal([cmd])) = get(s, "commands")
  assert cmd
    == ListVal([
      StringVal("bezier_to"),
      FloatVal(10.0),
      FloatVal(20.0),
      FloatVal(30.0),
      FloatVal(40.0),
      FloatVal(50.0),
      FloatVal(60.0),
    ])
}

pub fn path_quadratic_command_test() {
  let s = shape.path([shape.QuadraticTo(10.0, 20.0, 30.0, 40.0)], [])

  let assert Ok(ListVal([cmd])) = get(s, "commands")
  assert cmd
    == ListVal([
      StringVal("quadratic_to"),
      FloatVal(10.0),
      FloatVal(20.0),
      FloatVal(30.0),
      FloatVal(40.0),
    ])
}

pub fn path_arc_command_test() {
  let s = shape.path([shape.Arc(50.0, 50.0, 25.0, 0.0, 3.14)], [])

  let assert Ok(ListVal([cmd])) = get(s, "commands")
  assert cmd
    == ListVal([
      StringVal("arc"),
      FloatVal(50.0),
      FloatVal(50.0),
      FloatVal(25.0),
      FloatVal(0.0),
      FloatVal(3.14),
    ])
}

pub fn path_arc_to_command_test() {
  let s = shape.path([shape.ArcTo(1.0, 2.0, 3.0, 4.0, 5.0)], [])

  let assert Ok(ListVal([cmd])) = get(s, "commands")
  assert cmd
    == ListVal([
      StringVal("arc_to"),
      FloatVal(1.0),
      FloatVal(2.0),
      FloatVal(3.0),
      FloatVal(4.0),
      FloatVal(5.0),
    ])
}

pub fn path_ellipse_command_test() {
  let s = shape.path([shape.Ellipse(1.0, 2.0, 3.0, 4.0, 0.5, 0.0, 3.14)], [])

  let assert Ok(ListVal([cmd])) = get(s, "commands")
  assert cmd
    == ListVal([
      StringVal("ellipse"),
      FloatVal(1.0),
      FloatVal(2.0),
      FloatVal(3.0),
      FloatVal(4.0),
      FloatVal(0.5),
      FloatVal(0.0),
      FloatVal(3.14),
    ])
}

pub fn path_rounded_rect_command_test() {
  let s = shape.path([shape.RoundedRect(0.0, 0.0, 100.0, 50.0, 5.0)], [])

  let assert Ok(ListVal([cmd])) = get(s, "commands")
  assert cmd
    == ListVal([
      StringVal("rounded_rect"),
      FloatVal(0.0),
      FloatVal(0.0),
      FloatVal(100.0),
      FloatVal(50.0),
      FloatVal(5.0),
    ])
}

// -- fill_rule ----------------------------------------------------------------

pub fn fill_rule_option_test() {
  let s = shape.rect(0.0, 0.0, 10.0, 10.0, [shape.FillRule("even_odd")])

  assert get(s, "fill_rule") == Ok(StringVal("even_odd"))
}

// -- multiple opts combine ----------------------------------------------------

pub fn multiple_opts_combine_test() {
  let stroke_val = shape.stroke("black", 1.0, [])
  let s =
    shape.circle(0.0, 0.0, 10.0, [
      shape.Fill("red"),
      shape.Stroke(stroke_val),
      shape.Opacity(0.8),
    ])

  assert get(s, "fill") == Ok(StringVal("red"))
  assert get(s, "opacity") == Ok(FloatVal(0.8))
  let assert Ok(DictVal(stroke_dict)) = get(s, "stroke")
  assert dict.get(stroke_dict, "color") == Ok(StringVal("black"))
  assert dict.get(stroke_dict, "width") == Ok(FloatVal(1.0))
}

// -- stroke with options ------------------------------------------------------

pub fn stroke_with_cap_and_join_test() {
  let s =
    shape.stroke("red", 3.0, [
      shape.StrokeCapOpt(shape.RoundCap),
      shape.StrokeJoinOpt(shape.BevelJoin),
    ])

  let assert DictVal(d) = s
  assert dict.get(d, "color") == Ok(StringVal("red"))
  assert dict.get(d, "width") == Ok(FloatVal(3.0))
  assert dict.get(d, "cap") == Ok(StringVal("round"))
  assert dict.get(d, "join") == Ok(StringVal("bevel"))
}

pub fn stroke_with_dash_test() {
  let s = shape.stroke("#000", 1.0, [shape.StrokeDashOpt([5.0, 3.0], 0.0)])

  let assert DictVal(d) = s
  let assert Ok(DictVal(dash)) = dict.get(d, "dash")
  assert dict.get(dash, "segments")
    == Ok(ListVal([FloatVal(5.0), FloatVal(3.0)]))
  assert dict.get(dash, "offset") == Ok(FloatVal(0.0))
}

// -- transforms ---------------------------------------------------------------

pub fn push_transform_test() {
  let s = shape.push_transform()
  assert get(s, "type") == Ok(StringVal("push_transform"))
}

pub fn pop_transform_test() {
  let s = shape.pop_transform()
  assert get(s, "type") == Ok(StringVal("pop_transform"))
}

pub fn translate_test() {
  let s = shape.translate(100.0, 200.0)
  assert get(s, "type") == Ok(StringVal("translate"))
  assert get(s, "x") == Ok(FloatVal(100.0))
  assert get(s, "y") == Ok(FloatVal(200.0))
}

pub fn rotate_test() {
  let s = shape.rotate(1.57)
  assert get(s, "type") == Ok(StringVal("rotate"))
  assert get(s, "angle") == Ok(FloatVal(1.57))
}

pub fn scale_test() {
  let s = shape.scale(2.0, 3.0)
  assert get(s, "type") == Ok(StringVal("scale"))
  assert get(s, "x") == Ok(FloatVal(2.0))
  assert get(s, "y") == Ok(FloatVal(3.0))
}

// -- clipping -----------------------------------------------------------------

pub fn push_clip_uses_w_h_keys_test() {
  let s = shape.push_clip(10.0, 20.0, 100.0, 80.0)
  assert get(s, "type") == Ok(StringVal("push_clip"))
  assert get(s, "x") == Ok(FloatVal(10.0))
  assert get(s, "y") == Ok(FloatVal(20.0))
  assert get(s, "w") == Ok(FloatVal(100.0))
  assert get(s, "h") == Ok(FloatVal(80.0))
}

pub fn pop_clip_test() {
  let s = shape.pop_clip()
  assert get(s, "type") == Ok(StringVal("pop_clip"))
}

// -- image / svg --------------------------------------------------------------

pub fn image_uses_source_and_w_h_keys_test() {
  let s = shape.image("photo.png", 0.0, 0.0, 200.0, 150.0, [])
  assert get(s, "type") == Ok(StringVal("image"))
  assert get(s, "source") == Ok(StringVal("photo.png"))
  assert get(s, "w") == Ok(FloatVal(200.0))
  assert get(s, "h") == Ok(FloatVal(150.0))
}

pub fn image_with_rotation_and_opacity_test() {
  let s =
    shape.image("photo.png", 0.0, 0.0, 100.0, 100.0, [
      shape.Rotation(0.5),
      shape.Opacity(0.7),
    ])

  assert get(s, "rotation") == Ok(FloatVal(0.5))
  assert get(s, "opacity") == Ok(FloatVal(0.7))
}

pub fn svg_uses_source_and_w_h_keys_test() {
  let s = shape.svg("icon.svg", 5.0, 5.0, 24.0, 24.0)
  assert get(s, "type") == Ok(StringVal("svg"))
  assert get(s, "source") == Ok(StringVal("icon.svg"))
  assert get(s, "w") == Ok(FloatVal(24.0))
  assert get(s, "h") == Ok(FloatVal(24.0))
}

// -- gradient -----------------------------------------------------------------

pub fn linear_gradient_positional_format_test() {
  let grad =
    shape.linear_gradient(#(0.0, 0.0), #(200.0, 0.0), [
      #(0.0, "#ff0000"),
      #(1.0, "#0000ff"),
    ])

  let assert DictVal(d) = grad
  assert dict.get(d, "type") == Ok(StringVal("linear"))
  assert dict.get(d, "start") == Ok(ListVal([FloatVal(0.0), FloatVal(0.0)]))
  assert dict.get(d, "end") == Ok(ListVal([FloatVal(200.0), FloatVal(0.0)]))
  assert dict.get(d, "stops")
    == Ok(
      ListVal([
        ListVal([FloatVal(0.0), StringVal("#ff0000")]),
        ListVal([FloatVal(1.0), StringVal("#0000ff")]),
      ]),
    )
}

pub fn gradient_fill_on_rect_test() {
  let grad =
    shape.linear_gradient(#(0.0, 0.0), #(100.0, 0.0), [
      #(0.0, "#fff"),
      #(1.0, "#000"),
    ])
  let s = shape.rect(0.0, 0.0, 100.0, 50.0, [shape.GradientFill(grad)])

  let assert Ok(DictVal(fill_dict)) = get(s, "fill")
  assert dict.get(fill_dict, "type") == Ok(StringVal("linear"))
}

// -- interactive --------------------------------------------------------------

pub fn interactive_adds_nested_field_test() {
  let s =
    shape.rect(0.0, 0.0, 50.0, 50.0, [shape.Fill("#f00")])
    |> shape.interactive([
      shape.InteractiveId("my-shape"),
      shape.OnClick(True),
      shape.Cursor("pointer"),
      shape.Tooltip("Click me"),
    ])

  let assert Ok(DictVal(interactive)) = get(s, "interactive")
  assert dict.get(interactive, "id") == Ok(StringVal("my-shape"))
  assert dict.get(interactive, "on_click") == Ok(BoolVal(True))
  assert dict.get(interactive, "cursor") == Ok(StringVal("pointer"))
  assert dict.get(interactive, "tooltip") == Ok(StringVal("Click me"))
}

pub fn interactive_with_drag_bounds_test() {
  let s =
    shape.circle(50.0, 50.0, 10.0, [])
    |> shape.interactive([
      shape.InteractiveId("drag-me"),
      shape.Draggable(True),
      shape.DragBounds(0.0, 100.0, 0.0, 100.0),
    ])

  let assert Ok(DictVal(interactive)) = get(s, "interactive")
  assert dict.get(interactive, "draggable") == Ok(BoolVal(True))
  let assert Ok(DictVal(bounds)) = dict.get(interactive, "drag_bounds")
  assert dict.get(bounds, "min_x") == Ok(FloatVal(0.0))
  assert dict.get(bounds, "max_x") == Ok(FloatVal(100.0))
}

// -- group --------------------------------------------------------------------

pub fn group_with_children_test() {
  let child1 = shape.rect(0.0, 0.0, 10.0, 10.0, [])
  let child2 = shape.circle(5.0, 5.0, 3.0, [])
  let s = shape.group([child1, child2], [])

  assert get(s, "type") == Ok(StringVal("group"))
  let assert Ok(ListVal(children)) = get(s, "children")
  let assert [_, _] = children
}

pub fn group_with_position_test() {
  let child = shape.rect(0.0, 0.0, 10.0, 10.0, [])
  let s = shape.group([child], [shape.X(100.0), shape.Y(200.0)])

  assert get(s, "type") == Ok(StringVal("group"))
  assert get(s, "x") == Ok(FloatVal(100.0))
  assert get(s, "y") == Ok(FloatVal(200.0))
}

pub fn group_empty_children_test() {
  let s = shape.group([], [])

  assert get(s, "type") == Ok(StringVal("group"))
  assert get(s, "children") == Ok(ListVal([]))
}

pub fn group_interactive_test() {
  let child = shape.circle(0.0, 0.0, 5.0, [])
  let s =
    shape.group([child], [shape.X(10.0)])
    |> shape.interactive([shape.InteractiveId("grp"), shape.OnClick(True)])

  let assert Ok(DictVal(interactive)) = get(s, "interactive")
  assert dict.get(interactive, "id") == Ok(StringVal("grp"))
  assert dict.get(interactive, "on_click") == Ok(BoolVal(True))
  assert get(s, "x") == Ok(FloatVal(10.0))
}

pub fn interactive_with_hit_rect_test() {
  let s =
    shape.circle(50.0, 50.0, 5.0, [])
    |> shape.interactive([
      shape.InteractiveId("small"),
      shape.HitRect(40.0, 40.0, 20.0, 20.0),
    ])

  let assert Ok(DictVal(interactive)) = get(s, "interactive")
  let assert Ok(DictVal(hr)) = dict.get(interactive, "hit_rect")
  assert dict.get(hr, "x") == Ok(FloatVal(40.0))
  assert dict.get(hr, "w") == Ok(FloatVal(20.0))
}
