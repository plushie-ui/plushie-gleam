//// Integration tests for effects against the real renderer binary
//// (--mock mode).
////
//// In mock mode, platform effects (file dialogs, clipboard) return
//// EffectCancelled because there's no display server. These tests
//// verify the effect request/response cycle works end-to-end:
//// the command is sent over the wire, the renderer responds, and
//// the result dispatches through update.

import plushie/app.{type App}
import plushie/command
import plushie/effects
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/support
import plushie/ui

// ---------------------------------------------------------------------------
// Effect app: clipboard read on click, model captures the result
// ---------------------------------------------------------------------------

type EffectModel {
  EffectModel(got_response: Bool, was_cancelled: Bool)
}

fn effect_init() -> #(EffectModel, command.Command(Event)) {
  #(EffectModel(got_response: False, was_cancelled: False), command.none())
}

fn effect_update(
  model: EffectModel,
  event: Event,
) -> #(EffectModel, command.Command(Event)) {
  case event {
    event.WidgetClick(id: "read", ..) -> #(model, effects.clipboard_read())
    event.EffectResponse(result: event.EffectCancelled, ..) -> #(
      EffectModel(got_response: True, was_cancelled: True),
      command.none(),
    )
    event.EffectResponse(result: event.EffectOk(_), ..) -> #(
      EffectModel(got_response: True, was_cancelled: False),
      command.none(),
    )
    event.EffectResponse(result: event.EffectError(_), ..) -> #(
      EffectModel(got_response: True, was_cancelled: False),
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

/// Effect request goes over the wire, response dispatches through update.
pub fn effect_response_dispatches_through_update_test() -> Nil {
  let rt = support.start(effect_app(), [])
  support.dispatch_event(rt, event.WidgetClick(id: "read", scope: []))
  let result = support.await(rt, fn(m) { m.got_response }, 2000)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}
