import gleam/dict
import gleam/erlang/process
import gleeunit/should
import plushie
import plushie/app.{type App}
import plushie/bridge
import plushie/command
import plushie/event.{type Event}
import plushie/node.{IntVal, StringVal}
import plushie/platform
import plushie/protocol
import plushie/protocol/encode as proto_encode
import plushie/testing/timeout
import plushie/ui
import plushie/widget/window

const ready_env = "PLUSHIE_PACKAGE_READY_FILE"

type Model {
  Model
}

fn ready_app() -> App(Model, Event) {
  app.simple(
    fn() { #(Model, command.none()) },
    fn(model, _event) { #(model, command.none()) },
    fn(_model) {
      [ui.window("main", [window.Title("Ready")], [ui.text_("label", "ready")])]
    },
  )
}

pub fn package_ready_file_is_written_after_hello_test() {
  let saved = platform.get_env(ready_env)
  let path = "/tmp/plushie-package-ready-" <> platform.unique_id()
  delete_file(path)
  platform.set_env(ready_env, path)

  let adapter = process.new_subject()
  let stop_signal = start_owner(adapter)
  let assert Ok(bridge.IoStreamBridge(bridge: bridge_subject)) =
    process.receive(adapter, 1000)

  process.send(bridge_subject, bridge.IoStreamData(data: hello_bytes()))

  wait_for_file(path, platform.monotonic_time_ms() + 1000)
  read_file(path)
  |> should.equal(Ok("ready\n"))

  process.send(stop_signal, Nil)
  delete_file(path)
  restore_ready_env(saved)
}

pub fn package_ready_file_replaces_existing_file_test() {
  let saved = platform.get_env(ready_env)
  let path = "/tmp/plushie-package-ready-" <> platform.unique_id()
  delete_file(path)
  write_file(path, "old\n")
  platform.set_env(ready_env, path)

  let adapter = process.new_subject()
  let stop_signal = start_owner(adapter)
  let assert Ok(bridge.IoStreamBridge(bridge: bridge_subject)) =
    process.receive(adapter, 1000)

  process.send(bridge_subject, bridge.IoStreamData(data: hello_bytes()))

  wait_for_ready_content(path, platform.monotonic_time_ms() + 1000)

  process.send(stop_signal, Nil)
  delete_file(path)
  restore_ready_env(saved)
}

fn start_owner(
  adapter: process.Subject(bridge.IoStreamMessage),
) -> process.Subject(Nil) {
  let reply = process.new_subject()
  let caller_pid = process.self()

  process.spawn_unlinked(fn() {
    let stop_signal = process.new_subject()
    let caller_monitor = process.monitor(caller_pid)
    let opts =
      plushie.StartOpts(
        ..plushie.default_start_opts(),
        transport: plushie.Iostream(adapter),
        format: protocol.Msgpack,
      )
    let assert Ok(instance) = plushie.start(ready_app(), opts)
    process.send(reply, stop_signal)

    let selector =
      process.new_selector()
      |> process.select(stop_signal)
      |> process.select_specific_monitor(caller_monitor, fn(_down) { Nil })
    let _ = process.selector_receive(selector, timeout.scale(60_000))
    plushie.stop(instance)
  })

  let assert Ok(stop_signal) = process.receive(reply, 1000)
  stop_signal
}

fn hello_bytes() -> BitArray {
  let hello =
    dict.from_list([
      #("type", StringVal("hello")),
      #("protocol", IntVal(protocol.protocol_version)),
      #("version", StringVal("")),
      #("name", StringVal("plushie")),
    ])
  let assert Ok(bytes) = proto_encode.serialize(hello, protocol.Msgpack)
  bytes
}

fn wait_for_file(path: String, deadline: Int) -> Nil {
  case platform.file_exists(path) {
    True -> Nil
    False -> {
      case platform.monotonic_time_ms() >= deadline {
        True -> panic as "package readiness file was not written"
        False -> {
          process.sleep(10)
          wait_for_file(path, deadline)
        }
      }
    }
  }
}

fn wait_for_ready_content(path: String, deadline: Int) -> Nil {
  case read_file(path) {
    Ok("ready\n") -> Nil
    _ -> {
      case platform.monotonic_time_ms() >= deadline {
        True -> panic as "package readiness file was not replaced"
        False -> {
          process.sleep(10)
          wait_for_ready_content(path, deadline)
        }
      }
    }
  }
}

fn restore_ready_env(saved: Result(String, Nil)) -> Nil {
  case saved {
    Ok(value) -> platform.set_env(ready_env, value)
    Error(_) -> platform.unset_env(ready_env)
  }
}

@external(erlang, "plushie_snapshot_ffi", "read_file")
fn read_file(path: String) -> Result(String, Nil)

@external(erlang, "plushie_build_ffi", "write_file")
fn write_file(path: String, content: String) -> Nil

@external(erlang, "plushie_build_ffi", "delete_file")
fn delete_file(path: String) -> Nil
