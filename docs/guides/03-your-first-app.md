# Your First App

In the previous chapter we built a counter and learned the init/update/view
cycle. Now we start building **Plushie Pad**, a live widget editor that
grows with you throughout this guide.

In this chapter we set up the pad's layout: a code editor on the left, a
preview area on the right, and a save button. The preview does not do
anything yet; we wire that up in the next chapter. For now the focus is
on how views are composed.

## Two widget APIs

Gleam has no macro DSL, so Plushie exposes two widget APIs: `ui.*`
convenience functions with typed opt lists, and per-widget builder
modules with chainable setters. Both produce the same nodes and can be
mixed inside the same view.

The opt-list form is compact and reads well for small widgets:

```gleam
import plushie/prop/length.{Fill}
import plushie/ui
import plushie/widget/column

ui.column("root", [column.Spacing(8.0), column.Width(Fill)], [
  ui.text_("greeting", "Hello, Plushie!"),
])
```

The builder form is chainable and useful for helpers that tweak a
widget gradually or set many options:

```gleam
import plushie/prop/length.{Fill}
import plushie/widget/column
import plushie/widget/text

column.new("root")
|> column.spacing(8.0)
|> column.width(Fill)
|> column.push(text.new("greeting", "Hello, Plushie!") |> text.build())
|> column.build()
```

Both call sites return a `Node`. Pick whichever reads best at each call
site; this guide mixes both.

## Plushie Pad and Erlang experiments

Plushie Pad compiles code typed into the editor at runtime. BEAM ships
with an Erlang compiler, but there's no Gleam compiler we can call from
a running program, so experiments are written in Erlang. If you haven't
used Erlang before, copy the snippets as-is and they'll work. When
you're ready to understand what's happening under the hood, the
[Erlang interop reference](../reference/erlang-interop.md) covers the
Gleam-to-Erlang mapping.

The pad stores experiments as `.erl` files under `priv/experiments/`.
A first experiment looks like this:

```erlang
-module(hello).
-export([view/0]).

view() ->
    pad_helpers:column(<<"root">>,
        [{padding, pad_helpers:padding_all(16.0)}, {spacing, 8.0}],
        [
            pad_helpers:text_size(<<"greeting">>, <<"Hello, Plushie!">>, 24.0),
            pad_helpers:button(<<"btn">>, <<"Click Me">>)
        ]).
```

The helpers in `pad_helpers` are thin wrappers around the generated
Erlang atoms for `plushie@ui` calls. Nothing in this chapter depends
on it; we ship it so the pad has something to render once compilation
lands in the next chapter.

## The complete pad

Here is the module for this chapter. Save it as
`src/plushie_pad/app.gleam` and we walk through the key parts below.

```gleam
import gleam/option.{type Option, None, Some}
import plushie/app.{type App}
import plushie/command.{type Command}
import plushie/event.{
  type Event, EventTarget, Input, Widget,
}
import plushie/node.{type Node}
import plushie/prop/font.{Monospace}
import plushie/prop/length.{Fill, FillPortion}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/text_editor
import plushie/widget/window

pub type Model {
  Model(source: String, preview: Option(Node), error: Option(String))
}

pub fn app() -> App(Model, Event) {
  app.simple(init, update, view)
}

fn init() -> #(Model, Command(Event)) {
  let model =
    Model(
      source: "% Write some Plushie code here\n",
      preview: None,
      error: None,
    )
  #(model, command.none())
}

fn update(model: Model, evt: Event) -> #(Model, Command(Event)) {
  case evt {
    Widget(Input(target: EventTarget(id: "editor", ..), value: s)) -> #(
      Model(..model, source: s),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("Plushie Pad")], [
      ui.column("root", [column.Width(Fill), column.Height(Fill)], [
        ui.row("split", [row.Width(Fill), row.Height(Fill)], [
          editor_pane(model),
          preview_pane(model),
        ]),
        ui.row("toolbar", [row.Padding(padding.all(8.0))], [
          ui.button_("save", "Save"),
        ]),
      ]),
    ]),
  ]
}

fn editor_pane(model: Model) -> Node {
  ui.text_editor("editor", model.source, [
    text_editor.Width(FillPortion(1)),
    text_editor.Height(Fill),
    text_editor.HighlightSyntax("erlang"),
    text_editor.Font(Monospace),
  ])
}

fn preview_pane(model: Model) -> Node {
  let content = case model.preview {
    Some(tree) -> tree
    None -> ui.text_("placeholder", "Press Save to compile and preview")
  }
  ui.container(
    "preview",
    [
      container.Width(FillPortion(1)),
      container.Height(Fill),
      container.Padding(padding.all(16.0)),
    ],
    [content],
  )
}
```

The project's `src/plushie_pad.gleam` entry point hands this off to the
runtime:

```gleam
import gleam/io
import plushie
import plushie_pad/app as pad_app

pub fn main() {
  case plushie.start(pad_app.app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "plushie_pad failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
```

Run it:

```bash
gleam run -m plushie_pad
```

The editor appears on the left with Erlang syntax highlighting, and the
placeholder text fills the preview on the right. The save button is
there but does not do anything yet. We wire it up in the next chapter.

## Walking through the code

### The model

`app.simple` takes a zero-argument `init`. The returned record is the
initial model. `Option(Node)` lets us distinguish "no preview yet"
from "we have a tree to render" without inventing a sentinel.

### text_editor

`text_editor` is a multi-line editing widget with syntax highlighting
support. The `content` argument seeds the initial text, and subsequent
changes arrive as `Widget(Input(..))` events with the full content as
the value. `text_editor.HighlightSyntax("erlang")` names a `syntect`
language key (`"ex"`, `"rust"`, `"js"`, and so on).

Some widgets hold renderer-side state (cursor position, scroll offset,
text selection): `text_editor`, `text_input`, `combo_box`, `scrollable`,
`pane_grid`. They need an explicit string ID so the renderer can match
them to their state across renders. If the ID changes, the state resets.
Layout widgets like `column` and `row` have no renderer-side state, so
any stable ID works.

### The view

`view` returns a `List(Node)` of top-level windows. We return a
one-element list containing a `window` that wraps a `column`. The
column splits into a main content `row` and a toolbar `row`.

- `FillPortion(1)` gives the editor and preview equal width. Change
  one to `FillPortion(2)` and it takes twice the space. Sizing is
  covered in [chapter 7](07-layout.md).
- The preview pane is wrapped in `container("preview", ...)`. The
  named container matters later, when we need to distinguish events
  from preview widgets from events from the pad's own widgets.
- `model.preview` holds `None` until compilation is wired up, so the
  `case` on the `Option` renders the placeholder. Returning a
  different widget for each branch is the normal pattern; there is no
  "nil child" fallthrough in Gleam.

### Events

The editor emits `Widget(Input(..))` events on every keystroke. We
pattern-match on the target ID and pull the new value off the event
record. The catch-all arm ignores everything else, including save
button clicks, which we handle in the next chapter.

## Verify it

Add a test for the pad layout in `test/pad_test.gleam`:

```gleam
import gleeunit
import plushie/testing
import plushie_pad/app as pad_app

pub fn main() {
  gleeunit.main()
}

pub fn pad_has_editor_and_preview_panes_test() {
  let ctx = testing.start(pad_app.app())

  testing.assert_exists(ctx, "#editor")
  testing.assert_exists(ctx, "#preview")
  testing.assert_text(
    ctx,
    "#preview/placeholder",
    "Press Save to compile and preview",
  )

  testing.stop(ctx)
}
```

This verifies the split-pane layout is rendering correctly.

## Try it

With the pad running:

- Type some Erlang code in the editor. The syntax highlighting updates
  as you type.
- Change `FillPortion(1)` to `FillPortion(2)` on the editor pane,
  restart the pad, and the editor takes twice the width.
- Add a second button to the toolbar: `ui.button_("clear", "Clear")`.

The pad is a shell right now, a text editor next to an empty preview.
The next chapter wires up hot reload and code compilation so
experiments render as you save them.

---

Next: [The Development Loop](04-the-development-loop.md)
