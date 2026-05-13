import gleam/dict
import gleam/option
import plushie/prop/ellipsis
import plushie/widget/pick_list

pub fn ellipsis_sets_ellipsis_prop_test() {
  let node =
    pick_list.new("choice", ["A", "B"], option.None)
    |> pick_list.ellipsis(ellipsis.Start)
    |> pick_list.build()

  assert dict.get(node.props, "ellipsis")
    == Ok(ellipsis.to_prop_value(ellipsis.Start))
}
