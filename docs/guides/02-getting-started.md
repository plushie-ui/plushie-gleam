# Getting Started

## Prerequisites

You need Gleam 1.x and Erlang/OTP 26 or later. Plushie runs on Linux,
macOS, and Windows.

## Creating a project

We will build the pad application from scratch. Start with a new Gleam
project:

```bash
gleam new plushie_pad
cd plushie_pad
```

Open `gleam.toml` and add `plushie_gleam` under `[dependencies]`:

```toml
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
plushie_gleam = ">= 0.5.0 and < 1.0.0"
```

Pin the range tightly pre-1.0. The API may change between minor
releases. Check the CHANGELOG when upgrading.

Fetch dependencies:

```bash
gleam deps download
```

## Installing the renderer

Plushie apps communicate with a Rust binary (built on
[Iced](https://github.com/iced-rs/iced)) that handles rendering and
platform input. Download the precompiled binary:

```bash
gleam run -m plushie/download
```

The binary lands under `build/plushie/bin/` and the SDK resolves it
automatically at runtime. The download is pinned to the
`plushie_rust_version` key in `gleam.toml`, so the binary and the SDK
always match.

If you prefer to build the renderer yourself (or need to for
[native widgets](13-custom-widgets.md)), see the
[CLI Commands reference](../reference/cli-commands.md). You will need
a Rust toolchain and `cargo-plushie` installed.

## Your first window

Create `src/hello.gleam`:

```gleam
import plushie/app
import plushie/command
import plushie/event.{type Event}
import plushie/gui
import plushie/node.{type Node}
import plushie/ui
import plushie/widget/window

fn init() {
  #(Nil, command.none())
}

fn update(model: Nil, _event: Event) {
  #(model, command.none())
}

fn view(_model: Nil) -> List(Node) {
  [
    ui.window("main", [window.Title("Plushie Pad")], [
      ui.text_("greeting", "Hello from Plushie"),
    ]),
  ]
}

pub fn main() {
  gui.run(app.simple(init, update, view), gui.default_opts())
}
```

Run it:

```bash
gleam run -m hello
```

A native window appears with the text "Hello from Plushie". Close the
window or press Ctrl+C in the terminal to stop.

Here is what each piece does:

- `app.simple(init, update, view)` bundles the three callbacks that
  drive the Elm loop. This shape covers apps whose message type is
  the built-in `Event`. For a custom message type, see
  `app.application` in the [App Lifecycle reference](../reference/app-lifecycle.md).
- `gui.run` resolves the renderer binary, starts the runtime, and
  blocks until the app exits.
- `ui.window` creates a native OS window. The first argument is the
  window's ID (`"main"`), the second is a list of options
  (`window.Title(...)`, etc.), and the third is the list of child
  widgets. Every `view` returns a list of windows; the empty list
  renders nothing.
- `ui.text_` displays a read-only string. The trailing underscore
  marks the no-options form. `ui.text` takes a third argument for
  typed options.

## The Elm loop: a counter

Let us add interactivity. Replace `src/hello.gleam` with a counter:

```gleam
import gleam/int
import plushie/app
import plushie/command
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/gui
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/window

pub type Model {
  Model(count: Int)
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "increment", ..))) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    Widget(Click(target: EventTarget(id: "decrement", ..))) -> #(
      Model(count: model.count - 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("Counter")], [
      ui.column(
        "content",
        [column.Padding(padding.all(16.0)), column.Spacing(8.0)],
        [
          ui.text_("count", "Count: " <> int.to_string(model.count)),
          ui.row("buttons", [row.Spacing(8.0)], [
            ui.button_("increment", "+"),
            ui.button_("decrement", "-"),
          ]),
        ],
      ),
    ]),
  ]
}

pub fn main() {
  gui.run(app.simple(init, update, view), gui.default_opts())
}
```

Run it again with `gleam run -m hello`. Click "+" and "-". The count
updates on every click.

Here is what is new:

- `Model` is a custom type with a single `count` field. The init
  function returns the initial model and a `command.none()` (no side
  effect on startup).
- `update` pattern-matches on `Widget(Click(target: EventTarget(id: ...)))`.
  The `..` elides the other `EventTarget` fields (`scope`,
  `window_id`, `full`); this is standard Gleam record pattern syntax.
  See the [Events reference](../reference/events.md) for the full
  event taxonomy.
- `ui.column` is a vertical layout container. `column.Padding` adds
  space around the edges, `column.Spacing` adds space between
  children. `padding.all(16.0)` sets equal padding on all sides; see
  the [Built-in Widgets reference](../reference/built-in-widgets.md)
  for the full prop list.
- `ui.row` is the horizontal counterpart, same opt shape.
- `ui.button_` is the no-options button builder. First argument is
  the widget ID, second is the label. Clicking it emits
  `Widget(Click(target: EventTarget(id: "increment", ..)))`.

The cycle: you click "+". The renderer sends a click event. The
runtime calls `update` with the current model and the event. Your
function pattern-matches on the ID, increments the count, and returns
a new model. The runtime calls `view` with that model, diffs the
resulting tree against the previous one, and sends patches to the
renderer. The renderer updates the display. The round trip happens in
milliseconds.

If `update` raises an exception, the runtime catches it, logs the
error, and reverts to the previous model. Your app keeps running.
Experimenting is safe.

## Your first test

Plushie apps are easy to test. Create `test/hello_test.gleam`:

```gleam
import gleeunit
import plushie/testing

import hello

pub fn main() {
  gleeunit.main()
}

pub fn clicking_increment_updates_count_test() {
  let ctx = testing.start(hello.app())
  let ctx = testing.click(ctx, "increment")
  testing.assert_text(ctx, "count", "Count: 1")
  testing.stop(ctx)
}
```

For the test to call `hello.app()`, expose it from `src/hello.gleam`:

```gleam
pub fn app() {
  app.simple(init, update, view)
}
```

Keep `main` calling `gui.run(app(), gui.default_opts())`.

Run it:

```bash
gleam test
```

The test starts the app against the real renderer binary (in `--mock`
mode by default), clicks the increment button, and asserts the
display text. We will add tests throughout the guide to verify each
chapter's work. The full testing story is covered in
[chapter 15](15-testing.md) and the
[Testing reference](../reference/testing.md).

## Enabling hot reload

During development you want changes reflected without restarting the
app. Set `dev: True` on `GuiOpts`:

```gleam
pub fn main() {
  gui.run(app(), gui.GuiOpts(..gui.default_opts(), dev: True))
}
```

Start the app with `gleam run -m hello`, then change the `column.Spacing`
value from `8.0` to `32.0` and save. The window updates with the new
spacing and the count stays where it was. Under the hood, a dev
server watches `src/` for `.gleam` changes, runs `gleam build`, and
hot-loads the changed BEAM modules without tearing down the app.

This is how we will develop throughout the guide. Keep the app
running, edit code, save, and watch the window update. In
[chapter 4](04-the-development-loop.md) we wire hot reload into a
longer-lived development loop.

## Try it

With the counter running and hot reload active, try these changes one
at a time:

- Enlarge the count display: add `[text.Size(24.0)]` as the third
  argument to `ui.text`, replacing the `ui.text_` call:
  `ui.text("count", "Count: " <> int.to_string(model.count), [text.Size(24.0)])`.
  Add `import plushie/widget/text` at the top of the file.
- Add a reset button. Add `ui.button_("reset", "Reset")` to the row,
  and add a matching `update` clause that returns `Model(count: 0)`.
- Flip the layout. Swap `ui.column` and `ui.row` (and their
  respective opt modules) to rearrange the widgets horizontally and
  vertically.

When you are comfortable with the init / update / view cycle and hot
reload, move on to the next chapter and start building the pad.

---

Next: [Your First App](03-your-first-app.md)
