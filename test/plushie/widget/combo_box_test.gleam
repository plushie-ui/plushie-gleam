import gleam/dict
import plushie/prop/ellipsis
import plushie/widget/combo_box

pub fn ellipsis_sets_ellipsis_prop_test() {
  let node =
    combo_box.new("choice", ["A", "B"], "")
    |> combo_box.ellipsis(ellipsis.End)
    |> combo_box.build()

  assert dict.get(node.props, "ellipsis")
    == Ok(ellipsis.to_prop_value(ellipsis.End))
}
