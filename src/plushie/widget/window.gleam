//// Window widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, FloatVal, ListVal, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/widget/build

pub type WindowLevel {
  Normal
  AlwaysOnTop
  AlwaysOnBottom
}

pub opaque type Window {
  Window(
    id: String,
    children: List(Node),
    title: Option(String),
    width: Option(Float),
    height: Option(Float),
    position: Option(#(Float, Float)),
    min_size: Option(#(Float, Float)),
    max_size: Option(#(Float, Float)),
    maximized: Option(Bool),
    fullscreen: Option(Bool),
    visible: Option(Bool),
    resizable: Option(Bool),
    closeable: Option(Bool),
    minimizable: Option(Bool),
    decorations: Option(Bool),
    transparent: Option(Bool),
    blur: Option(Bool),
    level: Option(WindowLevel),
    exit_on_close_request: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Window {
  Window(
    id:,
    children: [],
    title: None,
    width: None,
    height: None,
    position: None,
    min_size: None,
    max_size: None,
    maximized: None,
    fullscreen: None,
    visible: None,
    resizable: None,
    closeable: None,
    minimizable: None,
    decorations: None,
    transparent: None,
    blur: None,
    level: None,
    exit_on_close_request: None,
    a11y: None,
  )
}

pub fn title(w: Window, t: String) -> Window {
  Window(..w, title: option.Some(t))
}

pub fn size(w: Window, width: Float, height: Float) -> Window {
  Window(..w, width: option.Some(width), height: option.Some(height))
}

pub fn width(w: Window, width: Float) -> Window {
  Window(..w, width: option.Some(width))
}

pub fn height(w: Window, height: Float) -> Window {
  Window(..w, height: option.Some(height))
}

pub fn position(w: Window, x: Float, y: Float) -> Window {
  Window(..w, position: option.Some(#(x, y)))
}

pub fn min_size(w: Window, width: Float, height: Float) -> Window {
  Window(..w, min_size: option.Some(#(width, height)))
}

pub fn max_size(w: Window, width: Float, height: Float) -> Window {
  Window(..w, max_size: option.Some(#(width, height)))
}

pub fn maximized(w: Window, m: Bool) -> Window {
  Window(..w, maximized: option.Some(m))
}

pub fn fullscreen(w: Window, f: Bool) -> Window {
  Window(..w, fullscreen: option.Some(f))
}

pub fn visible(w: Window, v: Bool) -> Window {
  Window(..w, visible: option.Some(v))
}

pub fn resizable(w: Window, r: Bool) -> Window {
  Window(..w, resizable: option.Some(r))
}

pub fn closeable(w: Window, c: Bool) -> Window {
  Window(..w, closeable: option.Some(c))
}

pub fn minimizable(w: Window, m: Bool) -> Window {
  Window(..w, minimizable: option.Some(m))
}

pub fn decorations(w: Window, d: Bool) -> Window {
  Window(..w, decorations: option.Some(d))
}

pub fn transparent(w: Window, t: Bool) -> Window {
  Window(..w, transparent: option.Some(t))
}

pub fn blur(w: Window, b: Bool) -> Window {
  Window(..w, blur: option.Some(b))
}

pub fn level(w: Window, l: WindowLevel) -> Window {
  Window(..w, level: option.Some(l))
}

pub fn exit_on_close_request(w: Window, e: Bool) -> Window {
  Window(..w, exit_on_close_request: option.Some(e))
}

/// Add a child node.
pub fn push(w: Window, child: Node) -> Window {
  Window(..w, children: list.append(w.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(w: Window, children: List(Node)) -> Window {
  Window(..w, children: list.append(w.children, children))
}

pub fn a11y(w: Window, a: A11y) -> Window {
  Window(..w, a11y: option.Some(a))
}

fn pair_to_prop_value(pair: #(Float, Float)) -> node.PropValue {
  ListVal([FloatVal(pair.0), FloatVal(pair.1)])
}

fn level_to_string(l: WindowLevel) -> String {
  case l {
    Normal -> "normal"
    AlwaysOnTop -> "always_on_top"
    AlwaysOnBottom -> "always_on_bottom"
  }
}

pub fn build(w: Window) -> Node {
  let props =
    dict.new()
    |> build.put_optional_string("title", w.title)
    |> build.put_optional_float("width", w.width)
    |> build.put_optional_float("height", w.height)
    |> build.put_optional("position", w.position, pair_to_prop_value)
    |> build.put_optional("min_size", w.min_size, pair_to_prop_value)
    |> build.put_optional("max_size", w.max_size, pair_to_prop_value)
    |> build.put_optional_bool("maximized", w.maximized)
    |> build.put_optional_bool("fullscreen", w.fullscreen)
    |> build.put_optional_bool("visible", w.visible)
    |> build.put_optional_bool("resizable", w.resizable)
    |> build.put_optional_bool("closeable", w.closeable)
    |> build.put_optional_bool("minimizable", w.minimizable)
    |> build.put_optional_bool("decorations", w.decorations)
    |> build.put_optional_bool("transparent", w.transparent)
    |> build.put_optional_bool("blur", w.blur)
    |> build.put_optional("level", w.level, fn(l) {
      StringVal(level_to_string(l))
    })
    |> build.put_optional_bool("exit_on_close_request", w.exit_on_close_request)
    |> build.put_optional("a11y", w.a11y, a11y.to_prop_value)
  Node(id: w.id, kind: "window", props:, children: w.children)
}
