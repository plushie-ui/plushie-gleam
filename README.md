# Plushie for Gleam

Build native desktop apps in Gleam. **[Pre-1.0](#status)**

Plushie is a desktop GUI framework that allows you to write your entire
application in Gleam -- state, events, UI -- and get native windows
on Linux, macOS, and Windows. Rendering is powered by
[iced](https://github.com/iced-rs/iced), a cross-platform GUI library
for Rust, which plushie drives as a precompiled binary behind the scenes.

<!-- test: readme_counter_init_test, readme_counter_view_structure_test -- keep this code block in sync with the test -->
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
    WidgetClick(id: "inc", ..) -> #(Model(count: model.count + 1), command.none())
    WidgetClick(id: "dec", ..) -> #(Model(count: model.count - 1), command.none())
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Counter")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(8)], [
      ui.text_("count", "Count: " <> int.to_string(model.count)),
      ui.row("buttons", [ui.spacing(8)], [
        ui.button_("inc", "+"),
        ui.button_("dec", "-"),
      ]),
    ]),
  ])
}

pub fn main() {
  gui.run(app.simple(init, update, view), gui.default_opts())
}
```

```bash
gleam run -m examples/counter
```

This is one of [8 examples](examples/) included in the repo, from a
minimal counter to a full widget catalog. Edit them while the GUI is
running and see changes instantly.

## Getting started

Add plushie to your dependencies:

```sh
gleam add plushie_gleam
```

Then:

```bash
bin/plushie_download                    # download precompiled binary
gleam run -m my_app                   # run your app
```

Pin to an exact version and read the
[CHANGELOG](CHANGELOG.md) carefully when upgrading.

The precompiled binary requires no Rust toolchain. To build from
source instead, install [rustup](https://rustup.rs/) and run
`bin/plushie_build`. See the
[getting started guide](docs/getting-started.md) for the full
walkthrough.

## Features

- **38 built-in widget types** -- buttons, text inputs, sliders,
  tables, markdown, canvas, and more. Easy to build your own.
  [Layout guide](docs/layout.md)
- **22 built-in themes** -- light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, and more. Custom
  palettes and per-widget style overrides.
  [Theming guide](docs/theming.md)
- **Multi-window** -- declare window nodes in your widget tree;
  the framework opens, closes, and manages them automatically.
  [App behaviour guide](docs/app-behaviour.md)
- **Platform effects** -- native file dialogs, clipboard, OS
  notifications. [Effects guide](docs/effects.md)
- **Accessibility** -- screen reader support via
  [accesskit](https://accesskit.dev) on all platforms.
  [Accessibility guide](docs/accessibility.md)
- **Live reload** -- edit code, see changes instantly. Enabled by
  default in dev mode.
- **Extensions** -- multiple paths to custom widgets:
  - **Compose** existing widgets into higher-level components with
    pure Gleam. No Rust, no binary rebuild.
  - **Draw** on the canvas with shape primitives for charts, gauges,
    diagrams, and other custom 2D rendering.
  - **Native** -- implement `WidgetExtension` in Rust for full
    control over rendering, state, and event handling.
  - [Extensions guide](docs/extensions.md)
- **Remote rendering** -- native desktop UI for apps running on
  servers or embedded devices. Dashboards, admin tools, IoT
  diagnostics -- over SSH with configurable event throttling.
  [Running guide](docs/running.md)

## Testing

Plushie ships a test framework with three interchangeable backends.
Write your tests once, run them at whatever fidelity you need:

- **Mocked** -- millisecond tests, no display server. Uses a shared
  mock process for fast logic and interaction testing.
- **Headless** -- real rendering via
  [tiny-skia](https://github.com/linebender/tiny-skia), no display
  server needed. Supports screenshots for pixel regression in CI.
- **Windowed** -- real windows with GPU rendering. Platform effects,
  real input, the works.

```gleam
import gleeunit/should
import gleam/option
import plushie/testing as test
import plushie/testing/element

pub fn add_and_complete_a_todo_test() {
  let session = test.start(todo_app)
  let session = test.type_text(session, "new_todo", "Buy milk")
  let session = test.submit(session, "new_todo")

  let assert option.Some(el) = test.find(session, "todo_count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "1 item")
  should.be_true(option.is_some(test.find(session, "todo:1")))

  let session = test.toggle(session, "todo:1")
  let session = test.click(session, "filter_completed")

  let assert option.Some(el) = test.find(session, "todo_count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "0 items")
  should.be_true(option.is_none(test.find(session, "todo:1")))
}
```

See the [testing guide](docs/testing.md) for the full API, backend
details, and CI configuration.

## How it works

Under the hood, a renderer built on
[iced](https://github.com/iced-rs/iced) handles window drawing and
platform integration. Your Gleam code sends widget trees to the
renderer over stdin; the renderer draws native windows and sends
user events back over stdout.

You don't need Rust to use plushie. The renderer is a precompiled
binary, similar to how your app talks to a database without you
writing C. If you ever need custom native rendering, the
[extension system](docs/extensions.md) lets you write Rust for just
those parts.

The same protocol works over a local pipe, an SSH connection, or
any bidirectional byte stream -- your code doesn't need to change.
See the [running guide](docs/running.md) for deployment options.

## Status

Pre-1.0. The core works -- 38 widget types, event system, 22 themes,
multi-window, testing framework, accessibility -- but the API is
still evolving:

- Pin to an exact version and read the
  [CHANGELOG](CHANGELOG.md) when upgrading.
- The extension framework (`plushie/extension`) is the least stable
  part of the API.

## Documentation

Guides are in [`docs/`](docs/) and will be on
[hexdocs](https://hexdocs.pm/plushie_gleam) once published:

- [Getting started](docs/getting-started.md) -- setup, first app, CLI helpers, dev mode
- [Tutorial](docs/tutorial.md) -- build a todo app step by step
- [App behaviour](docs/app-behaviour.md) -- the Gleam API contract, multi-window
- [Layout](docs/layout.md) -- length, padding, alignment, spacing
- [Events](docs/events.md) -- full event taxonomy
- [Commands and subscriptions](docs/commands.md) -- async work, timers, widget ops
- [Effects](docs/effects.md) -- native platform features
- [Theming](docs/theming.md) -- themes, custom palettes, styling
- [Composition patterns](docs/composition-patterns.md) -- tabs, sidebars, modals, cards, state helpers
- [Scoped IDs](docs/scoped-ids.md) -- hierarchical ID namespacing
- [Testing](docs/testing.md) -- three-backend test framework and pixel regression
- [Accessibility](docs/accessibility.md) -- accesskit integration, a11y props
- [Extensions](docs/extensions.md) -- custom widgets, publishing packages

## Development

```bash
./bin/preflight                       # run all CI checks locally
```

Mirrors CI and stops on first failure: format, compile, test.

## System requirements

The precompiled binary (`bin/plushie_download`) has no additional
dependencies. To build from source, install a Rust toolchain via
[rustup](https://rustup.rs/) and the platform-specific libraries:

- **Linux (Debian/Ubuntu):**
  `sudo apt-get install libxkbcommon-dev libwayland-dev libx11-dev cmake fontconfig pkg-config`
- **Linux (Arch):**
  `sudo pacman -S libxkbcommon wayland libx11 cmake fontconfig pkgconf`
- **macOS:** `xcode-select --install`
- **Windows:**
  [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
  with "Desktop development with C++"

## Links

| | |
|---|---|
| Gleam SDK | [github.com/plushie-ui/plushie-gleam](https://github.com/plushie-ui/plushie-gleam) |
| Elixir SDK | [github.com/plushie-ui/plushie-elixir](https://github.com/plushie-ui/plushie-elixir) |
| Renderer | [github.com/plushie-ui/plushie](https://github.com/plushie-ui/plushie) |
| Rust crate | [crates.io/crates/plushie](https://crates.io/crates/plushie) |

## License

MIT
