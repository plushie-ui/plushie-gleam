//// Native desktop GUIs from Gleam, powered by iced.
////
//// Toddy implements the Elm architecture (init/update/view) with commands
//// and subscriptions. It communicates with a Rust binary over stdin/stdout
//// using MessagePack, driving native windows via iced.

import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import toddy/app.{type App}
import toddy/binary
import toddy/bridge
import toddy/event.{type Event}
import toddy/protocol
import toddy/runtime

/// Options for starting a toddy application.
pub type StartOpts {
  StartOpts(
    /// Path to the toddy binary. None = auto-resolve.
    binary_path: Option(String),
    /// Wire format. Default: MessagePack.
    format: protocol.Format,
    /// Keep running after all windows close. Default: False.
    daemon: Bool,
    /// Session identifier. Default: "" (single-session).
    session: String,
  )
}

/// Default start options.
pub fn default_start_opts() -> StartOpts {
  StartOpts(
    binary_path: None,
    format: protocol.Msgpack,
    daemon: False,
    session: "",
  )
}

/// Errors that can occur when starting a toddy application.
pub type StartError {
  /// The toddy binary could not be found.
  BinaryNotFound(binary.BinaryError)
  /// The bridge actor failed to start.
  BridgeStartFailed(actor.StartError)
}

/// Start a toddy application.
///
/// Resolves the binary path, starts the bridge actor, and launches
/// the runtime process. The bridge and runtime are linked to the
/// calling process.
///
/// Returns the runtime's message subject, which can be used with
/// `stop` to shut down the application.
pub fn start(
  app: App(model, Event),
  opts: StartOpts,
) -> Result(Subject(runtime.RuntimeMessage), StartError) {
  // Resolve binary path
  use binary_path <- result.try(case opts.binary_path {
    Some(path) -> Ok(path)
    None -> binary.find() |> result.map_error(BinaryNotFound)
  })

  // Create notification subject for bridge -> runtime communication
  let notification_subject = runtime.new_notification_subject()

  // Start bridge actor
  use bridge_subject <- result.try(
    bridge.start(binary_path, opts.format, notification_subject, opts.session)
    |> result.map_error(BridgeStartFailed),
  )

  // Start runtime
  let runtime_opts =
    runtime.RuntimeOpts(
      format: opts.format,
      session: opts.session,
      daemon: opts.daemon,
    )
  let rt =
    runtime.start(app, bridge_subject, notification_subject, runtime_opts)

  Ok(rt)
}

/// Stop a running toddy application by sending Shutdown to the runtime.
pub fn stop(rt: Subject(runtime.RuntimeMessage)) -> Nil {
  process.send(rt, runtime.Shutdown)
}
