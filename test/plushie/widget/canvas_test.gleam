import gleam/list
import plushie/canvas/shape
import plushie/prop/length
import plushie/widget/canvas

pub fn multi_layer_shapes_get_distinct_auto_ids_test() {
  // Two layers, one rect each. Before the fix both shapes would receive
  // id "auto:shape_0" because index_map restarts at 0 per layer.
  let node =
    canvas.new("c", length.Fixed(200.0), length.Fixed(200.0))
    |> canvas.layer("track", [shape.rect(0.0, 0.0, 100.0, 10.0, [])])
    |> canvas.layer("fill", [shape.rect(0.0, 0.0, 50.0, 10.0, [])])
    |> canvas.build()

  // Each layer is a __layer__ child; extract the shape children.
  let shape_ids =
    node.children
    |> list.flat_map(fn(layer_node) {
      list.map(layer_node.children, fn(s) { s.id })
    })

  // Must be two distinct ids.
  assert list.length(shape_ids) == 2
  let assert [id_a, id_b] = shape_ids
  assert id_a != id_b
}

pub fn layer_shapes_auto_id_includes_canvas_and_layer_name_test() {
  let node =
    canvas.new("c", length.Fixed(100.0), length.Fixed(100.0))
    |> canvas.layer("bg", [shape.rect(0.0, 0.0, 100.0, 100.0, [])])
    |> canvas.build()

  let assert [layer_node] = node.children
  let assert [shape_node] = layer_node.children
  assert shape_node.id == "auto:c/bg/shape_0"
}

pub fn flat_shapes_auto_id_uses_canvas_default_prefix_test() {
  let node =
    canvas.new("c", length.Fixed(100.0), length.Fixed(100.0))
    |> canvas.shapes([
      shape.rect(0.0, 0.0, 10.0, 10.0, []),
      shape.rect(20.0, 0.0, 10.0, 10.0, []),
    ])
    |> canvas.build()

  let assert [s0, s1] = node.children
  assert s0.id == "auto:c/default/shape_0"
  assert s1.id == "auto:c/default/shape_1"
}

pub fn two_canvases_with_same_layer_name_dont_collide_test() {
  // Two canvas widgets with a layer called "stars" each containing one
  // shape - the classic case where rate_plushie uses multiple
  // star_rating widgets that all share the layer name "stars".
  let one =
    canvas.new("first", length.Fixed(100.0), length.Fixed(100.0))
    |> canvas.layer("stars", [shape.rect(0.0, 0.0, 10.0, 10.0, [])])
    |> canvas.build()
  let two =
    canvas.new("second", length.Fixed(100.0), length.Fixed(100.0))
    |> canvas.layer("stars", [shape.rect(0.0, 0.0, 10.0, 10.0, [])])
    |> canvas.build()
  let assert [layer_one] = one.children
  let assert [layer_two] = two.children
  let assert [shape_one] = layer_one.children
  let assert [shape_two] = layer_two.children
  assert shape_one.id != shape_two.id
}

pub fn explicit_id_takes_precedence_over_auto_id_test() {
  // interactive_group embeds an "id" field in the DictVal; the builder
  // should use it instead of generating an auto-id.
  let node =
    canvas.new("c", length.Fixed(100.0), length.Fixed(100.0))
    |> canvas.layer("main", [
      shape.interactive_group(
        "my-group",
        [shape.rect(0.0, 0.0, 50.0, 50.0, [])],
        [],
      ),
    ])
    |> canvas.build()

  let assert [layer_node] = node.children
  let assert [shape_node] = layer_node.children
  assert shape_node.id == "my-group"
}
