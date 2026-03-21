//// Element: a query-friendly wrapper around a tree Node.
////
//// Elements provide convenient accessors for testing -- find by ID,
//// extract text content, read props, and traverse children.

import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/string
import plushie/node.{type Node, type PropValue, StringVal}
import plushie/tree

/// A test element wrapping a Node for convenient querying.
pub type Element {
  Element(node: Node)
}

/// Wrap a Node as an Element.
pub fn from_node(node: Node) -> Element {
  Element(node:)
}

/// Find an element by ID in a normalized tree.
pub fn find(in root: Node, id target: String) -> Option(Element) {
  case tree.find(root, target) {
    option.Some(node) -> option.Some(Element(node:))
    option.None -> option.None
  }
}

/// Extract text content from an element.
/// Checks props in order: "content", "label", "value", "placeholder".
pub fn text(element: Element) -> Option(String) {
  let props = element.node.props
  let keys = ["content", "label", "value", "placeholder"]
  find_first_string(props, keys)
}

fn find_first_string(
  props: dict.Dict(String, PropValue),
  keys: List(String),
) -> Option(String) {
  case keys {
    [] -> option.None
    [key, ..rest] ->
      case dict.get(props, key) {
        Ok(StringVal(s)) -> option.Some(s)
        _ -> find_first_string(props, rest)
      }
  }
}

/// Get a prop value by key.
pub fn prop(element: Element, key: String) -> Option(PropValue) {
  case dict.get(element.node.props, key) {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

/// Get the element's ID.
pub fn id(element: Element) -> String {
  element.node.id
}

/// Get the element's kind (widget type).
pub fn kind(element: Element) -> String {
  element.node.kind
}

/// Get the element's children as Elements.
pub fn children(element: Element) -> List(Element) {
  list.map(element.node.children, from_node)
}

/// Check if the element has any children.
pub fn has_children(element: Element) -> Bool {
  !list.is_empty(element.node.children)
}

/// Get a child element by index.
pub fn child_at(element: Element, index: Int) -> Option(Element) {
  case list.drop(element.node.children, index) {
    [child, ..] -> option.Some(from_node(child))
    [] -> option.None
  }
}

/// Find a descendant element by ID within this element's subtree.
pub fn find_within(element: Element, target: String) -> Option(Element) {
  find(in: element.node, id: target)
}

/// Collect all descendant elements matching a predicate.
pub fn find_all(
  element: Element,
  predicate: fn(Element) -> Bool,
) -> List(Element) {
  tree.find_all(element.node, fn(node) { predicate(from_node(node)) })
  |> list.map(from_node)
}

/// Get the local ID (last segment after "/").
pub fn local_id(element: Element) -> String {
  case string.split(element.node.id, "/") {
    [] -> element.node.id
    segments ->
      case list.last(segments) {
        Ok(last) -> last
        Error(_) -> element.node.id
      }
  }
}
