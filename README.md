# toddy

Build native desktop apps in Gleam. **Pre-1.0**

Toddy is a desktop GUI framework that allows you to write your entire
application in Gleam -- state, events, UI -- and get native windows
on Linux, macOS, and Windows. Rendering is powered by
[iced](https://github.com/iced-rs/iced), a cross-platform GUI library
for Rust, which toddy drives as a precompiled binary behind the scenes.

```gleam
import toddy
import toddy/ui
import toddy/event.{type Event, WidgetClick}
import toddy/cmd

pub type Model {
  Model(count: Int)
}

pub fn init(_opts) {
  Model(count: 0)
}

pub fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "inc") -> Model(..model, count: model.count + 1)
    WidgetClick(id: "dec") -> Model(..model, count: model.count - 1)
    _ -> model
  }
}

pub fn view(model: Model) {
  ui.window("main", [ui.title("Counter")], [
    ui.column([ui.padding(16), ui.spacing(8)], [
      ui.text("count", "Count: " <> int.to_string(model.count)),
      ui.row([ui.spacing(8)], [
        ui.button("inc", "+"),
        ui.button("dec", "-"),
      ]),
    ]),
  ])
}

pub fn main() {
  toddy.start(init, update, view)
}
```

This is the Gleam SDK for toddy. It communicates with the same Rust
binary as the [Elixir SDK](https://github.com/toddy-ui/toddy-elixir)
over stdin/stdout using MessagePack.

## Status

Early development. The Elixir SDK is the reference implementation
with full feature coverage. This Gleam SDK targets feature parity
over time.

## Related

| | |
|---|---|
| Gleam SDK | [github.com/toddy-ui/toddy-gleam](https://github.com/toddy-ui/toddy-gleam) |
| Elixir SDK | [github.com/toddy-ui/toddy-elixir](https://github.com/toddy-ui/toddy-elixir) |
| Rust binary | [github.com/toddy-ui/toddy](https://github.com/toddy-ui/toddy) |

## License

MIT
