@target(javascript)
import gleam/dynamic/decode as dyn_decode
@target(javascript)
import gleam/json
@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{None, Some}
@target(javascript)
import gleam/string
@target(javascript)
import gleeunit
@target(javascript)
import gleeunit/should
@target(javascript)
import plushie/app
@target(javascript)
import plushie/command
@target(javascript)
import plushie/effect
@target(javascript)
import plushie/event
@target(javascript)
import plushie/node
@target(javascript)
import plushie/node.{StringVal}
@target(javascript)
import plushie_web

@target(erlang)
pub fn main() -> Nil {
  Nil
}

@target(javascript)
type Model {
  Model(events: List(String))
}

@target(javascript)
fn effect_test_app(
  init_command: command.Command(event.Event),
) -> app.App(Model, event.Event) {
  app.simple(
    fn() { #(Model([]), init_command) },
    fn(model, incoming) {
      case incoming {
        event.System(event.AnimationFrame(..)) -> #(
          model,
          effect.clipboard_read("clip"),
        )
        event.Effect(event.EffectEvent(tag:, result: event.ClipboardText(text:))) -> #(
          Model([tag <> ":" <> text, ..model.events]),
          command.none(),
        )
        event.Effect(event.EffectEvent(tag:, result: event.EffectTimeout)) -> #(
          Model([tag <> ":timeout", ..model.events]),
          command.none(),
        )
        _ -> #(model, command.none())
      }
    },
    fn(_model) {
      Some(
        node.new("main", "window")
        |> node.with_prop("title", StringVal("Runtime Web Test")),
      )
    },
  )
}

@target(javascript)
fn sent_effect_ids() -> List(String) {
  fake_transport_sent_messages()
  |> list.filter_map(fn(message) {
    case json.parse(string.trim(message), dyn_decode.dynamic) {
      Ok(payload) -> {
        let decoder = {
          use message_type <- dyn_decode.field("type", dyn_decode.string)
          use request_id <- dyn_decode.field("id", dyn_decode.string)
          dyn_decode.success(#(message_type, request_id))
        }
        case dyn_decode.run(payload, decoder) {
          Ok(#("effect", request_id)) -> Some(request_id)
          _ -> None
        }
      }
      Error(_) -> None
    }
  })
}

@target(javascript)
fn effect_ok_response(request_id: String, text: String) -> String {
  "{\"type\":\"effect_response\",\"id\":\""
  <> request_id
  <> "\",\"status\":\"ok\",\"result\":{\"text\":\""
  <> text
  <> "\"}}"
}

@target(javascript)
pub fn effect_response_updates_model_test() {
  install_fake_plushie_app()

  let assert Ok(instance) =
    plushie_web.start(
      effect_test_app(effect.clipboard_read("clip")),
      plushie_web.default_start_opts(),
    )

  let assert [request_id] = sent_effect_ids()
  fake_transport_emit(effect_ok_response(request_id, "hello"))

  plushie_web.get_model(instance)
  |> should.equal(Model(["clip:hello"]))

  plushie_web.stop(instance)
  reset_fake_plushie_app()
}

@target(javascript)
pub fn immediate_effect_response_during_send_is_delivered_test() {
  install_fake_plushie_app()
  set_immediate_clipboard_text_response("same-turn")

  let assert Ok(instance) =
    plushie_web.start(
      effect_test_app(command.none()),
      plushie_web.default_start_opts(),
    )

  plushie_web.dispatch_event(
    instance,
    event.System(event.AnimationFrame(timestamp: 1)),
  )

  plushie_web.get_model(instance)
  |> should.equal(Model(["clip:same-turn"]))

  plushie_web.stop(instance)
  reset_fake_plushie_app()
}

@target(javascript)
pub fn effect_timeout_updates_model_test() {
  install_fake_plushie_app()
  set_immediate_effect_timeouts(True)

  let assert Ok(instance) =
    plushie_web.start(
      effect_test_app(effect.clipboard_read("clip")),
      plushie_web.default_start_opts(),
    )

  plushie_web.get_model(instance)
  |> should.equal(Model(["clip:timeout"]))

  plushie_web.stop(instance)
  reset_fake_plushie_app()
}

@target(javascript)
pub fn stale_effect_response_is_ignored_after_tag_reuse_test() {
  install_fake_plushie_app()

  let assert Ok(instance) =
    plushie_web.start(
      effect_test_app(
        command.batch([
          effect.clipboard_read("clip"),
          effect.clipboard_read("clip"),
        ]),
      ),
      plushie_web.default_start_opts(),
    )

  let assert [first_id, second_id] = sent_effect_ids()

  fake_transport_emit(effect_ok_response(first_id, "stale"))
  plushie_web.get_model(instance)
  |> should.equal(Model([]))

  fake_transport_emit(effect_ok_response(second_id, "fresh"))
  plushie_web.get_model(instance)
  |> should.equal(Model(["clip:fresh"]))

  plushie_web.stop(instance)
  reset_fake_plushie_app()
}

@target(javascript)
pub fn async_task_entry_is_deleted_when_stopped_before_sync_error_test() {
  async_task_cleans_up_when_stopped_during_sync_throw()
  |> should.be_true
}

@target(javascript)
pub fn async_task_entry_is_deleted_when_stopped_before_promise_resolve_test() {
  async_task_cleans_up_when_stopped_before_promise_resolve()
  |> should.be_true
}

@target(javascript)
pub fn async_task_entry_is_deleted_when_stopped_before_promise_reject_test() {
  async_task_cleans_up_when_stopped_before_promise_reject()
  |> should.be_true
}

@target(javascript)
pub fn async_task_entry_is_deleted_when_cancelled_before_promise_resolve_test() {
  async_task_cleans_up_when_cancelled_before_promise_resolve()
  |> should.be_true
}

@target(javascript)
pub fn stream_task_entry_is_deleted_when_stopped_before_sync_error_test() {
  stream_task_cleans_up_when_stopped_during_sync_throw()
  |> should.be_true
}

@target(javascript)
pub fn main() -> Nil {
  gleeunit.main()
}

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "install_fake_plushie_app")
fn install_fake_plushie_app() -> Nil

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "reset_fake_plushie_app")
fn reset_fake_plushie_app() -> Nil

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "fake_transport_sent_messages")
fn fake_transport_sent_messages() -> List(String)

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "fake_transport_emit")
fn fake_transport_emit(json: String) -> Nil

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "set_immediate_effect_timeouts")
fn set_immediate_effect_timeouts(enabled: Bool) -> Nil

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "set_immediate_clipboard_text_response")
fn set_immediate_clipboard_text_response(text: String) -> Nil

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "async_task_cleans_up_when_stopped_during_sync_throw")
fn async_task_cleans_up_when_stopped_during_sync_throw() -> Bool

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "async_task_cleans_up_when_stopped_before_promise_resolve")
fn async_task_cleans_up_when_stopped_before_promise_resolve() -> Bool

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "async_task_cleans_up_when_stopped_before_promise_reject")
fn async_task_cleans_up_when_stopped_before_promise_reject() -> Bool

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "async_task_cleans_up_when_cancelled_before_promise_resolve")
fn async_task_cleans_up_when_cancelled_before_promise_resolve() -> Bool

@target(javascript)
@external(javascript, "../../plushie_test_ffi.mjs", "stream_task_cleans_up_when_stopped_during_sync_throw")
fn stream_task_cleans_up_when_stopped_during_sync_throw() -> Bool
