import plushie/node
import plushie/widget/floating

pub fn build_uses_floating_kind_test() {
  let child = node.new("content", "text")
  let built =
    floating.new("floaty")
    |> floating.push(child)
    |> floating.build()

  assert built.id == "floaty"
  assert built.kind == "floating"
  assert built.children == [child]
}
