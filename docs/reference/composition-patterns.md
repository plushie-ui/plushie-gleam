# Composition Patterns

Recipes for common UI patterns built from Plushie's built-in widgets.

## Tabs

```gleam
import gleam/list
import gleam/string
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/row
import plushie/widget/window

fn view(model: Model) {
  let tabs = ["overview", "details", "settings"]

  ui.window("main", [window.Title("Tabs")], [
    ui.column("tabs_layout", [], [
      ui.row("tab_row", [], list.map(tabs, fn(tab) {
        ui.button("tab:" <> tab, string.capitalise(tab), [
          button.Style(case model.active_tab == tab {
            True -> button.Primary
            False -> button.TextStyle
          }),
        ])
      })),
      ui.rule("tab_rule", []),
      case model.active_tab {
        "overview" -> overview_content(model)
        "details" -> details_content(model)
        _ -> settings_content(model)
      },
    ]),
  ])
}
```

## Modal dialog

Place overlays at the window level in a `stack`:

```gleam
import plushie/ui
import plushie/widget/window

ui.window("main", [window.Title("App")], [
  ui.stack("layers", [], [
    main_content(model),
    case model.show_modal {
      True -> modal_overlay(model)
      False -> ui.space("modal_placeholder", [])
    },
  ]),
])
```

## Toast notifications

Transient messages that auto-dismiss. Use `command.send_after` for
auto-dismiss and `command.announce` for screen reader announcements.

## Popover

The `overlay` widget positions floating content relative to an anchor:

```gleam
import plushie/prop/padding
import plushie/ui
import plushie/widget/button
import plushie/widget/container
import plushie/widget/overlay

ui.overlay("menu", [overlay.Position(overlay.Below), overlay.Gap(4)], [
  ui.button_("trigger", "Options"),
  ui.container("dropdown", [container.Padding(padding.all(8.0))], [
    ui.column("menu_items", [], [
      ui.button("opt-edit", "Edit", [button.Style(button.TextStyle)]),
      ui.button("opt-delete", "Delete", [button.Style(button.TextStyle)]),
    ]),
  ]),
])
```

## Debounced search

Use `command.send_after` which cancels and restarts on each keystroke:

```gleam
Widget(Input(target: EventTarget(id: "search", ..), value: query)) -> {
  let model = Model(..model, query: query)
  #(model, command.send_after(300, RunSearch(query)))
}
```

## Context menu

Right-click using `pointer_area` with `OnRightPress(True)`, positioned
with `pin` at cursor coordinates.

## Multi-window detail view

```gleam
import gleam/option
import plushie/node
import plushie/ui
import plushie/widget/window

fn view(model: Model) {
  option.Some(
    node.empty_container()
    |> node.with_children(
      case model.detached_id {
        option.Some(id) -> [
          ui.window("main", [window.Title("Items")], [item_list(model)]),
          ui.window("detail:" <> id, [
            window.Title("Detail"),
            window.ExitOnCloseRequest(False),
          ], [detail_view(model, id)]),
        ]
        option.None -> [
          ui.window("main", [window.Title("Items")], [item_list(model)]),
        ]
      },
    )
  )
}
```

## See also

- [Built-in Widgets](built-in-widgets.md)
- [Canvas](canvas.md)
- [Themes and Styling](themes-and-styling.md)
- [Animation](animation.md)
