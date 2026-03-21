//// Keyboard shortcuts example: scrollable log of key press events.
////
//// Demonstrates on_key_press subscription, modifier inspection,
//// and key module constants for pattern matching.

import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, type Modifiers, KeyPress}
import plushie/key
import plushie/node.{type Node}
import plushie/prop/length
import plushie/prop/padding
import plushie/subscription
import plushie/ui

const max_log_entries = 50

type Model {
  Model(log: List(String), count: Int)
}

fn init() {
  #(Model(log: [], count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    KeyPress(key: k, modifiers: mods, physical_key: phys, ..) -> {
      let n = model.count + 1
      let entry = format_key_event(n, k, mods, phys)
      let log =
        [entry, ..model.log]
        |> list.take(max_log_entries)
      #(Model(log:, count: n), command.none())
    }
    _ -> #(model, command.none())
  }
}

fn format_key_event(
  n: Int,
  key_name: String,
  mods: Modifiers,
  physical: option.Option(String),
) -> String {
  let prefix = format_modifiers(mods)
  let prefix = case prefix {
    "" -> ""
    p -> p <> "+"
  }
  let phys_str = case physical {
    option.Some(p) -> " [" <> p <> "]"
    option.None -> ""
  }

  // Show special key name annotations for demo purposes
  let annotation = case key_name {
    k if k == key.escape -> " (Escape)"
    k if k == key.enter -> " (Enter)"
    k if k == key.tab -> " (Tab)"
    k if k == key.backspace -> " (Backspace)"
    k if k == key.space -> " (Space)"
    k if k == key.arrow_up -> " (ArrowUp)"
    k if k == key.arrow_down -> " (ArrowDown)"
    k if k == key.arrow_left -> " (ArrowLeft)"
    k if k == key.arrow_right -> " (ArrowRight)"
    _ -> ""
  }

  "#"
  <> int.to_string(n)
  <> ": "
  <> prefix
  <> key_name
  <> annotation
  <> phys_str
}

fn format_modifiers(m: Modifiers) -> String {
  []
  |> push_if(m.ctrl, "Ctrl")
  |> push_if(m.alt, "Alt")
  |> push_if(m.shift, "Shift")
  |> push_if(m.logo, "Super")
  |> string.join("+")
}

fn push_if(acc: List(String), cond: Bool, label: String) -> List(String) {
  case cond {
    True -> list.append(acc, [label])
    False -> acc
  }
}

fn subscribe(_model: Model) -> List(subscription.Subscription) {
  [subscription.on_key_press("keys")]
}

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Keyboard Shortcuts")], [
    ui.column(
      "content",
      [ui.padding(padding.all(16.0)), ui.spacing(12), ui.width(length.Fill)],
      [
        ui.text("header", "Press any key", [ui.font_size(20.0)]),
        ui.text_("count", int.to_string(model.count) <> " key events captured"),
        ui.rule("divider", []),
        ui.scrollable("log", [ui.height(length.Fill)], [
          ui.column(
            "log-entries",
            [ui.spacing(2), ui.width(length.Fill)],
            list.index_map(model.log, fn(entry, idx) {
              ui.text("log_" <> int.to_string(idx), entry, [
                ui.font_size(13.0),
              ])
            }),
          ),
        ]),
      ],
    ),
  ])
}

pub fn main() {
  let my_app =
    app.simple(init, update, view)
    |> app.with_subscriptions(subscribe)
  let _ = plushie.start(my_app, plushie.default_start_opts())
  process.sleep_forever()
}
