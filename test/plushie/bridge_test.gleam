//// Bridge message classification tests.
////
//// These tests verify the Send vs SendTransient behavior without
//// a real renderer binary. They use the iostream transport to
//// create a bridge with a controllable data path, then verify
//// message delivery and queueing semantics.

@target(erlang)
import gleam/dict
@target(erlang)
import gleam/erlang/process
@target(erlang)
import gleam/int
@target(erlang)
import gleam/list
@target(erlang)
import gleeunit/should
@target(erlang)
import plushie/bridge.{
  type BridgeMessage, type IoStreamMessage, InboundEvent, IoStreamBridge,
  IoStreamSend, RegisterRuntime, ResyncComplete, Send, SendTransient, Shutdown,
}
@target(erlang)
import plushie/node.{IntVal, StringVal}
@target(erlang)
import plushie/platform
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/decode
@target(erlang)
import plushie/protocol/encode as proto_encode
@target(erlang)
import plushie/support

// -- Helpers ------------------------------------------------------------------

@target(erlang)
@external(erlang, "plushie_build_ffi", "delete_file")
fn delete_file(path: String) -> Nil

@target(erlang)
/// Start a bridge with iostream transport and return the bridge subject
/// plus a way to receive what the bridge sends.
fn start_iostream_bridge(
  format: protocol.Format,
) -> #(
  process.Subject(BridgeMessage),
  process.Subject(IoStreamMessage),
  process.Subject(bridge.RuntimeNotification),
) {
  let adapter = process.new_subject()
  let runtime = process.new_subject()

  let assert Ok(bridge_subject) =
    bridge.start_with_transport(
      "",
      format,
      runtime,
      "",
      [],
      bridge.TransportIoStream(adapter),
    )

  // The bridge sends IoStreamBridge to register itself
  let assert Ok(IoStreamBridge(bridge: _)) = process.receive(adapter, 1000)

  #(bridge_subject, adapter, runtime)
}

@target(erlang)
fn start_deferred_iostream_bridge(
  format: protocol.Format,
) -> #(process.Subject(BridgeMessage), process.Subject(IoStreamMessage)) {
  let adapter = process.new_subject()
  let name = process.new_name(prefix: "plushie.bridge.test")

  let assert Ok(started) =
    bridge.start_supervised(
      name,
      "",
      format,
      "",
      [],
      bridge.TransportIoStream(adapter),
    )

  let assert Ok(IoStreamBridge(bridge: _)) = process.receive(adapter, 1000)

  #(started.data, adapter)
}

@target(erlang)
fn start_restarting_spawn_bridge() -> #(
  process.Subject(BridgeMessage),
  process.Subject(bridge.RuntimeNotification),
  String,
) {
  let runtime = process.new_subject()
  let marker = "/tmp/plushie-bridge-restart-" <> platform.unique_id()
  let script =
    "if [ -e \"$1\" ]; then trap 'rm -f \"$1\"' EXIT; cat; else : > \"$1\"; exit 1; fi"

  let assert Ok(bridge_subject) =
    bridge.start_with_transport(
      "/bin/sh",
      protocol.Msgpack,
      runtime,
      "",
      ["-c", script, "plushie-bridge-test", marker],
      bridge.TransportSpawn,
    )

  #(bridge_subject, runtime, marker)
}

@target(erlang)
/// Collect all IoStreamSend messages from the adapter subject.
fn collect_sent(
  adapter: process.Subject(IoStreamMessage),
  acc: List(BitArray),
) -> List(BitArray) {
  case process.receive(adapter, 50) {
    Ok(IoStreamSend(data:)) -> collect_sent(adapter, [data, ..acc])
    Ok(IoStreamBridge(..)) -> collect_sent(adapter, acc)
    Error(_) -> acc
  }
}

@target(erlang)
fn hello_bytes(name: String, format: protocol.Format) -> BitArray {
  let hello =
    dict.from_list([
      #("type", StringVal("hello")),
      #("protocol", IntVal(protocol.protocol_version)),
      #("version", StringVal("0.1.0")),
      #("name", StringVal(name)),
    ])
  let assert Ok(bytes) = proto_encode.serialize(hello, format)
  bytes
}

@target(erlang)
fn range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..range(from + 1, to)]
  }
}

@target(erlang)
fn collect_hello_names(
  runtime: process.Subject(bridge.RuntimeNotification),
  expected: Int,
) -> List(String) {
  collect_hello_names_until(
    runtime,
    expected,
    platform.monotonic_time_ms() + 5000,
    [],
  )
}

@target(erlang)
fn collect_hello_names_until(
  runtime: process.Subject(bridge.RuntimeNotification),
  expected: Int,
  deadline: Int,
  acc: List(String),
) -> List(String) {
  case
    list.length(acc) >= expected || platform.monotonic_time_ms() >= deadline
  {
    True -> list.reverse(acc)
    False -> {
      case process.receive(runtime, 10) {
        Ok(InboundEvent(decode.Hello(name:, ..))) ->
          collect_hello_names_until(runtime, expected, deadline, [name, ..acc])
        Ok(_) -> collect_hello_names_until(runtime, expected, deadline, acc)
        Error(_) -> collect_hello_names_until(runtime, expected, deadline, acc)
      }
    }
  }
}

@target(erlang)
fn wait_for_restart(runtime: process.Subject(bridge.RuntimeNotification)) -> Nil {
  wait_for_restart_until(runtime, platform.monotonic_time_ms() + 5000)
}

@target(erlang)
fn wait_for_restart_until(
  runtime: process.Subject(bridge.RuntimeNotification),
  deadline: Int,
) -> Nil {
  case platform.monotonic_time_ms() >= deadline {
    True -> panic as "bridge did not restart before timeout"
    False -> {
      case process.receive(runtime, 10) {
        Ok(bridge.RendererRestarted) -> Nil
        Ok(_) -> wait_for_restart_until(runtime, deadline)
        Error(_) -> wait_for_restart_until(runtime, deadline)
      }
    }
  }
}

@target(erlang)
fn remove_file(path: String) -> Nil {
  delete_file(path)
}

// -- Tests --------------------------------------------------------------------

@target(erlang)
pub fn send_delivers_when_port_ready_test() {
  let #(bridge, adapter, _runtime) = start_iostream_bridge(protocol.Json)
  let data = <<"hello":utf8>>
  process.send(bridge, Send(data:))
  // Small delay for actor to process
  process.sleep(50)

  let sent = collect_sent(adapter, [])
  should.equal(sent, [data])

  process.send(bridge, Shutdown)
}

@target(erlang)
pub fn send_transient_delivers_when_port_ready_test() {
  let #(bridge, adapter, _runtime) = start_iostream_bridge(protocol.Json)
  let data = <<"transient":utf8>>
  process.send(bridge, SendTransient(data:))
  process.sleep(50)

  let sent = collect_sent(adapter, [])
  should.equal(sent, [data])

  process.send(bridge, Shutdown)
}

@target(erlang)
pub fn send_transient_queued_during_resync_test() {
  // We can't easily simulate a PortExit with iostream transport,
  // but we can test the ResyncComplete flush path by verifying
  // the bridge processes messages correctly in sequence.
  let #(bridge, adapter, _runtime) = start_iostream_bridge(protocol.Json)

  // Send a mix of rebuildable and transient messages
  let rebuildable = <<"settings":utf8>>
  let transient = <<"widget_op":utf8>>
  process.send(bridge, Send(data: rebuildable))
  process.send(bridge, SendTransient(data: transient))
  process.sleep(50)

  // Both should arrive since port is ready and not awaiting resync
  let sent = collect_sent(adapter, [])
  should.equal(sent, [transient, rebuildable])

  process.send(bridge, Shutdown)
}

@target(erlang)
pub fn resync_complete_is_accepted_test() {
  // Verify ResyncComplete doesn't crash the bridge
  let #(bridge, _adapter, _runtime) = start_iostream_bridge(protocol.Json)
  process.send(bridge, ResyncComplete)
  process.sleep(50)
  // Bridge should still be alive
  process.send(bridge, Send(data: <<"alive":utf8>>))
  process.sleep(50)
  process.send(bridge, Shutdown)
}

@target(erlang)
pub fn queued_transient_messages_are_capped_and_flush_fifo_test() {
  support.mute_logs(fn() {
    let #(bridge, runtime, marker) = start_restarting_spawn_bridge()
    let result =
      platform.try_call(fn() {
        wait_for_restart(runtime)

        list.each(range(0, 1029), fn(i) {
          process.send(
            bridge,
            SendTransient(data: hello_bytes(int.to_string(i), protocol.Msgpack)),
          )
        })

        process.send(bridge, ResyncComplete)

        let names = collect_hello_names(runtime, 1024)
        should.equal(list.length(names), 1024)
        let assert [first, ..] = names
        should.equal(first, "6")
        should.equal(list.last(names), Ok("1029"))
      })

    process.send(bridge, Shutdown)
    remove_file(marker)

    case result {
      Ok(_) -> Nil
      Error(_) -> panic as "queued transient cap test failed"
    }
  })
}

@target(erlang)
pub fn pre_registration_events_are_capped_and_flush_fifo_test() {
  support.mute_logs(fn() {
    let #(bridge, _adapter) = start_deferred_iostream_bridge(protocol.Json)

    list.each(range(0, 299), fn(i) {
      process.send(
        bridge,
        bridge.IoStreamData(data: hello_bytes(int.to_string(i), protocol.Json)),
      )
    })
    process.sleep(100)

    let runtime = process.new_subject()
    process.send(bridge, RegisterRuntime(runtime))

    let names = collect_hello_names(runtime, 256)
    should.equal(list.length(names), 256)
    let assert [first, ..] = names
    should.equal(first, "44")
    should.equal(list.last(names), Ok("299"))

    process.send(bridge, Shutdown)
  })
}

@target(erlang)
pub fn msgpack_iostream_data_forwards_hello_test() {
  let #(bridge, _adapter, runtime) = start_iostream_bridge(protocol.Msgpack)
  let hello =
    dict.from_list([
      #("type", StringVal("hello")),
      #("protocol", IntVal(protocol.protocol_version)),
      #("version", StringVal("0.1.0")),
      #("name", StringVal("plushie")),
    ])
  let assert Ok(bytes) = proto_encode.serialize(hello, protocol.Msgpack)

  process.send(bridge, bridge.IoStreamData(data: bytes))

  let assert Ok(InboundEvent(decode.Hello(
    protocol: wire_protocol,
    version:,
    name:,
    ..,
  ))) = process.receive(runtime, 1000)
  should.equal(wire_protocol, protocol.protocol_version)
  should.equal(version, "0.1.0")
  should.equal(name, "plushie")

  process.send(bridge, Shutdown)
}
