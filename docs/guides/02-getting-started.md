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

Open `gleam.toml` and add `plushie` to your dependencies:

```toml
[dependencies]
plushie = "~> 0.6"
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
import plushie
import plushie/app
import plushie/ui
import plushie/event.{type Event}

pub type Model {
  Model
}

pub fn main() {
  let app =
    app.simple(
      fn(_opts) { Model },
      fn(model, _event) { model },
      fn(_model) {
        ui.window("main", "Hello", [
          ui.text("greeting", "Hello from Plushie"),
        ])
      },
    )

  let assert Ok(_) = plushie.start(app, [])
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
- `ui.window` creates a native OS window. The first argument is the
  window's ID (here `"main"`). The second is the title bar text.
- `ui.text` displays a read-only string. The first argument is the
  widget ID, the second is the content to display.

## The Elm loop: a counter

Let us add interactivity. Create `src/counter.gleam`:

```gleam
import plushie
import plushie/app
import plushie/ui
import plushie/event.{type Event, WidgetClick}
import gleam/int

pub type Model {
  Model(count: Int)
}

pub fn main() {
  let app =
    app.simple(
      fn(_opts) { Model(count: 0) },
      update,
      view,
    )

  let assert Ok(_) = plushie.start(app, [])
}

fn update(model: Model, event: Event) -> Model {
  case event {
    WidgetClick(id: "increment", ..) -> Model(count: model.count + 1)
    WidgetClick(id: "decrement", ..) -> Model(count: model.count - 1)
    _ -> model
  }
}

fn view(model: Model) {
  ui.window("main", "Counter", [
    ui.column_("", [
      ui.text("count", "Count: " <> int.to_string(model.count)),
      ui.row_("", [
        ui.button_("increment", "+"),
        ui.button_("decrement", "-"),
      ]),
    ]),
  ])
}
```

Run it:

```bash
gleam run -m counter
```

Click the "+" and "-" buttons. The count updates on every click.

Here is what is new:

- `WidgetClick` is the event variant delivered when a button is clicked.
  It carries the `id` of the widget and a `scope` list of ancestor
  container IDs.
- `ui.column_` is a vertical layout container (the `_` suffix means no
  options). Children stack top to bottom.
- `ui.row_` is a horizontal layout container. Children flow left to right.
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
import plushie/testing

pub fn main() {
  gleeunit.main()
}

pub fn increment_test() {
  let session = testing.start(counter.app())
  testing.click(session, "#increment")
  testing.assert_text(session, "#count", "Count: 1")
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
without restarting the application. Pass `dev: True` in start options
to enable hot code reloading:

```gleam
let assert Ok(_) = plushie.start(app, [plushie.Dev(True)])
```

Or use the CLI with the `--watch` flag:

```bash
gleam run -m plushie/cli/gui -- counter --watch
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
- Change `ui.column_` to `ui.row_` and `ui.row_` to `ui.column_` to flip
  the layout. See how the same widgets rearrange.

When you are comfortable with the init/update/view cycle and hot reload,
you are ready for the next chapter.

---

Next: [Your First App](03-your-first-app.md)
