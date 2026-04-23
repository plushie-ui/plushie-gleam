# Getting Started

## Prerequisites

You need **Gleam** 1.0 or later with **Erlang/OTP** 25+. Plushie works
on Linux, macOS, and Windows.

## Creating a project

Start with a new Gleam project:

```bash
gleam new plushie_pad
cd plushie_pad
```

Open `gleam.toml` and add `plushie_gleam` to your dependencies:

```toml
[dependencies]
plushie_gleam = "~> 0.5"
```

Pin to an exact version pre-1.0. The API may change between minor
releases.

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

The binary is placed under `build/` and Plushie resolves it
automatically at runtime.

If you prefer to build the renderer yourself (or need to for
[native widgets](13-custom-widgets.md)), use the build command. You will
need a Rust toolchain installed:

```bash
gleam run -m plushie/build
```

## Your first window

Create `src/hello.gleam`:

```gleam
import plushie/app
import plushie/command
import plushie/gui
import gleam/option.{type Option, Some}
import plushie/ui
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/widget/window

pub type Model {
  Model
}

pub fn app() {
  app.simple(init, update, view)
}

pub fn main() {
  gui.run(app(), gui.default_opts())
}

fn init() {
  #(Model, command.none())
}

fn update(model: Model, _event: Event) {
  #(model, command.none())
}

fn view(_model: Model) -> Option(Node) {
  Some(
    ui.window("main", [window.Title("Hello")], [
      ui.text_("greeting", "Hello from Plushie"),
    ]),
  )
}
```

Run it:

```bash
gleam run -m hello
```

A native window appears with the text "Hello from Plushie". Close the
window or press Ctrl+C in the terminal to stop.

Here is what each piece does:

- `app.simple` creates an app with the three Elm architecture callbacks:
  `init`, `update`, and `view`. The `simple` variant uses `Event` as the
  message type directly.
- `gui.run` starts the desktop runtime with `gui.default_opts()`.
- `ui.window` creates a native OS window. The first argument is the
  window's ID (here `"main"`). Window options such as the title live in
  the second argument, here `[window.Title("Hello")]`.
- `ui.text_` displays a read-only string with no extra options. Use
  `ui.text` when you need text-specific opts.

## The Elm loop: a counter

Let us add interactivity. Create `src/counter.gleam`:

```gleam
import plushie/app
import plushie/command
import plushie/gui
import gleam/int
import gleam/option.{type Option, Some}
import plushie/ui
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/widget/column
import plushie/widget/row
import plushie/widget/text
import plushie/widget/window

pub type Model {
  Model(count: Int)
}

pub fn app() {
  app.simple(init, update, view)
}

pub fn main() {
  gui.run(app(), gui.default_opts())
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "increment", ..))) ->
      #(Model(count: model.count + 1), command.none())
    Widget(Click(target: EventTarget(id: "decrement", ..))) ->
      #(Model(count: model.count - 1), command.none())
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Option(Node) {
  Some(
    ui.window("main", [window.Title("Counter")], [
      ui.column(
        "content",
        [column.Padding(padding.all(16.0)), column.Spacing(8.0)],
        [
          ui.text("count", "Count: " <> int.to_string(model.count), [
            text.Size(20.0),
          ]),
          ui.row("buttons", [row.Spacing(8.0)], [
            ui.button_("increment", "+"),
            ui.button_("decrement", "-"),
          ]),
        ],
      ),
    ]),
  )
}
```

Run it:

```bash
gleam run -m counter
```

Click the "+" and "-" buttons. The count updates on every click.

Here is what is new:

- `Widget(Click(...))` is the event variant delivered when a button is
  clicked. `EventTarget` carries the widget `id` plus scoped path data.
- `ui.column` is a vertical layout container. Children stack top to bottom.
- `ui.row` is a horizontal layout container. Children flow left to right.
- `ui.button_` is a clickable button. The first argument is the widget ID,
  the second is the label text.

The cycle works like this: you click "+". The renderer sends a click
event. The runtime calls `update` with your current model and the event.
Your function pattern-matches on the ID, increments the count, and returns
the new model. The runtime calls `view` with that new model, diffs the
resulting tree against the previous one, and sends patches to the renderer.
The renderer updates the display. The whole round trip happens in
milliseconds.

## Your first test

Plushie apps are easy to test. Write a test for the counter in
`test/counter_test.gleam`:

```gleam
import gleeunit
import counter
import plushie/testing

pub fn main() {
  gleeunit.main()
}

pub fn increment_test() {
  let session = testing.start(counter.app())
  let session = testing.click(session, "increment")
  testing.assert_text(session, "count", "Count: 1")
}
```

Run it:

```bash
gleam test
```

The test starts a real app instance, clicks the increment button, and
verifies the display text changed. We will add tests throughout the guide.
The full testing framework is covered in [chapter 15](15-testing.md).

## Enabling hot reload

During development, you want to see changes reflected immediately
without restarting the application. Set `dev: True` in `GuiOpts` to
enable hot code reloading:

```gleam
let opts = gui.GuiOpts(..gui.default_opts(), dev: True)
gui.run(app(), opts)
```

Then run the app module normally:

```bash
gleam run -m counter
```

The dev server watches your `src/` directory for `.gleam` file changes,
runs `gleam build`, hot-loads changed BEAM modules, and signals the
runtime to re-render. Your model state is preserved across hot reloads.

## Try it

With the counter running and hot reload active, try these changes one
at a time. Save after each one and watch the window update:

- Change the button labels from "+" and "-" to "Increment" and "Decrement".
- Add a reset button. Put `ui.button_("reset", "Reset")` in the row
  and add a matching clause in `update` that sets count back to `0`.
- Change `ui.column` to `ui.row` and `ui.row` to `ui.column` to flip
  the layout. Keep the matching option modules in sync too. See how the
  same widgets rearrange.

When you are comfortable with the init/update/view cycle and hot reload,
you are ready for the next chapter.

---

Next: [Your First App](03-your-first-app.md)
