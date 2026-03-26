//// Mouse area widget builder (mouse interaction wrapper).

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

pub opaque type MouseArea {
  MouseArea(
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
pub fn new(id: String) -> MouseArea {
  MouseArea(
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
pub fn cursor(ma: MouseArea, c: Cursor) -> MouseArea {
  MouseArea(..ma, cursor: option.Some(c))
}

/// Set the press event tag.
pub fn on_press(ma: MouseArea, tag: String) -> MouseArea {
  MouseArea(..ma, on_press: option.Some(tag))
}

/// Set the release event tag.
pub fn on_release(ma: MouseArea, tag: String) -> MouseArea {
  MouseArea(..ma, on_release: option.Some(tag))
}

/// Enable the right-click press event.
pub fn on_right_press(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_right_press: option.Some(enabled))
}

/// Enable the right-click release event.
pub fn on_right_release(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_right_release: option.Some(enabled))
}

/// Enable the middle-click press event.
pub fn on_middle_press(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_middle_press: option.Some(enabled))
}

/// Enable the middle-click release event.
pub fn on_middle_release(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_middle_release: option.Some(enabled))
}

/// Enable the double-click event.
pub fn on_double_click(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_double_click: option.Some(enabled))
}

/// Enable the mouse-enter event.
pub fn on_enter(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_enter: option.Some(enabled))
}

/// Enable the mouse-exit event.
pub fn on_exit(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_exit: option.Some(enabled))
}

/// Enable the move event.
pub fn on_move(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_move: option.Some(enabled))
}

/// Enable the scroll event.
pub fn on_scroll(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_scroll: option.Some(enabled))
}

/// Set the event throttle rate in milliseconds.
pub fn event_rate(ma: MouseArea, rate: Int) -> MouseArea {
  MouseArea(..ma, event_rate: option.Some(rate))
}

/// Add a child node.
pub fn push(ma: MouseArea, child: Node) -> MouseArea {
  MouseArea(..ma, children: list.append(ma.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(ma: MouseArea, children: List(Node)) -> MouseArea {
  MouseArea(..ma, children: list.append(ma.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(ma: MouseArea, a: A11y) -> MouseArea {
  MouseArea(..ma, a11y: option.Some(a))
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

/// Apply a list of options to a mouse area builder.
pub fn with_opts(ma: MouseArea, opts: List(Opt)) -> MouseArea {
  list.fold(opts, ma, fn(m, opt) {
    case opt {
      Cursor(c) -> cursor(m, c)
      OnPress(tag) -> on_press(m, tag)
      OnRelease(tag) -> on_release(m, tag)
      OnRightPress(v) -> on_right_press(m, v)
      OnRightRelease(v) -> on_right_release(m, v)
      OnMiddlePress(v) -> on_middle_press(m, v)
      OnMiddleRelease(v) -> on_middle_release(m, v)
      OnDoubleClick(v) -> on_double_click(m, v)
      OnEnter(v) -> on_enter(m, v)
      OnExit(v) -> on_exit(m, v)
      OnMove(v) -> on_move(m, v)
      OnScroll(v) -> on_scroll(m, v)
      EventRate(r) -> event_rate(m, r)
      A11y(a) -> a11y(m, a)
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
pub fn build(ma: MouseArea) -> Node {
  let props =
    dict.new()
    |> build.put_optional("cursor", ma.cursor, fn(c) {
      StringVal(cursor_to_string(c))
    })
    |> build.put_optional_string("on_press", ma.on_press)
    |> build.put_optional_string("on_release", ma.on_release)
    |> build.put_optional_bool("on_right_press", ma.on_right_press)
    |> build.put_optional_bool("on_right_release", ma.on_right_release)
    |> build.put_optional_bool("on_middle_press", ma.on_middle_press)
    |> build.put_optional_bool("on_middle_release", ma.on_middle_release)
    |> build.put_optional_bool("on_double_click", ma.on_double_click)
    |> build.put_optional_bool("on_enter", ma.on_enter)
    |> build.put_optional_bool("on_exit", ma.on_exit)
    |> build.put_optional_bool("on_move", ma.on_move)
    |> build.put_optional_bool("on_scroll", ma.on_scroll)
    |> build.put_optional_int("event_rate", ma.event_rate)
    |> build.put_optional("a11y", ma.a11y, a11y.to_prop_value)
  Node(
    id: ma.id,
    kind: "mouse_area",
    props:,
    children: ma.children,
    meta: dict.new(),
  )
}
