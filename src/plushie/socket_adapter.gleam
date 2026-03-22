//// Bridges a Unix domain socket or TCP connection to the iostream
//// transport protocol.
////
//// When the renderer uses `--listen`, it creates a socket. This adapter
//// connects to that socket and translates between gen_tcp messages and
//// the iostream protocol that the Bridge already speaks.
////
//// Protocol:
////   Bridge sends IoStreamBridge(bridge) on init -> adapter stores it
////   Bridge sends IoStreamSend(data) -> adapter writes to socket
////   Socket sends tcp data -> adapter forwards as IoStreamData to bridge
////   Socket closes -> adapter sends IoStreamClosed to bridge
////
//// Implementation uses a raw Erlang gen_server rather than the Gleam
//// actor framework, because the adapter must receive both typed
//// IoStreamMessage from the bridge subject AND raw gen_tcp messages
//// from the socket -- a pattern that doesn't map cleanly to Gleam's
//// single-typed actor model.

import gleam/erlang/process.{type Subject}
import plushie/bridge.{type IoStreamMessage}
import plushie/protocol

/// Opaque socket handle from gen_tcp.
pub type Socket

/// Start the socket adapter.
///
/// Connects to the given address and returns the adapter's subject,
/// which speaks the IoStreamMessage protocol expected by the Bridge.
///
/// The address is a Unix socket path (e.g. `/tmp/plushie.sock`),
/// a TCP port (e.g. `:4567`), or a TCP host:port (e.g. `127.0.0.1:4567`).
pub fn start(
  addr: String,
  format: protocol.Format,
) -> Result(Subject(IoStreamMessage), String) {
  start_ffi(addr, format)
}

@external(erlang, "plushie_socket_adapter_ffi", "start")
fn start_ffi(
  addr: String,
  format: protocol.Format,
) -> Result(Subject(IoStreamMessage), String)
