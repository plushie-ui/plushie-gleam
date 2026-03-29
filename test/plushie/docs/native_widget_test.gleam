import gleam/dict
import gleam/list
import gleeunit/should
import plushie/command
import plushie/native_widget
import plushie/node.{type Node, FloatVal, StringVal}
import plushie/ui
import plushie/widget/column

// -- NativeDef matching the native_widget.md quick start example --------------

const sparkline_def = native_widget.NativeDef(
  kind: "sparkline",
  rust_crate: "native/my_sparkline",
  rust_constructor: "my_sparkline::SparklineExtension::new()",
  props: [
    native_widget.NumberProp("data"),
    native_widget.ColorProp("color"),
    native_widget.NumberProp("capacity"),
  ],
  commands: [native_widget.CommandDef("push", [native_widget.NumberParam("value")])],
)

// -- Tests for the quick start NativeDef --------------------------------------

pub fn extensions_sparkline_def_validates_test() {
  let result = native_widget.validate(sparkline_def)
  should.be_ok(result)
}

pub fn extensions_sparkline_build_creates_node_test() {
  let node =
    native_widget.build(sparkline_def, "s1", [
      #("data", node.ListVal([FloatVal(1.0), FloatVal(2.0)])),
      #("color", StringVal("#ff0000")),
    ])
  should.equal(node.id, "s1")
  should.equal(node.kind, "sparkline")
  should.equal(dict.get(node.props, "color"), Ok(StringVal("#ff0000")))
}

pub fn extensions_sparkline_push_command_test() {
  let cmd =
    native_widget.command(sparkline_def, "s1", "push", [
      #("value", FloatVal(42.0)),
    ])
  case cmd {
    command.WidgetCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "s1")
      should.equal(op, "push")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(42.0)))
    }
    _ -> should.fail()
  }
}

pub fn extensions_sparkline_prop_names_test() {
  let names = native_widget.prop_names(sparkline_def)
  should.equal(names, ["data", "color", "capacity"])
}

pub fn extensions_sparkline_command_names_test() {
  let names = native_widget.command_names(sparkline_def)
  should.equal(names, ["push"])
}

// -- Native widget def from the "Native widgets" section ----------------------

const hex_view_def = native_widget.NativeDef(
  kind: "hex_view",
  rust_crate: "native/hex_view",
  rust_constructor: "hex_view::HexViewExtension::new()",
  props: [native_widget.StringProp("data"), native_widget.NumberProp("columns")],
  commands: [],
)

pub fn extensions_hex_view_validates_test() {
  let result = native_widget.validate(hex_view_def)
  should.be_ok(result)
}

pub fn extensions_hex_view_build_test() {
  let node =
    native_widget.build(hex_view_def, "hv1", [
      #("data", StringVal("deadbeef")),
      #("columns", FloatVal(16.0)),
    ])
  should.equal(node.kind, "hex_view")
  should.equal(dict.get(node.props, "data"), Ok(StringVal("deadbeef")))
}

pub fn extensions_hex_view_no_commands_test() {
  should.equal(native_widget.command_names(hex_view_def), [])
}

// -- Composite widget from the "Composite widgets" section --------------------

fn labeled_input(id: String, label: String, value: String) -> Node {
  ui.column(id, [column.Spacing(4)], [
    ui.text_(id <> "-label", label),
    ui.text_input(id <> "-input", value, []),
  ])
}

pub fn extensions_composite_labeled_input_test() {
  let node = labeled_input("email", "Email", "user@example.com")
  should.equal(node.kind, "column")
  should.equal(node.id, "email")
  should.equal(list.length(node.children), 2)

  let assert [label_node, input_node] = node.children
  should.equal(label_node.kind, "text")
  should.equal(label_node.id, "email-label")
  should.equal(dict.get(label_node.props, "content"), Ok(StringVal("Email")))

  should.equal(input_node.kind, "text_input")
  should.equal(input_node.id, "email-input")
  should.equal(
    dict.get(input_node.props, "value"),
    Ok(StringVal("user@example.com")),
  )
}

// -- Validation edge cases from the doc's DSL reference -----------------------

pub fn extensions_validate_empty_kind_fails_test() {
  let def =
    native_widget.NativeDef(
      kind: "",
      rust_crate: "native/x",
      rust_constructor: "x::new()",
      props: [],
      commands: [],
    )
  should.be_error(native_widget.validate(def))
}

pub fn extensions_validate_list_prop_test() {
  let def =
    native_widget.NativeDef(
      kind: "chart",
      rust_crate: "native/chart",
      rust_constructor: "chart::ChartExtension::new()",
      props: [
        native_widget.ListProp("points", "point"),
        native_widget.MapProp("metadata"),
        native_widget.AnyProp("extra"),
      ],
      commands: [],
    )
  should.be_ok(native_widget.validate(def))
}
