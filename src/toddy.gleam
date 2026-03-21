//// Native desktop GUIs from Gleam, powered by iced.
////
//// Toddy implements the Elm architecture (init/update/view) with commands
//// and subscriptions. It communicates with a Rust binary over stdin/stdout
//// using MessagePack, driving native windows via iced.
////
//// ## Quick start
////
//// ```gleam
//// import toddy
//// import toddy/app
//// import toddy/command
//// import toddy/event.{type Event, WidgetClick}
//// import toddy/ui
//// import gleam/int
////
//// type Model { Model(count: Int) }
////
//// pub fn main() {
////   let counter = app.simple(
////     fn() { #(Model(0), command.none()) },
////     fn(model, event) {
////       case event {
////         WidgetClick(id: "inc", ..) ->
////           #(Model(model.count + 1), command.none())
////         _ -> #(model, command.none())
////       }
////     },
////     fn(model) {
////       ui.window("main", [ui.title("Counter")], [
////         ui.text_("count", "Count: " <> int.to_string(model.count)),
////         ui.button_("inc", "+"),
////       ])
////     },
////   )
////   let assert Ok(_) = toddy.start(counter, toddy.default_start_opts())
//// }
//// ```

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/result
import toddy/app.{type App}
import toddy/binary
import toddy/bridge
import toddy/protocol
import toddy/runtime

/// Transport mode for communicating with the renderer.
///
/// - `Spawn` (default): spawns the renderer binary as a child process
///   using an Erlang Port.
/// - `Stdio`: reads/writes the BEAM's own stdin/stdout. Used when the
///   renderer spawns the Gleam process (e.g. `toddy --exec`).
/// - `Iostream`: sends and receives protocol messages via an external
///   process. Used for custom transports like SSH channels, TCP sockets,
///   or WebSockets where an adapter process handles the underlying I/O.
pub type Transport {
  Spawn
  Stdio
  Iostream(adapter: Subject(bridge.IoStreamMessage))
}

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
    /// Application options passed to init/1. Default: dynamic.nil().
    app_opts: Dynamic,
    /// Extra CLI arguments prepended to the renderer command.
    renderer_args: List(String),
    /// Transport mode. Default: Spawn.
    transport: Transport,
  )
}

/// Default start options.
pub fn default_start_opts() -> StartOpts {
  StartOpts(
    binary_path: None,
    format: protocol.Msgpack,
    daemon: False,
    session: "",
    app_opts: dynamic.nil(),
    renderer_args: [],
    transport: Spawn,
  )
}

/// Errors that can occur when starting a toddy application.
pub type StartError {
  /// The toddy binary could not be found.
  BinaryNotFound(binary.BinaryError)
  /// The runtime failed to start (bridge or init error).
  RuntimeStartFailed(runtime.StartError)
}

/// Start a toddy application.
///
/// Resolves the binary path and launches the runtime process,
/// which internally starts the bridge actor and initializes the app.
/// All Subjects are created inside the runtime process for correct
/// message ownership.
///
/// Returns the runtime's message subject, which can be used with
/// `stop` to shut down the application.
pub fn start(
  app: App(model, msg),
  opts: StartOpts,
) -> Result(Subject(runtime.RuntimeMessage), StartError) {
  // Resolve binary path
  use binary_path <- result.try(case opts.binary_path {
    Some(path) -> Ok(path)
    None -> binary.find() |> result.map_error(BinaryNotFound)
  })

  // Start runtime (which starts bridge internally)
  let runtime_opts =
    runtime.RuntimeOpts(
      format: opts.format,
      session: opts.session,
      daemon: opts.daemon,
      app_opts: opts.app_opts,
      renderer_args: opts.renderer_args,
    )

  runtime.start(app, binary_path, runtime_opts)
  |> result.map_error(RuntimeStartFailed)
}

/// Stop a running toddy application by sending Shutdown to the runtime.
pub fn stop(rt: Subject(runtime.RuntimeMessage)) -> Nil {
  process.send(rt, runtime.Shutdown)
}
