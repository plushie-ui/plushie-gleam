//// Integration tests for effects against the real renderer binary
//// (--mock mode).
////
//// Effect stubs are registered with the renderer so it returns
//// controlled responses without executing real OS operations.
//// This tests the full request/response cycle over the wire:
//// command -> bridge -> renderer -> stub response -> bridge -> runtime -> update.

import gleam/dynamic/decode as dyn_decode
import plushie/app.{type App}
import plushie/command
import plushie/effects
import plushie/event.{type Event}
import plushie/node.{type Node, StringVal}
import plushie/support
import plushie/ui

// ---------------------------------------------------------------------------
// Effect app: clipboard read on click, model captures the result
// ---------------------------------------------------------------------------

type EffectModel {
  EffectModel(clipboard_text: String, got_unsupported: Bool)
}

fn effect_init() -> #(EffectModel, command.Command(Event)) {
  #(EffectModel(clipboard_text: "", got_unsupported: False), command.none())
}

fn effect_update(
  model: EffectModel,
  event: Event,
) -> #(EffectModel, command.Command(Event)) {
  case event {
    event.WidgetClick(id: "read", ..) -> #(model, effects.clipboard_read())
    event.EffectResponse(result: event.EffectOk(data), ..) -> {
      let text = case dyn_decode.run(data, dyn_decode.string) {
        Ok(s) -> s
        Error(_) -> ""
      }
      #(EffectModel(..model, clipboard_text: text), command.none())
    }
    event.EffectResponse(result: event.EffectUnsupported, ..) -> #(
      EffectModel(..model, got_unsupported: True),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn effect_view(_model: EffectModel) -> Node {
  ui.window("main", [ui.title("Effect Test")], [
    ui.button_("read", "Read Clipboard"),
  ])
}

fn effect_app() -> App(EffectModel, Event) {
  app.simple(effect_init, effect_update, effect_view)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// With a registered stub, the renderer returns the stubbed response
/// instead of touching the real clipboard.
pub fn stubbed_effect_returns_controlled_response_test() -> Nil {
  let rt = support.start(effect_app(), [])

  // Register a stub so clipboard_read returns "test data".
  // This blocks until the renderer confirms the stub is stored.
  let assert Ok(_) =
    support.register_effect_stub(rt, "clipboard_read", StringVal("test data"))

  // Trigger the clipboard read
  support.dispatch_event(rt, event.WidgetClick(id: "read", scope: []))

  let result =
    support.await(rt, fn(m) { m.clipboard_text == "test data" }, 2000)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}
