//// Telemetry event emission.
////
//// On BEAM, wraps the Erlang `telemetry` library. Event names,
//// measurements, and metadata are accepted only when their names are
//// known to the SDK. Unknown events are discarded, and unknown
//// measurement or metadata keys are omitted. On JavaScript, all
//// functions are no-ops (events are silently discarded).
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
import gleam/list
import plushie/platform

/// Emit a telemetry event.
///
/// - `event_name`: list of strings identifying a known SDK event,
///   e.g. `["plushie", "bridge", "send"]`.
/// - `measurements`: known numeric measurements such as byte_size or duration_ms.
/// - `metadata`: known contextual information such as reason.
///
/// Unknown event names are discarded. Unknown measurement and metadata
/// keys are omitted before the event is sent to the BEAM telemetry
/// library.
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
/// is already in use or the event name is not a known SDK event. Unknown
/// event names return Error(unknown_telemetry_event) on BEAM.
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

/// Execute a function and emit telemetry start/stop events with timing.
///
/// Emits `event_name ++ ["start"]` before and `event_name ++ ["stop"]`
/// after the function runs. The stop event includes a `duration_ms`
/// measurement (as a Dynamic integer).
///
/// Returns the function's result.
pub fn span(
  event_name: List(String),
  metadata: Dict(String, Dynamic),
  work: fn() -> a,
) -> a {
  let start_name = list.append(event_name, ["start"])
  let stop_name = list.append(event_name, ["stop"])
  let start_time = platform.monotonic_time_ms()
  execute(start_name, dict.new(), metadata)
  let result = work()
  let duration = platform.monotonic_time_ms() - start_time
  let measurements = do_duration_measurement(duration)
  execute(stop_name, measurements, metadata)
  result
}

/// Create a measurement dict with duration_ms. Uses FFI to coerce
/// the Int to Dynamic without importing erlang-specific coercion.
@external(erlang, "plushie_ffi", "telemetry_duration_measurement")
fn do_duration_measurement(_duration_ms: Int) -> Dict(String, Dynamic) {
  // JS fallback: empty measurements
  dict.new()
}
