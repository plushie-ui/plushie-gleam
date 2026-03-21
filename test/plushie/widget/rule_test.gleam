import gleam/dict
import plushie/widget/rule

pub fn new_builds_rule_test() {
  let node = rule.new("divider") |> rule.build()

  assert node.id == "divider"
  assert node.kind == "rule"
  assert node.children == []
  assert dict.is_empty(node.props)
}
