//// Build a Plushie package payload for Erlang-target Gleam apps.
////
//// The command exports the app with `gleam export erlang-shipment`,
//// prepares a host-first shared-launcher payload with app icon assets, writes
//// `plushie-package.toml`, and archives the payload for
//// `bin/plushie package portable` or `bin/plushie package bundle`.

@target(erlang)
import gleam/io
@target(erlang)
import plushie/protocol

@target(erlang)
/// Entry point for `gleam run -m plushie/package`.
pub fn main() -> Nil {
  case package(protocol.protocol_version) {
    Ok(_) -> Nil
    Error(reason) -> {
      io.println_error(reason)
      halt(1)
    }
  }
}

@target(erlang)
@external(erlang, "plushie_package_ffi", "package")
fn package(protocol_version: Int) -> Result(Nil, String)

@target(erlang)
@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
