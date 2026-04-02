//// Pointer area widget builder (pointer interaction wrapper).
////
//// Captures all pointer input (mouse, touch, pen) within a region.
//// Renamed from mouse_area to reflect device-agnostic pointer model.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/widget/build

pub type Cursor {
  Pointer
  Grab
  Grabbing
  Crosshair
  CursorText
  CursorMove
  NotAllowed
  Progress
  Wait
  Help
  Cell
  Copy
  CursorAlias
  NoDrop
  AllScroll
  ZoomIn
  ZoomOut
  ContextMenu
  ResizingHorizontally
  ResizingVertically
  ResizingDiagonallyUp
  ResizingDiagonallyDown
  ResizingColumn
  ResizingRow
}

pub opaque type PointerArea {
  PointerArea(
    id: String,
    children: List(Node),
    cursor: Option(Cursor),
    on_press: Option(String),
    on_release: Option(String),
    on_right_press: Option(Bool),
    on_right_release: Option(Bool),
    on_middle_press: Option(Bool),
    on_middle_release: Option(Bool),
    on_double_click: Option(Bool),
    on_enter: Option(Bool),
    on_exit: Option(Bool),
    on_move: Option(Bool),
    on_scroll: Option(Bool),
    event_rate: Option(Int),
    a11y: Option(A11y),
  )
}

/// Create a new mouse area builder.
pub fn new(id: String) -> PointerArea {
  PointerArea(
    id:,
    children: [],
    cursor: None,
    on_press: None,
    on_release: None,
    on_right_press: None,
    on_right_release: None,
    on_middle_press: None,
    on_middle_release: None,
    on_double_click: None,
    on_enter: None,
    on_exit: None,
    on_move: None,
    on_scroll: None,
    event_rate: None,
    a11y: None,
  )
}

/// Set the mouse cursor.
pub fn cursor(pa: PointerArea, c: Cursor) -> PointerArea {
  PointerArea(..pa, cursor: option.Some(c))
}

/// Set the press event tag.
pub fn on_press(pa: PointerArea, tag: String) -> PointerArea {
  PointerArea(..pa, on_press: option.Some(tag))
}

/// Set the release event tag.
pub fn on_release(pa: PointerArea, tag: String) -> PointerArea {
  PointerArea(..pa, on_release: option.Some(tag))
}

/// Enable the right-click press event.
pub fn on_right_press(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_right_press: option.Some(enabled))
}

/// Enable the right-click release event.
pub fn on_right_release(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_right_release: option.Some(enabled))
}

/// Enable the middle-click press event.
pub fn on_middle_press(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_middle_press: option.Some(enabled))
}

/// Enable the middle-click release event.
pub fn on_middle_release(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_middle_release: option.Some(enabled))
}

/// Enable the double-click event.
pub fn on_double_click(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_double_click: option.Some(enabled))
}

/// Enable the mouse-enter event.
pub fn on_enter(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_enter: option.Some(enabled))
}

/// Enable the mouse-exit event.
pub fn on_exit(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_exit: option.Some(enabled))
}

/// Enable the move event.
pub fn on_move(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_move: option.Some(enabled))
}

/// Enable the scroll event.
pub fn on_scroll(pa: PointerArea, enabled: Bool) -> PointerArea {
  PointerArea(..pa, on_scroll: option.Some(enabled))
}

/// Set the event throttle rate in milliseconds.
pub fn event_rate(pa: PointerArea, rate: Int) -> PointerArea {
  PointerArea(..pa, event_rate: option.Some(rate))
}

/// Add a child node.
pub fn push(pa: PointerArea, child: Node) -> PointerArea {
  PointerArea(..pa, children: list.append(pa.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(pa: PointerArea, children: List(Node)) -> PointerArea {
  PointerArea(..pa, children: list.append(pa.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(pa: PointerArea, a: A11y) -> PointerArea {
  PointerArea(..pa, a11y: option.Some(a))
}

/// Option type for mouse area properties.
pub type Opt {
  Cursor(Cursor)
  OnPress(String)
  OnRelease(String)
  OnRightPress(Bool)
  OnRightRelease(Bool)
  OnMiddlePress(Bool)
  OnMiddleRelease(Bool)
  OnDoubleClick(Bool)
  OnEnter(Bool)
  OnExit(Bool)
  OnMove(Bool)
  OnScroll(Bool)
  EventRate(Int)
  A11y(A11y)
}

/// Apply a list of options to a pointer area builder.
pub fn with_opts(pa: PointerArea, opts: List(Opt)) -> PointerArea {
  list.fold(opts, pa, fn(p, opt) {
    case opt {
      Cursor(c) -> cursor(p, c)
      OnPress(tag) -> on_press(p, tag)
      OnRelease(tag) -> on_release(p, tag)
      OnRightPress(v) -> on_right_press(p, v)
      OnRightRelease(v) -> on_right_release(p, v)
      OnMiddlePress(v) -> on_middle_press(p, v)
      OnMiddleRelease(v) -> on_middle_release(p, v)
      OnDoubleClick(v) -> on_double_click(p, v)
      OnEnter(v) -> on_enter(p, v)
      OnExit(v) -> on_exit(p, v)
      OnMove(v) -> on_move(p, v)
      OnScroll(v) -> on_scroll(p, v)
      EventRate(r) -> event_rate(p, r)
      A11y(a) -> a11y(p, a)
    }
  })
}

fn cursor_to_string(c: Cursor) -> String {
  case c {
    Pointer -> "pointer"
    Grab -> "grab"
    Grabbing -> "grabbing"
    Crosshair -> "crosshair"
    CursorText -> "text"
    CursorMove -> "move"
    NotAllowed -> "not_allowed"
    Progress -> "progress"
    Wait -> "wait"
    Help -> "help"
    Cell -> "cell"
    Copy -> "copy"
    CursorAlias -> "alias"
    NoDrop -> "no_drop"
    AllScroll -> "all_scroll"
    ZoomIn -> "zoom_in"
    ZoomOut -> "zoom_out"
    ContextMenu -> "context_menu"
    ResizingHorizontally -> "resizing_horizontally"
    ResizingVertically -> "resizing_vertically"
    ResizingDiagonallyUp -> "resizing_diagonally_up"
    ResizingDiagonallyDown -> "resizing_diagonally_down"
    ResizingColumn -> "resizing_column"
    ResizingRow -> "resizing_row"
  }
}

/// Build the mouse area into a renderable Node.
pub fn build(pa: PointerArea) -> Node {
  let props =
    dict.new()
    |> build.put_optional("cursor", pa.cursor, fn(c) {
      StringVal(cursor_to_string(c))
    })
    |> build.put_optional_string("on_press", pa.on_press)
    |> build.put_optional_string("on_release", pa.on_release)
    |> build.put_optional_bool("on_right_press", pa.on_right_press)
    |> build.put_optional_bool("on_right_release", pa.on_right_release)
    |> build.put_optional_bool("on_middle_press", pa.on_middle_press)
    |> build.put_optional_bool("on_middle_release", pa.on_middle_release)
    |> build.put_optional_bool("on_double_click", pa.on_double_click)
    |> build.put_optional_bool("on_enter", pa.on_enter)
    |> build.put_optional_bool("on_exit", pa.on_exit)
    |> build.put_optional_bool("on_move", pa.on_move)
    |> build.put_optional_bool("on_scroll", pa.on_scroll)
    |> build.put_optional_int("event_rate", pa.event_rate)
    |> build.put_optional("a11y", pa.a11y, a11y.to_prop_value)
  Node(
    id: pa.id,
    kind: "pointer_area",
    props:,
    children: pa.children,
    meta: dict.new(),
  )
}
