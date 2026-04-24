# Composition Patterns

Recipes for common UI patterns built from Plushie's built-in widgets
and state helpers. These are not special framework features; they
compose the same widgets, commands, subscriptions, and helpers
documented elsewhere in this reference. Each pattern shows the
view, an excerpt from `update`, and notes on when to reach for it.

| Section | Patterns |
|---|---|
| [Reusable components](#reusable-components) | Extracting functions that return `Node` |
| [Navigation](#navigation) | Tabs, sidebar, breadcrumbs, route stack |
| [Overlays](#overlays) | Modal dialog, popover menu, context menu, tooltip, loading indicator |
| [Layout](#layout-patterns) | Toolbar, card helper, split panel, badge, responsive switch |
| [Form patterns](#form-patterns) | Validated field, search and filter |
| [State helpers](#state-helpers) | Selection, undo, data query with sort |
| [Interaction](#interaction-patterns) | Keyboard shortcuts, focus management, drag tracking, multi-window |
| [Optimisation](#optimisation) | `ui.memo` for subtree caching |

## Reusable components

A component in Plushie is any function that returns a `Node` (or a
`List(Node)`). There is no framework registration step. Pass the
model, the slice of state, or raw arguments; return a tree.

```gleam
import plushie/node.{type Node}
import plushie/prop/length.{Fill}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/text

fn page_header(title: String, subtitle: String) -> Node {
  ui.column("header", [column.Spacing(4.0), column.Width(Fill)], [
    ui.text(title <> "-title", title, [text.Size(24.0)]),
    ui.text_(title <> "-subtitle", subtitle),
  ])
}

fn field(id: String, label: String, value: String) -> Node {
  ui.row(id, [row.Spacing(8.0), row.Padding(padding.xy(4.0, 0.0))], [
    ui.text_(id <> "-label", label),
    ui.text_(id <> "-value", value),
  ])
}
```

Use components for any repeated chunk. Keep IDs unique by deriving
them from the caller's context (`id <> "-label"`) or by wrapping
the component in a named `ui.container` that establishes a scope
chain (see the [Scoped IDs reference](scoped-ids.md)).

## Navigation

### Tabs

Buttons in a row with conditional content. Track the active tab in
the model.

```gleam
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/prop/length.{Fill}
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/row

pub type Tab {
  Overview
  Details
  Settings
}

fn tab_bar(active: Tab) -> Node {
  ui.row("tabs", [row.Spacing(0.0)], [
    tab_button("tab-overview", "Overview", active == Overview),
    tab_button("tab-details", "Details", active == Details),
    tab_button("tab-settings", "Settings", active == Settings),
  ])
}

fn tab_button(id: String, label: String, is_active: Bool) -> Node {
  let style = case is_active {
    True -> button.Primary
    False -> button.TextStyle
  }
  ui.button(id, label, [button.Style(style)])
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "tab-overview", ..))) ->
      #(Model(..model, tab: Overview), command.none())
    Widget(Click(target: EventTarget(id: "tab-details", ..))) ->
      #(Model(..model, tab: Details), command.none())
    Widget(Click(target: EventTarget(id: "tab-settings", ..))) ->
      #(Model(..model, tab: Settings), command.none())
    _ -> #(model, command.none())
  }
}
```

Dispatch on the tab value inside `view` to pick the body content.

### Sidebar and content

A fixed-width sidebar next to a filling content area.

```gleam
import plushie/prop/length.{Fill, Fixed}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row

fn layout(model: Model) -> Node {
  ui.row("shell", [row.Width(Fill), row.Height(Fill)], [
    ui.column(
      "sidebar",
      [
        column.Width(Fixed(220.0)),
        column.Height(Fill),
        column.Padding(padding.all(8.0)),
        column.Spacing(4.0),
      ],
      nav_buttons(model),
    ),
    ui.container(
      "content",
      [
        container.Width(Fill),
        container.Height(Fill),
        container.Padding(padding.all(16.0)),
      ],
      [active_page(model)],
    ),
  ])
}
```

### Breadcrumbs

Interleave text separators with buttons; the final segment is
non-interactive.

```gleam
import gleam/int
import gleam/list
import plushie/prop/color
import plushie/ui
import plushie/widget/button
import plushie/widget/row
import plushie/widget/text

fn breadcrumbs(segments: List(String)) -> Node {
  let last = list.length(segments) - 1
  let children =
    list.index_map(segments, fn(segment, i) {
      let id = "crumb-" <> int.to_string(i)
      case i == last {
        True -> ui.text(id, segment, [text.Size(12.0)])
        False -> ui.button(id, segment, [button.Style(button.TextStyle)])
      }
    })
    |> interleave_with(fn(i) {
      ui.text("sep-" <> int.to_string(i), "/", [
        text.Size(12.0),
        text.Color(grey()),
      ])
    })

  ui.row("crumbs", [row.Spacing(4.0)], children)
}

fn grey() -> color.Color {
  let assert Ok(c) = color.from_hex("#999999")
  c
}
```

### Route-driven view dispatch

`plushie/route` maintains a path stack with typed parameters.
Push on navigation, pop for back, inspect `route.current` in the
view.

```gleam
import gleam/dict
import plushie/route
import plushie/ui
import plushie/widget/window

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("App")], [
      case route.current(model.nav) {
        "/list" -> list_view(model)
        "/detail" -> detail_view(model, route.params(model.nav))
        "/settings" -> settings_view(model)
        _ -> list_view(model)
      },
    ]),
  ]
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "show-detail", scope: [item_id, ..], ..))) ->
      #(
        Model(..model, nav: route.push_with_params(
          model.nav,
          "/detail",
          dict.from_list([#("id", item_id)]),
        )),
        command.none(),
      )
    Widget(Click(target: EventTarget(id: "back", ..))) ->
      #(Model(..model, nav: route.pop(model.nav)), command.none())
    _ -> #(model, command.none())
  }
}
```

`route.pop` never removes the root entry, so you can't navigate
away from the initial path. Use `route.can_go_back` to decide
whether to render a back button.

## Overlays

Overlays (modals, toasts, context menus) must live at the
**window level** so they are not clipped or scrolled by inner
containers. A `ui.stack` directly under the window layers children
on the z-axis: first child at the back, last child at the front.

```gleam
import plushie/prop/length.{Fill}
import plushie/ui
import plushie/widget/stack
import plushie/widget/window

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("App")], [
      ui.stack("overlays", [stack.Width(Fill), stack.Height(Fill)], [
        main_content(model),
        ..conditional_overlays(model)
      ]),
    ]),
  ]
}

fn conditional_overlays(model: Model) -> List(Node) {
  let layers = []
  let layers = case model.loading {
    True -> [loading_overlay(), ..layers]
    False -> layers
  }
  let layers = case model.modal {
    Some(m) -> [modal_overlay(m), ..layers]
    None -> layers
  }
  layers
}
```

### Modal dialog

A semi-transparent backdrop centred over the window with a dialog
card on top. Because `stack` children are positioned at the
stack's origin, a `container.Center(True)` child fills the whole
window and places its child at the centre.

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/prop/length.{Fill}
import plushie/prop/padding
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/text

fn modal_overlay(msg: String) -> Node {
  let backdrop = {
    let assert Ok(c) = color.from_hex("#00000088")
    c
  }
  let card_bg = {
    let assert Ok(c) = color.from_hex("#ffffff")
    c
  }

  ui.container(
    "modal-backdrop",
    [
      container.Width(Fill),
      container.Height(Fill),
      container.BgColor(backdrop),
      container.Center(True),
    ],
    [
      ui.container(
        "modal-card",
        [
          container.Padding(padding.all(24.0)),
          container.BgColor(card_bg),
          container.Border(border.new() |> border.radius(8.0)),
        ],
        [
          ui.column("modal-body", [column.Spacing(12.0)], [
            ui.text("modal-title", "Confirm", [text.Size(18.0)]),
            ui.text_("modal-msg", msg),
            ui.row("modal-actions", [row.Spacing(8.0)], [
              ui.button_("modal-cancel", "Cancel"),
              ui.button("modal-confirm", "Confirm", [
                button.Style(button.Primary),
              ]),
            ]),
          ]),
        ],
      ),
    ],
  )
}
```

Dismiss on `Widget(Click(target: EventTarget(id: "modal-cancel", ..)))`
and key `Escape` for keyboard users. Return focus to the element
that opened the modal after closing; see [focus
management](#focus-management) below.

### Popover menu

The `ui.overlay` widget anchors a floating element to a sibling.
It takes exactly two children: anchor first, overlay second.
Build-time validation panics on anything else.

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/container
import plushie/widget/overlay

fn dropdown_menu() -> Node {
  let edge = {
    let assert Ok(c) = color.from_hex("#dddddd")
    c
  }

  ui.overlay(
    "options",
    [overlay.Position(overlay.Below), overlay.Gap(4.0), overlay.Flip(True)],
    [
      ui.button_("options-trigger", "Options"),
      ui.container(
        "options-panel",
        [
          container.Padding(padding.all(8.0)),
          container.Border(
            border.new() |> border.width(1.0) |> border.color(edge) |> border.radius(4.0),
          ),
        ],
        [
          ui.column("options-list", [column.Spacing(2.0)], [
            ui.button("opt-edit", "Edit", [button.Style(button.TextStyle)]),
            ui.button("opt-delete", "Delete", [button.Style(button.TextStyle)]),
          ]),
        ],
      ),
    ],
  )
}
```

`overlay.Flip(True)` re-positions automatically when the overlay
would overflow the viewport. Combine with `overlay.Align` and
`overlay.OffsetX` / `overlay.OffsetY` for cross-axis tweaks.

### Context menu

Right-click uses `pointer_area.OnRightPress`. The menu renders
at the window-level stack using `ui.pin` for absolute positioning.

```gleam
import gleam/option.{type Option, None, Some}
import plushie/event.{
  EventTarget, Press, RightButton, Widget,
}
import plushie/ui
import plushie/widget/pin
import plushie/widget/pointer_area

pub type Model {
  Model(context_menu: Option(#(String, Float, Float)))
}

fn list_row(item_id: String, label: String) -> Node {
  ui.pointer_area(
    "item-" <> item_id,
    [pointer_area.OnRightPress(True)],
    [ui.text_(item_id <> "-label", label)],
  )
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Press(
      target: EventTarget(id: id, scope: [_, ..], ..),
      button: RightButton,
      x:,
      y:,
      ..,
    )) ->
      #(Model(context_menu: Some(#(id, x, y))), command.none())

    // Any other click dismisses the menu.
    Widget(_) -> #(Model(context_menu: None), command.none())
    _ -> #(model, command.none())
  }
}

fn context_menu_overlay(model: Model) -> Option(Node) {
  case model.context_menu {
    None -> None
    Some(#(_, x, y)) ->
      Some(ui.pin("ctx", [pin.X(x), pin.Y(y)], [menu_panel()]))
  }
}
```

Dismiss on any subsequent click or on `Escape`. The `Press`
variant carries a `button: MouseButton` field whose `RightButton`
variant indicates right click. See [Events
reference](events.md#pointer-events) for the full pointer event
shape.

### Tooltip that follows the cursor

`ui.tooltip` wraps a single anchor child. Set
`tooltip.Position(FollowCursor)` to track the mouse.

```gleam
import plushie/prop/position.{FollowCursor}
import plushie/ui
import plushie/widget/tooltip

ui.tooltip("tip", "Click to save", [tooltip.Position(FollowCursor)], [
  ui.button_("save", "Save"),
])
```

Other positions: `Top`, `Bottom`, `PositionLeft`, `PositionRight`
(from `plushie/prop/position`). Add `tooltip.Delay` in milliseconds
to avoid flashing tooltips during quick cursor passes.

### Loading indicator

Conditionally add a translucent overlay when work is in flight.
Keep it at the window-level stack so it covers scrollable content.

```gleam
import plushie/event.{
  type Event, Async, AsyncEvent, Click, EventTarget, Widget,
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "fetch", ..))) ->
      #(Model(..model, loading: True), command.task(fetch_data, "fetch"))

    Async(AsyncEvent(tag: "fetch", result: Ok(value))) ->
      #(Model(..model, loading: False, data: decode_data(value)), command.none())

    Async(AsyncEvent(tag: "fetch", result: Error(_))) ->
      #(Model(..model, loading: False), command.none())

    _ -> #(model, command.none())
  }
}
```

## Layout patterns

### Toolbar

`ui.space` with `Width(Fill)` expands to push trailing items to
the right edge.

```gleam
import plushie/prop/direction
import plushie/prop/length.{Fill, Fixed}
import plushie/prop/padding
import plushie/ui
import plushie/widget/row
import plushie/widget/rule
import plushie/widget/space

ui.row(
  "toolbar",
  [row.Spacing(4.0), row.Padding(padding.xy(8.0, 4.0))],
  [
    ui.button_("bold", "B"),
    ui.button_("italic", "I"),
    ui.rule("tool-sep-1", [rule.Direction(direction.Horizontal)]),
    ui.button_("align-left", "Left"),
    ui.button_("align-center", "Center"),
    ui.space("push", [space.Width(Fill)]),
    ui.button_("settings", "Settings"),
  ],
)
```

### Card helper

Wrap a block of content with a consistent border, shadow, and
padding. The helper takes the caller's inner node and returns
a `container`.

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/prop/padding
import plushie/prop/shadow
import plushie/widget/container

fn card(id: String, inner: Node) -> Node {
  let edge = {
    let assert Ok(c) = color.from_hex("#e5e7eb")
    c
  }
  let bg = {
    let assert Ok(c) = color.from_hex("#ffffff")
    c
  }
  let shade = {
    let assert Ok(c) = color.from_hex("#0000001a")
    c
  }

  ui.container(id, [
    container.Padding(padding.all(16.0)),
    container.BgColor(bg),
    container.Border(
      border.new() |> border.color(edge) |> border.width(1.0) |> border.radius(8.0),
    ),
    container.Shadow(
      shadow.new() |> shadow.color(shade) |> shadow.offset(0.0, 2.0) |> shadow.blur_radius(4.0),
    ),
  ], [inner])
}
```

### Badge

A pill-shaped container. Setting the border radius to a large
value clamps to the maximum, producing a pill.

```gleam
import plushie/prop/border
import plushie/prop/color
import plushie/prop/padding
import plushie/ui
import plushie/widget/container
import plushie/widget/text

fn badge(count: Int) -> Node {
  let bg = {
    let assert Ok(c) = color.from_hex("#3b82f6")
    c
  }
  let fg = {
    let assert Ok(c) = color.from_hex("#ffffff")
    c
  }
  ui.container(
    "badge",
    [
      container.Padding(padding.xy(2.0, 8.0)),
      container.BgColor(bg),
      container.Border(border.new() |> border.radius(999.0)),
    ],
    [
      ui.text("count", int.to_string(count), [
        text.Size(12.0),
        text.Color(fg),
      ]),
    ],
  )
}
```

### Split panel

A draggable divider between two panes. Track the current width
in the model and update it from pointer-move events.

```gleam
import plushie/event.{
  type Event, EventTarget, Move, Press, Release, Widget,
}
import plushie/prop/length.{Fill, Fixed}
import plushie/subscription
import plushie/ui
import plushie/widget/container
import plushie/widget/pointer_area
import plushie/widget/row

fn split_panel(model: Model) -> Node {
  let handle_bg = {
    let assert Ok(c) = color.from_hex("#dddddd")
    c
  }
  ui.row("split", [row.Width(Fill), row.Height(Fill)], [
    ui.container("left", [container.Width(Fixed(model.split_x)), container.Height(Fill)],
      [left_pane(model)],
    ),
    ui.pointer_area(
      "divider",
      [
        pointer_area.OnPress("drag-start"),
        pointer_area.OnRelease("drag-end"),
        pointer_area.Cursor(pointer_area.ResizingHorizontally),
      ],
      [
        ui.container("handle", [container.Width(Fixed(4.0)), container.Height(Fill), container.BgColor(handle_bg)], []),
      ],
    ),
    ui.container("right", [container.Width(Fill), container.Height(Fill)],
      [right_pane(model)],
    ),
  ])
}

fn subscribe(model: Model) -> List(subscription.Subscription) {
  case model.dragging {
    True -> [subscription.on_pointer_move() |> subscription.set_max_rate(60)]
    False -> []
  }
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Press(target: EventTarget(id: "divider", ..), ..)) ->
      #(Model(..model, dragging: True), command.none())
    Widget(Release(target: EventTarget(id: "divider", ..), ..)) ->
      #(Model(..model, dragging: False), command.none())
    Widget(Move(x:, ..)) if model.dragging ->
      #(Model(..model, split_x: float.max(120.0, x)), command.none())
    _ -> #(model, command.none())
  }
}
```

Subscriptions are recomputed every render, so toggling
`model.dragging` transparently starts and stops the global
pointer-move feed.

### Responsive layout switch

`ui.responsive` emits `Widget(Resize(target, width, height))` when
its available size changes. Store the measured width in the model
and branch the layout below a breakpoint.

```gleam
import plushie/event.{EventTarget, Resize, Widget}
import plushie/prop/length.{Fill}
import plushie/ui
import plushie/widget/responsive

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("App")], [
      ui.responsive(
        "root",
        [responsive.Width(Fill), responsive.Height(Fill)],
        [
          case model.viewport_w <. 800.0 {
            True -> stacked_layout(model)
            False -> sidebar_layout(model)
          },
        ],
      ),
    ]),
  ]
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Resize(target: EventTarget(id: "root", ..), width: w, ..)) ->
      #(Model(..model, viewport_w: w), command.none())
    _ -> #(model, command.none())
  }
}
```

`ui.sensor` provides the same `Resize` event for any child widget,
not just the layout root.

## Form patterns

### Validated field

Show an inline error under a text input, wire the a11y state so
screen readers announce the error.

```gleam
import plushie/event.{type Event, EventTarget, Input, Widget}
import plushie/prop/a11y
import plushie/prop/color
import plushie/ui
import plushie/widget/column
import plushie/widget/text
import plushie/widget/text_input

fn email_field(model: Model) -> Node {
  let err_color = {
    let assert Ok(c) = color.from_hex("#ef4444")
    c
  }
  ui.column("email-field", [column.Spacing(4.0)], [
    ui.text_input("email", model.email, [
      text_input.Placeholder("Email"),
      text_input.A11y(
        a11y.new()
        |> a11y.required(True)
        |> a11y.invalid(model.email_error != None),
      ),
    ]),
    case model.email_error {
      Some(msg) ->
        ui.text("email-error", msg, [text.Size(12.0), text.Color(err_color)])
      None -> ui.text_("email-spacer", "")
    },
  ])
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Input(target: EventTarget(id: "email", ..), value: v)) -> {
      let error = case string.contains(v, "@") {
        True -> None
        False -> Some("Must contain @")
      }
      #(Model(..model, email: v, email_error: error), command.none())
    }
    _ -> #(model, command.none())
  }
}
```

### Search and filter

`plushie/data` provides a query pipeline that composes filters,
searches, sorts, paging, and grouping. Run the query from `view`
so it always reflects the current query string.

```gleam
import plushie/data
import plushie/ui

fn filtered(model: Model) -> List(Item) {
  case model.query {
    "" -> model.items
    q -> {
      let result =
        data.query(model.items, [
          data.Search(
            fields: [fn(it: Item) { it.name }, fn(it: Item) { it.email }],
            query: q,
          ),
        ])
      result.entries
    }
  }
}
```

## State helpers

### Selection with highlighting

`plushie/selection` tracks single, multi, or range selection.
Toggle on click, check membership when rendering each row.

```gleam
import gleam/int
import plushie/event.{EventTarget, Toggle, Widget}
import plushie/selection
import plushie/ui
import plushie/widget/checkbox
import plushie/widget/keyed_column
import plushie/widget/row

fn list_view(model: Model) -> Node {
  ui.keyed_column("items", [keyed_column.Spacing(4.0)],
    list.map(model.items, fn(item) {
      let id_str = int.to_string(item.id)
      let selected = selection.is_selected(model.sel, id_str)
      ui.row("row:" <> id_str, [row.Spacing(8.0)], [
        ui.checkbox("select:" <> id_str, item.label, selected, []),
      ])
    }),
  )
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Toggle(target: EventTarget(id: id, ..), ..)) -> {
      case string.split(id, ":") {
        ["select", id_str] ->
          #(
            Model(..model, sel: selection.toggle(model.sel, id_str)),
            command.none(),
          )
        _ -> #(model, command.none())
      }
    }
    _ -> #(model, command.none())
  }
}
```

`selection.new(selection.Multi)` allows many selected IDs at once;
`selection.new_with_order(selection.Range, ordered_ids)` enables
shift-click ranges. See the [Events reference](events.md) for the
`Toggle` shape and the [Selection module docs](../../src/plushie/selection.gleam)
for `select`, `deselect`, `range_select`, and `clear`.

### Undo with coalesced typing

`plushie/undo` stores each change as an `UndoCommand` with an
`apply` and `undo` pair. Matching `coalesce_key` entries arriving
within the coalesce window merge into a single step, so a run of
keystrokes becomes one Ctrl+Z target.

The `UndoStack` is the source of truth for the value it wraps. Keep any
rendering cache in sync from `undo.current`, and send every undoable
change through `undo.push` so coalesced redo can replay commands in the
same order they were first applied.

```gleam
import gleam/option.{Some}
import plushie/event.{
  type Event, EventTarget, Input, Key, KeyEvent, KeyPressed, Widget,
}
import plushie/undo

pub type EditState {
  EditState(title: String, body: String)
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Input(target: EventTarget(id: "body", ..), value: v)) -> {
      let previous = undo.current(model.edit).body
      let cmd =
        undo.UndoCommand(
          apply: fn(s) { EditState(..s, body: v) },
          undo: fn(s) { EditState(..s, body: previous) },
          label: "edit body",
          coalesce_key: Some("body"),
          coalesce_window_ms: Some(500),
        )
      #(Model(..model, edit: undo.push(model.edit, cmd)), command.none())
    }

    Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..)) if m.command && !m.shift ->
      #(Model(..model, edit: undo.undo(model.edit)), command.none())

    Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..)) if m.command && m.shift ->
      #(Model(..model, edit: undo.redo(model.edit)), command.none())

    _ -> #(model, command.none())
  }
}
```

The `command` modifier is platform-aware: Ctrl on Linux and
Windows, Command on macOS. Use `undo.can_undo` / `undo.can_redo`
to enable or disable toolbar buttons.

### Data query with sort controls

Render sortable headers; track the active column and direction in
the model; feed both into `data.query`.

```gleam
import gleam/order
import gleam/string
import plushie/data

fn paged(model: Model) -> data.QueryResult(User) {
  data.query(model.users, [
    data.Search(
      fields: [fn(u: User) { u.name }, fn(u: User) { u.email }],
      query: model.query,
    ),
    data.SortBy(direction: model.sort_dir, compare: compare_on(model.sort_field)),
    data.Page(model.page),
    data.PageSize(25),
  ])
}

fn compare_on(field: String) -> fn(User, User) -> order.Order {
  case field {
    "name" -> fn(a, b) { string.compare(a.name, b.name) }
    "email" -> fn(a, b) { string.compare(a.email, b.email) }
    _ -> fn(_, _) { order.Eq }
  }
}
```

Clicking a sortable column in `ui.table` emits
`Widget(Sort(target, value))` where `value` is the column key.
Toggle between `data.Asc` and `data.Desc` in the handler.

## Interaction patterns

### Keyboard shortcuts

Subscribe globally, then dispatch through a helper that maps
key events to intents. Keeps `update` readable.

```gleam
import plushie/event.{type Event, Key, KeyEvent, KeyPressed}
import plushie/key
import plushie/subscription

fn subscribe(_model: Model) -> List(subscription.Subscription) {
  [subscription.on_key_press()]
}

pub type Intent {
  Save
  Undo
  Redo
  NewItem
  Find
  DismissOverlays
  Noop
}

fn shortcut(k: KeyEvent) -> Intent {
  case k {
    KeyEvent(key: "s", modifiers: m, ..) if m.command -> Save
    KeyEvent(key: "z", modifiers: m, ..) if m.command && !m.shift -> Undo
    KeyEvent(key: "z", modifiers: m, ..) if m.command && m.shift -> Redo
    KeyEvent(key: "n", modifiers: m, ..) if m.command -> NewItem
    KeyEvent(key: "f", modifiers: m, ..) if m.command -> Find
    KeyEvent(key: k, ..) if k == key.escape -> DismissOverlays
    _ -> Noop
  }
}

fn update(model: Model, event: Event) {
  case event {
    Key(KeyEvent(event_type: KeyPressed, ..) as k) ->
      apply_intent(model, shortcut(k))
    _ -> #(model, command.none())
  }
}
```

The `plushie/key` module exports string constants for named keys
(`key.escape`, `key.enter`, `key.tab`, arrow keys, etc.). Use them
in guards rather than comparing against string literals.

### Focus management

Return focus to a sensible place after destructive actions or
when closing dialogs.

```gleam
import plushie/command

fn update(model: Model, event: Event) {
  case event {
    // After deleting an item, focus the first remaining row or the
    // new-item button.
    Widget(Click(target: EventTarget(id: "delete", scope: [item_id, ..], ..))) -> {
      let remaining = list.filter(model.items, fn(it) { it.id != item_id })
      let focus_target = case remaining {
        [next, ..] -> next.id <> "/select"
        [] -> "new_item"
      }
      #(
        Model(..model, items: remaining),
        command.focus(focus_target),
      )
    }

    // After closing a modal, restore focus to the opener.
    Widget(Click(target: EventTarget(id: "modal-confirm", ..))) ->
      #(
        apply_modal_action(model),
        command.focus(model.modal_opener_id),
      )

    _ -> #(model, command.none())
  }
}
```

`command.focus_next` and `command.focus_previous` move focus along
the registered tab order. `command.focus_next_within(scope)` and
`command.focus_previous_within(scope)` cycle within a scoped
container, useful for keeping focus inside a modal.

### Multi-window detail view

`view` returns a `List(Node)` of windows. Appending a window while
an item is "detached" opens it as a separate OS window.
`window.ExitOnCloseRequest(False)` on secondaries means the user
can close them without quitting the app; handle `Window(WindowEvent(
event_type: CloseRequested, ..))` to remove the window from the
model.

```gleam
import gleam/list
import plushie/event.{
  type Event, CloseRequested, EventTarget, Widget, Window, WindowEvent,
}
import plushie/ui
import plushie/widget/window

fn view(model: Model) -> List(Node) {
  let main =
    ui.window("main", [window.Title("Items")], [items_list(model)])

  let detail_windows =
    list.filter_map(model.detached, fn(id) {
      case find_item(model, id) {
        Ok(item) ->
          Ok(ui.window(
            "detail:" <> id,
            [
              window.Title(item.name),
              window.ExitOnCloseRequest(False),
            ],
            [detail_view(item)],
          ))
        Error(_) -> Error(Nil)
      }
    })

  [main, ..detail_windows]
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "detach", scope: [item_id, ..], ..))) ->
      #(Model(..model, detached: [item_id, ..model.detached]), command.none())

    Window(WindowEvent(event_type: CloseRequested, window_id: wid, ..)) ->
      case string.split_once(wid, ":") {
        Ok(#("detail", item_id)) ->
          #(
            Model(..model, detached: list.filter(model.detached, fn(id) { id != item_id })),
            command.none(),
          )
        _ -> #(model, command.none())
      }

    _ -> #(model, command.none())
  }
}
```

All windows share the same model, `update`, and `view`. That's the
whole multi-window story; there is no separate window-manager
state.

## Optimisation

### `ui.memo` for subtree caching

`ui.memo("key", dependency, fn() { ... })` wraps a subtree in a
memo node. The content function runs on every render (Gleam
doesn't cache the closure itself), but the runtime compares
`dependency` with `==` and skips tree normalisation and diffing
for the subtree when the value hasn't changed.

```gleam
import plushie/ui

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("App")], [
      ui.row("shell", [row.Width(Fill), row.Height(Fill)], [
        ui.memo("sidebar", model.sidebar_version, fn() {
          sidebar_view(model.sidebar)
        }),
        content_view(model),
      ]),
    ]),
  ]
}
```

Good candidates: a sidebar keyed to a version integer, a chart
keyed to the data snapshot, any subtree whose inputs change much
less often than the surrounding view. Bad candidates: subtrees
that depend on the whole model or on values that change every
frame - the equality check will always fail and you'll pay the
overhead for nothing.

The memo key must be unique within its parent's children. Keep
the dependency small (an integer, a hash, a struct of primitives)
so the equality check stays cheap.

## See also

- [Built-in Widgets reference](built-in-widgets.md) - widget catalog with prop tables
- [Events reference](events.md) - full event taxonomy and pattern matching
- [Windows and Layout reference](windows-and-layout.md) - sizing, alignment, containers
- [Commands reference](commands.md) - `focus`, `send_after`, `announce`, and friends
- [Custom Widgets reference](custom-widgets.md) - extracting richer reusable widgets
