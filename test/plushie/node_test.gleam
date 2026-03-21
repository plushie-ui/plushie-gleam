import gleam/dict
import gleeunit/should
import plushie/node.{
  BoolVal, DictVal, FloatVal, IntVal, ListVal, NullVal, StringVal,
}

pub fn new_creates_empty_node_test() {
  let n = node.new("btn", "button")
  should.equal(n.id, "btn")
  should.equal(n.kind, "button")
  should.equal(dict.size(n.props), 0)
  should.equal(n.children, [])
}

pub fn with_prop_adds_to_props_test() {
  let n =
    node.new("t", "text")
    |> node.with_prop("content", StringVal("hello"))
  should.equal(dict.get(n.props, "content"), Ok(StringVal("hello")))
}

pub fn with_props_adds_multiple_test() {
  let n =
    node.new("t", "text")
    |> node.with_props([
      #("content", StringVal("hi")),
      #("size", FloatVal(14.0)),
      #("bold", BoolVal(True)),
    ])
  should.equal(dict.size(n.props), 3)
  should.equal(dict.get(n.props, "size"), Ok(FloatVal(14.0)))
}

pub fn with_children_replaces_children_test() {
  let child1 = node.new("a", "text")
  let child2 = node.new("b", "text")
  let parent =
    node.new("col", "column")
    |> node.with_children([child1, child2])
  should.equal(parent.children, [child1, child2])
}

pub fn add_child_appends_test() {
  let parent =
    node.new("col", "column")
    |> node.add_child(node.new("a", "text"))
    |> node.add_child(node.new("b", "text"))
  let ids = case parent.children {
    [first, second] -> #(first.id, second.id)
    _ -> #("", "")
  }
  should.equal(ids, #("a", "b"))
}

pub fn empty_container_test() {
  let c = node.empty_container()
  should.equal(c.id, "")
  should.equal(c.kind, "container")
}

pub fn prop_value_equality_test() {
  // PropValue structural equality
  should.equal(StringVal("fill"), StringVal("fill"))
  should.not_equal(StringVal("fill"), StringVal("shrink"))
  should.equal(IntVal(42), IntVal(42))
  should.equal(FloatVal(3.14), FloatVal(3.14))
  should.equal(BoolVal(True), BoolVal(True))
  should.equal(NullVal, NullVal)
  should.equal(ListVal([IntVal(1), IntVal(2)]), ListVal([IntVal(1), IntVal(2)]))
  should.equal(
    DictVal(dict.from_list([#("x", IntVal(1))])),
    DictVal(dict.from_list([#("x", IntVal(1))])),
  )
}

pub fn with_prop_overwrites_existing_test() {
  let n =
    node.new("t", "text")
    |> node.with_prop("size", FloatVal(12.0))
    |> node.with_prop("size", FloatVal(16.0))
  should.equal(dict.get(n.props, "size"), Ok(FloatVal(16.0)))
}
