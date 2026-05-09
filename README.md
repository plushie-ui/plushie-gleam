# Plushie for Gleam

Build native desktop apps in Gleam. **[Pre-1.0](#status)**

Write your entire application in Gleam (state, events, UI) and get
native windows on Linux, macOS, and Windows. The
[renderer](https://github.com/plushie-ui/plushie-rust) is built on
[Iced](https://github.com/iced-rs/iced) and ships as a precompiled
binary, no Rust toolchain required.

SDKs are also available for
[Elixir](https://github.com/plushie-ui/plushie-elixir),
[Python](https://github.com/plushie-ui/plushie-python),
[Ruby](https://github.com/plushie-ui/plushie-ruby), and
[TypeScript](https://github.com/plushie-ui/plushie-typescript).

## Quick start

<!-- test: readme_counter_init_test, readme_counter_view_structure_test -- keep this code block in sync with the test -->
```gleam
import gleam/int
import plushie/app
import plushie/gui
import plushie/command
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/window

type Model {
  Model(count: Int)
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "inc", ..))) ->
      #(Model(count: model.count + 1), command.none())
    Widget(Click(target: EventTarget(id: "dec", ..))) ->
      #(Model(count: model.count - 1), command.none())
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
            ui.button_("inc", "+"),
            ui.button_("dec", "-"),
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

Add plushie to your dependencies and run:

```sh
gleam add plushie_gleam
gleam run -m plushie/download         # download precompiled binary
gleam run -m my_app                   # run your app
```

Pin to an exact version and read the
[CHANGELOG](CHANGELOG.md) carefully when upgrading.

The precompiled binary requires no Rust toolchain. To build from
source instead, install [rustup](https://rustup.rs/) and
[`cargo-plushie`](https://crates.io/crates/cargo-plushie) (see the
installation hints printed by `plushie/build` if it's not yet on
PATH), then run `gleam run -m plushie/build`.

The repo includes [several examples](examples/) you can try. Edit
them while the GUI is running and see changes instantly. See the
[getting started guide](docs/guides/02-getting-started.md) for the
full walkthrough, or browse the [docs](docs/README.md) for all guides
and references.

## How it works

Under the hood, a renderer built on
[iced](https://github.com/iced-rs/iced) handles window drawing and
platform integration. Your Gleam code sends widget trees to the
renderer over stdin; the renderer draws native windows and sends
user events back over stdout.

You don't need Rust to use plushie. The renderer is a precompiled
binary, similar to how your app talks to a database without you
writing C. If you ever need custom native rendering, the
[custom widgets guide](docs/guides/13-custom-widgets.md) shows how to
compose widgets in Gleam and when to drop to Rust for native widgets.

The same protocol works over a local pipe, an SSH connection, or
any bidirectional byte stream - your code doesn't need to change.
See the [shared state guide](docs/guides/16-shared-state.md) for
deployment and remote rendering options.

## Features

- **Elm architecture** - init, update, view. State lives in
  Gleam, pure functions, predictable updates
- **Built-in widgets** - layout, input, display, and interactive
  widgets out of the box
- **Canvas** - shapes, paths, gradients, transforms, and
  interactive elements for custom 2D drawing
- **Themes** - dark, light, nord, catppuccin, tokyo night, and
  more, with custom palettes and per-widget style overrides
- **Animation** - renderer-side transitions, springs, and
  sequences with no wire traffic per frame
- **Multi-window** - declare windows in your view; the framework
  manages the rest
- **Platform effects** - native file dialogs, clipboard, OS
  notifications
- **Accessibility** - keyboard navigation, screen readers, and
  focus management via [AccessKit](https://accesskit.dev)
- **Custom widgets** - compose existing widgets in pure Gleam,
  draw on the canvas, or extend with native Rust
- **Hot reload** - edit code, see changes instantly with full
  state preservation (requires `file_system` dep and Elixir; see Getting Started)
- **Remote rendering** - app on a server or embedded device,
  renderer on a display machine over SSH or any byte stream
- **Multi-target** - runs on BEAM and JavaScript, same codebase

## Testing and automation

Tests run through the real renderer binary, not mocks. Interact like
a user: click, type, find elements, assert on text. Three
interchangeable backends:

- **Mock** - millisecond tests, no display server
- **Headless** - real rendering via
  [tiny-skia](https://github.com/linebender/tiny-skia), supports
  screenshots for pixel regression in CI
- **Windowed** - real windows with GPU rendering, platform effects,
  real input

```gleam
import gleeunit/should
import gleam/option
import plushie/testing
import plushie/testing/element

pub fn add_and_complete_a_todo_test() {
  let session = testing.start(todo_app)
  let session = testing.type_text(session, "new_todo", "Buy milk")
  let session = testing.submit(session, "new_todo")

  let assert option.Some(el) = testing.find(session, "todo_count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "1 item")
  should.be_true(option.is_some(testing.find(session, "todo:1")))

  let session = testing.toggle(session, "todo:1")
  let session = testing.click(session, "filter_completed")

  let assert option.Some(el) = testing.find(session, "todo_count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "0 items")
  should.be_true(option.is_none(testing.find(session, "todo:1")))
}
```

See the [testing reference](docs/reference/testing.md) for the full
API, backend details, and CI configuration.

## Status

Pre-1.0. The core works (built-in widgets, event system, themes,
multi-window, testing framework, accessibility) but the API is
still evolving. Pin to an exact version and read the
[CHANGELOG](CHANGELOG.md) when upgrading.

## License

MIT
