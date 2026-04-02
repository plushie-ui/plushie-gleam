# Scoped IDs

Named containers automatically scope their children's IDs, producing
unique hierarchical paths without manual prefixing.

## Scoping rules

| Node type | Creates scope? | Notes |
|---|---|---|
| Named container (explicit ID) | Yes | ID pushed onto scope chain |
| Auto-ID container | No | Transparent |
| Window node | Yes | Appended to end of scope list |
| Custom widget | No | Widget IDs are transparent to scoping |

User-provided IDs must not contain `/`. The slash is the scope separator.

## ID resolution

```
sidebar (container)       ->  "sidebar"
  form (container)        ->  "sidebar/form"
    email (text_input)    ->  "sidebar/form/email"
    save (button)         ->  "sidebar/form/save"
```

## Event scope field

The scope list is reversed (nearest parent first, window ID last):

```gleam
WidgetClick(id: "save", scope: ["form", "sidebar", "main"], window_id: "main", ..)
```

Pattern match on the immediate parent with `[parent, ..]`:

```gleam
WidgetClick(id: "delete", scope: [item_id, ..], ..) ->
  delete_item(model, item_id)
```

## Command paths

Commands use the forward-slash scoped format:

```gleam
command.focus("form/email")
command.scroll_to("sidebar/list", 0.0)
```

In multi-window apps, use the `window_id#path` syntax:

```gleam
command.focus("settings#email")
command.scroll_to("main#sidebar/list", 0.0)
```

## Test selectors

```gleam
testing.find(session, "#save")
testing.click(session, "#sidebar/form/save")
testing.click(session, "main#save")
testing.assert_text(session, "#form/email", "")
```

## Accessibility cross-references

A11y props (`labelled_by`, `described_by`) reference widget IDs. Bare
IDs are resolved relative to the current scope during normalisation.

## See also

- [Lists and Inputs guide](../guides/06-lists-and-inputs.md)
- [Custom Widgets](custom-widgets.md)
- [Events](events.md)
