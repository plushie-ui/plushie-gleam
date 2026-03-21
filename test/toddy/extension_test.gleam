import gleam/dict
import gleeunit/should
import toddy/command
import toddy/extension
import toddy/node.{FloatVal, StringVal}

const gauge_def = extension.ExtensionDef(
  kind: "gauge",
  rust_crate: "native/my_gauge",
  rust_constructor: "my_gauge::GaugeExtension::new()",
  props: [
    extension.NumberProp("value"),
    extension.NumberProp("min"),
    extension.NumberProp("max"),
    extension.ColorProp("color"),
  ],
  commands: [
    extension.CommandDef("set_value", [extension.NumberParam("value")]),
    extension.CommandDef("reset", []),
  ],
)

pub fn build_creates_node_with_extension_kind_test() {
  let node =
    extension.build(gauge_def, "g1", [
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
    extension.build_container(gauge_def, "g2", [#("value", FloatVal(0.0))], [
      child,
    ])
  should.equal(node.children, [child])
}

pub fn command_creates_extension_command_test() {
  let cmd =
    extension.command(gauge_def, "g1", "set_value", [
      #("value", FloatVal(75.0)),
    ])
  case cmd {
    command.ExtensionCommand(node_id:, op:, payload:) -> {
      should.equal(node_id, "g1")
      should.equal(op, "set_value")
      should.equal(dict.get(payload, "value"), Ok(FloatVal(75.0)))
    }
    _ -> should.fail()
  }
}

pub fn prop_names_returns_all_prop_names_test() {
  let names = extension.prop_names(gauge_def)
  should.equal(names, ["value", "min", "max", "color"])
}

pub fn command_names_returns_all_command_names_test() {
  let names = extension.command_names(gauge_def)
  should.equal(names, ["set_value", "reset"])
}

pub fn commands_creates_batch_test() {
  let cmd =
    extension.commands(gauge_def, [
      #("g1", "set_value", [#("value", FloatVal(10.0))]),
      #("g2", "reset", []),
    ])
  case cmd {
    command.ExtensionCommands(commands:) -> {
      should.equal(list.length(commands), 2)
    }
    _ -> should.fail()
  }
}

import gleam/list
