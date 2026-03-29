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
    scale_factor: Option(Float),
    a11y: Option(A11y),
  )
}

/// Create a new window builder.
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
    scale_factor: None,
    a11y: None,
  )
}

/// Set the window title.
pub fn title(w: Window, t: String) -> Window {
  Window(..w, title: option.Some(t))
}

/// Set both width and height at once.
pub fn size(w: Window, width: Float, height: Float) -> Window {
  Window(..w, width: option.Some(width), height: option.Some(height))
}

/// Set the width.
pub fn width(w: Window, width: Float) -> Window {
  Window(..w, width: option.Some(width))
}

/// Set the height.
pub fn height(w: Window, height: Float) -> Window {
  Window(..w, height: option.Some(height))
}

/// Set the window position in screen coordinates.
pub fn position(w: Window, x: Float, y: Float) -> Window {
  Window(..w, position: option.Some(#(x, y)))
}

/// Set the minimum window size.
pub fn min_size(w: Window, width: Float, height: Float) -> Window {
  Window(..w, min_size: option.Some(#(width, height)))
}

/// Set the maximum window size.
pub fn max_size(w: Window, width: Float, height: Float) -> Window {
  Window(..w, max_size: option.Some(#(width, height)))
}

/// Set whether the window is maximized.
pub fn maximized(w: Window, m: Bool) -> Window {
  Window(..w, maximized: option.Some(m))
}

/// Set whether the window is fullscreen.
pub fn fullscreen(w: Window, f: Bool) -> Window {
  Window(..w, fullscreen: option.Some(f))
}

/// Set whether the window is visible.
pub fn visible(w: Window, v: Bool) -> Window {
  Window(..w, visible: option.Some(v))
}

/// Set whether the window is resizable.
pub fn resizable(w: Window, r: Bool) -> Window {
  Window(..w, resizable: option.Some(r))
}

/// Set whether the window has a close button.
pub fn closeable(w: Window, c: Bool) -> Window {
  Window(..w, closeable: option.Some(c))
}

/// Set whether the window can be minimized.
pub fn minimizable(w: Window, m: Bool) -> Window {
  Window(..w, minimizable: option.Some(m))
}

/// Set whether window decorations are shown.
pub fn decorations(w: Window, d: Bool) -> Window {
  Window(..w, decorations: option.Some(d))
}

/// Set whether the window background is transparent.
pub fn transparent(w: Window, t: Bool) -> Window {
  Window(..w, transparent: option.Some(t))
}

/// Set whether background blur is enabled.
pub fn blur(w: Window, b: Bool) -> Window {
  Window(..w, blur: option.Some(b))
}

/// Set the window stacking level.
pub fn level(w: Window, l: WindowLevel) -> Window {
  Window(..w, level: option.Some(l))
}

/// Set whether to exit when close is requested.
pub fn exit_on_close_request(w: Window, e: Bool) -> Window {
  Window(..w, exit_on_close_request: option.Some(e))
}

/// Set the DPI scale factor for this window. Overrides the global
/// scale factor from settings. Useful for per-window zoom levels.
pub fn scale_factor(w: Window, factor: Float) -> Window {
  Window(..w, scale_factor: option.Some(factor))
}

/// Add a child node.
pub fn push(w: Window, child: Node) -> Window {
  Window(..w, children: list.append(w.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(w: Window, children: List(Node)) -> Window {
  Window(..w, children: list.append(w.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(w: Window, a: A11y) -> Window {
  Window(..w, a11y: option.Some(a))
}

/// Option type for window properties.
pub type Opt {
  Title(String)
  Size(Float, Float)
  Width(Float)
  Height(Float)
  Position(Float, Float)
  MinSize(Float, Float)
  MaxSize(Float, Float)
  Maximized(Bool)
  Fullscreen(Bool)
  Visible(Bool)
  Resizable(Bool)
  Closeable(Bool)
  Minimizable(Bool)
  Decorations(Bool)
  Transparent(Bool)
  Blur(Bool)
  Level(WindowLevel)
  ExitOnCloseRequest(Bool)
  ScaleFactor(Float)
  A11y(A11y)
}

/// Apply a list of options to a window builder.
pub fn with_opts(w: Window, opts: List(Opt)) -> Window {
  list.fold(opts, w, fn(win, opt) {
    case opt {
      Title(t) -> title(win, t)
      Size(width_, height_) -> size(win, width_, height_)
      Width(v) -> width(win, v)
      Height(v) -> height(win, v)
      Position(x, y) -> position(win, x, y)
      MinSize(width_, height_) -> min_size(win, width_, height_)
      MaxSize(width_, height_) -> max_size(win, width_, height_)
      Maximized(v) -> maximized(win, v)
      Fullscreen(v) -> fullscreen(win, v)
      Visible(v) -> visible(win, v)
      Resizable(v) -> resizable(win, v)
      Closeable(v) -> closeable(win, v)
      Minimizable(v) -> minimizable(win, v)
      Decorations(v) -> decorations(win, v)
      Transparent(v) -> transparent(win, v)
      Blur(v) -> blur(win, v)
      Level(v) -> level(win, v)
      ExitOnCloseRequest(v) -> exit_on_close_request(win, v)
      ScaleFactor(v) -> scale_factor(win, v)
      A11y(a) -> a11y(win, a)
    }
  })
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

/// Build the window into a renderable Node.
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
    |> build.put_optional_float("scale_factor", w.scale_factor)
    |> build.put_optional("a11y", w.a11y, a11y.to_prop_value)
  Node(id: w.id, kind: "window", props:, children: w.children, meta: dict.new())
}
