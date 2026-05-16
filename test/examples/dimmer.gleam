//// Dimmer example: demonstrates `app.application` with a custom Msg
//// type alongside a custom canvas widget.
////
//// The default `app.simple` API delivers raw `Event` values to update,
//// so the app pattern-matches on string widget IDs everywhere it
//// reacts to user input. `app.application` adds a single `on_event`
//// boundary that maps wire Events to a typed Msg, and `update` then
//// works in the app's own vocabulary.
////
//// Three sources of input show how the Msg variants stay narrow:
//// - Custom canvas widget (`dimmer`) emits `change` -> `BrightnessChanged`
//// - Built-in button (`cut`) -> `CutPower`
//// - Built-in button (`boost`) -> `Boost`
//// Anything else funnels into `Ignore` so unrelated events don't reach
//// `update` at all.

import examples/widgets/dimmer
import gleam/dynamic/decode
import gleam/float
import gleam/int
@target(erlang)
import gleam/io
@target(erlang)
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, CustomWidget, EventTarget, Widget, click_route}
import plushie/node.{type Node}
import plushie/prop/length
import plushie/prop/padding
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/row
import plushie/widget/window

// -- Model --------------------------------------------------------------------

pub type Model {
  Model(brightness: Float)
}

const initial_brightness: Float = 0.5

const boost_step: Float = 0.1

// -- Messages -----------------------------------------------------------------

/// Domain messages this app understands. `update` only ever sees one
/// of these; the wire-event-to-Msg mapping happens in `on_event`.
pub type Msg {
  /// Emitted by the custom dimmer widget when the user presses on it.
  BrightnessChanged(Float)
  /// Built-in "Cut Power" button clicked.
  CutPower
  /// Built-in "Boost" button clicked.
  Boost
  /// Catch-all for events this app doesn't care about.
  Ignore
}

// -- Elm functions ------------------------------------------------------------

fn init() -> #(Model, command.Command(Msg)) {
  #(Model(brightness: initial_brightness), command.none())
}

fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  case msg {
    BrightnessChanged(v) -> #(Model(brightness: clamp(v)), command.none())
    CutPower -> #(Model(brightness: 0.0), command.none())
    Boost -> #(
      Model(brightness: clamp(model.brightness +. boost_step)),
      command.none(),
    )
    Ignore -> #(model, command.none())
  }
}

/// Wire-event boundary: this is the only place that knows about widget
/// IDs as strings. Everywhere else in the app, messages are typed.
fn on_event(event: Event) -> Msg {
  case event {
    Widget(CustomWidget(
      kind: "change",
      target: EventTarget(id: "dimmer", ..),
      data: data,
      ..,
    )) ->
      case decode.run(data, decode.float) {
        Ok(v) -> BrightnessChanged(v)
        Error(_) -> Ignore
      }
    _ -> click_route(event, [#("cut", CutPower), #("boost", Boost)], Ignore)
  }
}

fn view(model: Model) -> List(Node) {
  let percent = float.round(model.brightness *. 100.0)
  [
    ui.window("main", [window.Title("Dimmer")], [
      ui.column(
        "content",
        [column.Padding(padding.all(16.0)), column.Spacing(12.0)],
        [
          ui.text_("readout", "Brightness: " <> int.to_string(percent) <> "%"),
          dimmer.widget("dimmer", model.brightness),
          ui.row("buttons", [row.Spacing(8.0)], [
            ui.button("cut", "Cut power", [button.Width(length.Shrink)]),
            ui.button("boost", "Boost", [button.Width(length.Shrink)]),
          ]),
        ],
      ),
    ]),
  ]
}

pub fn app() -> app.App(Model, Msg) {
  app.application(init, update, view, on_event)
}

fn clamp(v: Float) -> Float {
  float.max(0.0, float.min(1.0, v))
}

@target(erlang)
pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
