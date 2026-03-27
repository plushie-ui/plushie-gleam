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
import plushie/widget/window

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
    event.WidgetClick(window_id: "main", id: "read", ..) -> #(
      model,
      effects.clipboard_read(),
    )
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
  ui.window("main", [window.Title("Effect Test")], [
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
  support.dispatch_event(
    rt,
    event.WidgetClick(window_id: "main", id: "read", scope: []),
  )

  let result =
    support.await(rt, fn(m) { m.clipboard_text == "test data" }, 2000)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// After unregistering a stub, the renderer no longer returns the
/// stubbed response. In mock mode, the real clipboard isn't available,
/// so we should not get the original stub value back.
pub fn unregister_removes_stub_test() -> Nil {
  let rt = support.start(effect_app(), [])

  // Register and then immediately unregister
  let assert Ok(_) =
    support.register_effect_stub(rt, "clipboard_read", StringVal("first"))
  let assert Ok(_) = support.unregister_effect_stub(rt, "clipboard_read")

  // Trigger the clipboard read -- should not get "first" back
  support.dispatch_event(
    rt,
    event.WidgetClick(window_id: "main", id: "read", scope: []),
  )

  // Wait a bit for the response to arrive
  let result =
    support.await(
      rt,
      fn(m) { m.clipboard_text != "" || m.got_unsupported },
      2000,
    )
  support.stop(rt)

  // Either we got a different value or unsupported -- but not "first"
  case result {
    Ok(model) -> {
      let assert True = model.clipboard_text != "first"
      Nil
    }
    // Timeout is also acceptable -- no stub means the mock may not respond
    Error(_) -> Nil
  }
}
