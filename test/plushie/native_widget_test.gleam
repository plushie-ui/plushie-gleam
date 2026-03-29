import gleam/dict
import gleeunit/should
import plushie/command
import plushie/native_widget
import plushie/node.{FloatVal}

const gauge_def = native_widget.NativeDef(
  kind: "gauge",
  rust_crate: "native/my_gauge",
  rust_constructor: "my_gauge::GaugeExtension::new()",
  props: [
    native_widget.NumberProp("value"),
    native_widget.NumberProp("min"),
    native_widget.NumberProp("max"),
    native_widget.ColorProp("color"),
  ],
  commands: [
    native_widget.CommandDef("set_value", [native_widget.NumberParam("value")]),
    native_widget.CommandDef("reset", []),
  ],
)

pub fn build_creates_node_with_native_widget_kind_test() {
  let node =
    native_widget.build(gauge_def, "g1", [
      #("value", FloatVal(42.0)),
      #("min", FloatVal(0.0)),
      #("max", FloatVal(100.0)),
    ])
  should.equal(node.id, "g1")
  should.equal(node.kind, "gauge")
  should.equal(dict.get(node.props, "value"), Ok(FloatVal(42.0)))
  should.equal(node.children, [])
}

pub fn build_container_includes_children_test() {
  let child = node.new("inner", "text")
  let node =
    native_widget.build_container(gauge_def, "g2", [#("value", FloatVal(0.0))], [
      child,
    ])
  should.equal(node.children, [child])
}

pub fn command_creates_native_widget_command_test() {
  let cmd =
    native_widget.command(gauge_def, "g1", "set_value", [
      #("value", FloatVal(75.0)),
    ])
  case cmd {
    command.WidgetCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "g1")
      should.equal(op, "set_value")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(75.0)))
    }
    _ -> should.fail()
  }
}

pub fn prop_names_returns_all_prop_names_test() {
  let names = native_widget.prop_names(gauge_def)
  should.equal(names, ["value", "min", "max", "color"])
}

pub fn command_names_returns_all_command_names_test() {
  let names = native_widget.command_names(gauge_def)
  should.equal(names, ["set_value", "reset"])
}

pub fn commands_creates_batch_test() {
  let cmd =
    native_widget.commands(gauge_def, [
      #("g1", "set_value", [#("value", FloatVal(10.0))]),
      #("g2", "reset", []),
    ])
  case cmd {
    command.WidgetCommands(commands:) -> {
      should.equal(list.length(commands), 2)
    }
    _ -> should.fail()
  }
}

import gleam/list

// ---------------------------------------------------------------------------
// validate
// ---------------------------------------------------------------------------

pub fn validate_valid_def_test() {
  let result = native_widget.validate(gauge_def)
  should.be_ok(result)
}

pub fn validate_empty_kind_test() {
  let def =
    native_widget.NativeDef(
      kind: "",
      rust_crate: "native/x",
      rust_constructor: "x::new()",
      props: [],
      commands: [],
    )
  let assert Error(errors) = native_widget.validate(def)
  should.be_true(list.contains(errors, "kind must not be empty"))
}

pub fn validate_duplicate_prop_names_test() {
  let def =
    native_widget.NativeDef(
      kind: "widget",
      rust_crate: "native/x",
      rust_constructor: "x::new()",
      props: [
        native_widget.NumberProp("value"),
        native_widget.StringProp("label"),
        native_widget.NumberProp("value"),
      ],
      commands: [],
    )
  let assert Error(errors) = native_widget.validate(def)
  should.be_true(list.contains(errors, "duplicate prop name \"value\""))
}

pub fn validate_reserved_names_test() {
  let def =
    native_widget.NativeDef(
      kind: "widget",
      rust_crate: "native/x",
      rust_constructor: "x::new()",
      props: [native_widget.StringProp("id"), native_widget.StringProp("type")],
      commands: [],
    )
  let assert Error(errors) = native_widget.validate(def)
  should.be_true(list.contains(errors, "prop name \"id\" is reserved"))
  should.be_true(list.contains(errors, "prop name \"type\" is reserved"))
}

pub fn validate_multiple_errors_test() {
  let def =
    native_widget.NativeDef(
      kind: "",
      rust_crate: "native/x",
      rust_constructor: "x::new()",
      props: [native_widget.StringProp("children")],
      commands: [],
    )
  let assert Error(errors) = native_widget.validate(def)
  should.be_true(list.length(errors) >= 2)
}
