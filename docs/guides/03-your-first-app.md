# Your First App

In the previous chapter we built a counter and learned the init/update/view
cycle. Now we will start building a more complex layout: a code editor on
the left, a preview area on the right, and a save button.

## Two widget APIs

Gleam has no macro system, so Plushie offers two ways to build widgets:

**Convenience functions** in `plushie/ui` with per-widget option lists:

```gleam
import plushie/ui
import plushie/widget/button
import plushie/prop/length.{Fill}

ui.button("save", "Save", [button.Width(Fill)])
```

**Typed builders** in `plushie/widget/*` with chainable setters:

```gleam
import plushie/widget/button
import plushie/prop/length.{Fill}

button.new("save", "Save")
|> button.width(Fill)
|> button.build()
```

Both produce the same output. The convenience functions are shorter for
simple cases; the builders are clearer when you have many options. You can
mix both styles freely.

The `_` suffix variants (`ui.button_`, `ui.text_`, etc.) take no options,
keeping simple cases compact.

## The layout

Here is a split-pane layout with an editor and preview:

```gleam
import gleam/option.{Some}
import plushie/node.{type Node}
import plushie/ui
import plushie/widget/window
import plushie/widget/column
import plushie/widget/row
import plushie/widget/container
import plushie/widget/text_editor
import plushie/prop/length.{Fill, FillPortion}
import plushie/prop/padding

fn view(model: Model) -> Option(Node) {
  Some(
    ui.window("main", [window.Title("My App")], [
      ui.column("layout", [column.Width(Fill), column.Height(Fill)], [
        ui.row("split", [row.Width(Fill), row.Height(Fill)], [
          ui.text_editor("editor", model.source, [
            text_editor.Width(FillPortion(1)),
            text_editor.Height(Fill),
          ]),
          ui.container("preview", [
            container.Width(FillPortion(1)),
            container.Height(Fill),
            container.Padding(padding.all(16.0)),
          ], [
            ui.text_("placeholder", "Preview area"),
          ]),
        ]),
        ui.row("actions", [], [
          ui.button_("save", "Save"),
        ]),
      ]),
    ]),
  )
}
```

### text_editor

`text_editor` is a multi-line editing widget. The `content` argument
seeds the initial text, and subsequent changes arrive as
`Widget(Input(...))` events with the full content as the value.

Some widgets hold renderer-side state (cursor position, scroll offset,
text selection). `text_editor`, `text_input`, `combo_box`, `scrollable`,
and `pane_grid` all fall into this category. These widgets need an explicit
string ID so the renderer can match them to their state across renders.

### fill_portion

`FillPortion(1)` gives the editor and preview equal width. Change one
to `FillPortion(2)` and it takes twice the space. We cover sizing in
depth in [chapter 7](07-layout.md).

---

Next: [The Development Loop](04-the-development-loop.md)
