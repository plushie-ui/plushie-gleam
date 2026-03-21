//// Rule widget builder (horizontal/vertical divider).

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/prop/direction.{type Direction}
import plushie/widget/build

pub opaque type Rule {
  Rule(
    id: String,
    height: Option(Float),
    width: Option(Float),
    direction: Option(Direction),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Rule {
  Rule(id:, height: None, width: None, direction: None, style: None, a11y: None)
}

pub fn height(r: Rule, h: Float) -> Rule {
  Rule(..r, height: option.Some(h))
}

pub fn width(r: Rule, w: Float) -> Rule {
  Rule(..r, width: option.Some(w))
}

pub fn direction(r: Rule, d: Direction) -> Rule {
  Rule(..r, direction: option.Some(d))
}

pub fn style(r: Rule, s: String) -> Rule {
  Rule(..r, style: option.Some(s))
}

pub fn a11y(r: Rule, a: A11y) -> Rule {
  Rule(..r, a11y: option.Some(a))
}

pub fn build(r: Rule) -> Node {
  let props =
    dict.new()
    |> build.put_optional_float("height", r.height)
    |> build.put_optional_float("width", r.width)
    |> build.put_optional("direction", r.direction, fn(d) {
      StringVal(direction.to_string(d))
    })
    |> build.put_optional_string("style", r.style)
    |> build.put_optional("a11y", r.a11y, a11y.to_prop_value)
  Node(id: r.id, kind: "rule", props:, children: [])
}
