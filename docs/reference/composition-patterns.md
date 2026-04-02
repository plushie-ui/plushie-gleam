# Composition Patterns

Recipes for common UI patterns built from Plushie's built-in widgets.

## Tabs

```gleam
fn view(model: Model) {
  let tabs = ["overview", "details", "settings"]

  ui.window("main", "Tabs", [
    ui.column_("", [
      ui.row_("", list.map(tabs, fn(tab) {
        ui.button("tab:" <> tab, string.capitalise(tab), [
          button.Style(case model.active_tab == tab {
            True -> style_map.Primary
            False -> style_map.Text
          }),
        ])
      })),
      ui.rule_(""),
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
ui.window("main", "App", [
  ui.stack_("", [
    main_content(model),
    case model.show_modal {
      True -> modal_overlay(model)
      False -> ui.space_("")
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
ui.overlay("menu", [overlay.Position(overlay.Below), overlay.Gap(4)], [
  ui.button_("trigger", "Options"),
  ui.container("dropdown", [container.Padding(8)], [
    ui.column_("", [
      ui.button("opt-edit", "Edit", [button.Style(style_map.Text)]),
      ui.button("opt-delete", "Delete", [button.Style(style_map.Text)]),
    ]),
  ]),
])
```

## Debounced search

Use `command.send_after` which cancels and restarts on each keystroke:

```gleam
WidgetInput(id: "search", value: query, ..) -> {
  let model = Model(..model, query: query)
  #(model, command.send_after(300, RunSearch(query)))
}
```

## Context menu

Right-click using `pointer_area` with `OnRightPress(True)`, positioned
with `pin` at cursor coordinates.

## Multi-window detail view

```gleam
fn view(model: Model) {
  let main = ui.window("main", "Items", [item_list(model)])

  case model.detached_id {
    option.Some(id) -> [
      main,
      ui.window_with("detail:" <> id, "Detail", [
        window.ExitOnCloseRequest(False),
      ], [detail_view(model, id)]),
    ]
    option.None -> [main]
  }
}
```

## See also

- [Built-in Widgets](built-in-widgets.md)
- [Canvas](canvas.md)
- [Themes and Styling](themes-and-styling.md)
- [Animation](animation.md)
