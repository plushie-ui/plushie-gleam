# Getting started

Build native desktop GUIs from Gleam. Plushie handles rendering via
iced (Rust) while you own state, logic, and UI trees in pure Gleam.

## Prerequisites

- **Gleam** 1.0+ and **Erlang/OTP** 26+
- **Rust** 1.75+ (install via [rustup.rs](https://rustup.rs))
- **System libraries** for your platform:
  - Linux: a C compiler, `pkg-config`, and display server headers
    (e.g. `libxkbcommon-dev`, `libwayland-dev` on Debian/Ubuntu)
  - macOS: Xcode command-line tools (`xcode-select --install`)
  - Windows: Visual Studio C++ build tools

## Setup

### 1. Create a new Gleam project

```sh
gleam new my_app
cd my_app
```

### 2. Add plushie as a dependency

```sh
gleam add plushie
```

### 3. Fetch dependencies and build the renderer

```sh
bin/plushie_build
```

The build step compiles the Rust renderer binary. First build takes a
few minutes; subsequent builds are fast.

## Your first app: a counter

Create `src/my_app.gleam`:

<!-- test: getting_started_counter_init_test, getting_started_counter_increment_test, getting_started_counter_decrement_test, getting_started_counter_unknown_event_test, getting_started_counter_view_test, getting_started_counter_view_after_increments_test -- keep this code block in sync with the test -->
```gleam
import gleam/int
import plushie/app
import plushie/cli/gui
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/ui

type Model {
  Model(count: Int)
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "increment", ..) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    WidgetClick(id: "decrement", ..) -> #(
      Model(count: model.count - 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Counter")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(8)], [
      ui.text("count", "Count: " <> int.to_string(model.count), [
        ui.font_size(20.0),
      ]),
      ui.row("buttons", [ui.spacing(8)], [
        ui.button_("increment", "+"),
        ui.button_("decrement", "-"),
      ]),
    ]),
  ])
}

pub fn main() {
  gui.run(app.simple(init, update, view), gui.default_opts())
}
```

Run it:

```sh
gleam run -m my_app
```

A native window appears with the count and two buttons.

## The Elm architecture

Plushie follows the Elm architecture. Your app is built from three
functions passed to `app.simple`:

- **`init`** -- returns a tuple of the initial model and a command.
- **`update`** -- takes the current model and an event, returns
  a tuple of the new model and a command. Pure function. See
  [Commands](commands.md).
- **`view`** -- takes the model and returns a UI tree. Plushie diffs
  trees and sends only patches to the renderer.

For apps that need subscriptions, use `app.with_subscriptions` to
add a subscribe callback that returns a list of active subscriptions
(timers, keyboard events).

See [App behaviour](app-behaviour.md) for the full API.

## Event types

Events are constructors of the `Event` type in `plushie/event`.
Pattern match in `update`:

| Event | Meaning |
|---|---|
| `WidgetClick(id: id, ..)` | Button click |
| `WidgetInput(id: id, value: val, ..)` | Text input change |
| `WidgetSubmit(id: id, value: val, ..)` | Text input Enter |
| `WidgetToggle(id: id, value: val, ..)` | Checkbox/toggler |
| `WidgetSlide(id: id, value: val, ..)` | Slider moved |
| `WidgetSelect(id: id, value: val, ..)` | Pick list/radio |
| `TimerTick(tag: tag, timestamp: ts)` | Timer fired |

See [Events](events.md) for the full taxonomy.

## CLI helpers

Plushie provides CLI modules for common tasks:

```gleam
// src/my_app.gleam -- build and run
import plushie/cli/gui

pub fn main() {
  gui.run(my_app(), gui.default_opts())
}
```

```gleam
// src/inspect_app.gleam -- print UI tree as JSON
import plushie/cli/inspect

pub fn main() {
  inspect.run(my_app())
}
```

```bash
bin/plushie_build                       # build renderer only
bin/plushie_build --release             # release build
bin/plushie_download                    # download precompiled binary
```

Use `GuiOpts` to configure the runner:

```gleam
gui.run(my_app(), GuiOpts(..gui.default_opts(), json: True))   // JSON wire format
gui.run(my_app(), GuiOpts(..gui.default_opts(), dev: True))    // live reload
```

## Debugging

Use JSON wire format to see messages between Gleam and the renderer:

```gleam
gui.run(my_app(), GuiOpts(..gui.default_opts(), json: True))
```

Enable verbose renderer logging:

```sh
RUST_LOG=plushie=debug gleam run -m my_app
```

## Error handling

If `update` or `view` raises, the runtime catches the exception,
logs it, and continues with the previous state. The GUI does not
crash. Fix the code and the next event works normally.

## Dev mode

Live code reloading without losing application state. Enable it
by setting `dev: True` in your `GuiOpts`:

```gleam
gui.run(my_app(), GuiOpts(..gui.default_opts(), dev: True))
```

In dev mode, the dev server watches `src/` for changes, recompiles,
hot-reloads BEAM modules, and triggers a re-render without losing
app state. Edit any `.gleam` file, save, and the GUI updates in
place. The model is preserved -- only `view` is re-evaluated with
the new code.

Try it with the counter example -- run with `dev: True`, then edit
your view function and save. The window updates instantly.

## Next steps

- [Tutorial: building a todo app](tutorial.md) -- step-by-step guide
- Browse the [examples](https://github.com/plushie-ui/plushie-gleam/tree/main/examples) for patterns
- [App behaviour](app-behaviour.md) -- full API
- [Layout](layout.md) -- sizing and positioning widgets
- [Commands](commands.md) -- async work, file dialogs, effects
- [Events](events.md) -- complete event taxonomy
- [Testing](testing.md) -- writing tests against your UI
- [Theming](theming.md) -- custom themes and palettes
