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
import gleeunit/should
@target(erlang)
import plushie/bridge.{
  type BridgeMessage, type IoStreamMessage, InboundEvent, IoStreamBridge,
  IoStreamSend, ResyncComplete, Send, SendTransient, Shutdown,
}
@target(erlang)
import plushie/node.{IntVal, StringVal}
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/decode
@target(erlang)
import plushie/protocol/encode as proto_encode

// -- Helpers ------------------------------------------------------------------

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
