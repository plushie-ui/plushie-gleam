//// Telemetry event emission.
////
//// On BEAM, wraps the Erlang `telemetry` library -- event names
//// are lists of strings converted to atom lists for the underlying
//// `:telemetry.execute/3` call. On JavaScript, all functions are
//// no-ops (events are silently discarded).
////
//// ## Usage
////
//// ```gleam
//// import gleam/dict
//// import gleam/dynamic
//// import plushie/telemetry
////
//// telemetry.execute(
////   ["plushie", "bridge", "send"],
////   dict.from_list([#("byte_size", dynamic.from(42))]),
////   dict.new(),
//// )
//// ```

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

/// Emit a telemetry event.
///
/// - `event_name`: list of strings identifying the event (converted
///   to atoms internally, e.g. `["plushie", "bridge", "send"]`).
/// - `measurements`: numeric measurements (byte_size, duration, etc.).
/// - `metadata`: contextual information (reason, format, etc.).
pub fn execute(
  event_name: List(String),
  measurements: Dict(String, Dynamic),
  metadata: Dict(String, Dynamic),
) -> Nil {
  do_execute(event_name, measurements, metadata)
}

@external(erlang, "plushie_ffi", "telemetry_execute")
fn do_execute(
  _event_name: List(String),
  _measurements: Dict(String, Dynamic),
  _metadata: Dict(String, Dynamic),
) -> Nil {
  Nil
}

/// Attach a handler for a telemetry event.
///
/// The handler function receives the event name, measurements,
/// metadata, and the config value passed here.
///
/// Returns Ok(Nil) on success, Error(reason) if the handler ID
/// is already in use.
pub fn attach(
  handler_id: String,
  event_name: List(String),
  handler: fn(List(String), Dict(String, Dynamic), Dict(String, Dynamic)) -> Nil,
  config: Dynamic,
) -> Result(Nil, Dynamic) {
  do_attach(handler_id, event_name, handler, config)
}

@external(erlang, "plushie_ffi", "telemetry_attach")
fn do_attach(
  _handler_id: String,
  _event_name: List(String),
  _handler: fn(List(String), Dict(String, Dynamic), Dict(String, Dynamic)) ->
    Nil,
  _config: Dynamic,
) -> Result(Nil, Dynamic) {
  Ok(Nil)
}

/// Detach a previously attached handler by ID.
pub fn detach(handler_id: String) -> Nil {
  do_detach(handler_id)
}

@external(erlang, "plushie_ffi", "telemetry_detach")
fn do_detach(_handler_id: String) -> Nil {
  Nil
}
