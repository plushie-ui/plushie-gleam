//// Native desktop GUIs from Gleam, powered by iced.
////
//// Plushie implements the Elm architecture (init/update/view) with commands
//// and subscriptions. It communicates with a Rust binary over stdin/stdout
//// using MessagePack, driving native windows via iced.
////
//// ## Quick start
////
//// ```gleam
//// import plushie
//// import plushie/app
//// import plushie/command
//// import plushie/event.{type Event, WidgetClick}
//// import plushie/ui
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
////   let assert Ok(_) = plushie.start(counter, plushie.default_start_opts())
//// }
//// ```

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/result
import plushie/app.{type App}
import plushie/binary
import plushie/bridge
import plushie/dev_server
import plushie/protocol
import plushie/runtime

/// Transport mode for communicating with the renderer.
///
/// - `Spawn` (default): spawns the renderer binary as a child process
///   using an Erlang Port.
/// - `Stdio`: reads/writes the BEAM's own stdin/stdout. Used when the
///   renderer spawns the Gleam process (e.g. `plushie --exec`).
/// - `Iostream`: sends and receives protocol messages via an external
///   process. Used for custom transports like SSH channels, TCP sockets,
///   or WebSockets where an adapter process handles the underlying I/O.
pub type Transport {
  Spawn
  Stdio
  Iostream(adapter: Subject(bridge.IoStreamMessage))
}

/// Options for starting a plushie application.
pub type StartOpts {
  StartOpts(
    /// Path to the plushie binary. None = auto-resolve.
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
    /// Enable dev-mode live reload. Default: False.
    /// When True, starts a file watcher that recompiles on source
    /// changes and triggers a force re-render without losing state.
    dev: Bool,
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
    dev: False,
  )
}

/// Errors that can occur when starting a plushie application.
pub type StartError {
  /// The plushie binary could not be found.
  BinaryNotFound(binary.BinaryError)
  /// The runtime failed to start (bridge or init error).
  RuntimeStartFailed(runtime.StartError)
}

/// Format a start error as a human-readable string.
pub fn start_error_to_string(err: StartError) -> String {
  case err {
    BinaryNotFound(binary_err) ->
      "binary not found: " <> binary.error_to_string(binary_err)
    RuntimeStartFailed(_) -> "runtime failed to start"
  }
}

/// Start a plushie application.
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

  let runtime_result =
    runtime.start(app, binary_path, runtime_opts)
    |> result.map_error(RuntimeStartFailed)

  // Start the dev server if dev mode is enabled
  case runtime_result, opts.dev {
    Ok(runtime_subject), True -> {
      dev_server.start(runtime_subject)
      runtime_result
    }
    _, _ -> runtime_result
  }
}

/// Stop a running plushie application by sending Shutdown to the runtime.
pub fn stop(rt: Subject(runtime.RuntimeMessage)) -> Nil {
  process.send(rt, runtime.Shutdown)
}

/// Block the caller until the plushie runtime exits.
///
/// This monitors the runtime process and returns when it stops.
/// Use this instead of `process.sleep_forever()` so that the
/// caller exits cleanly when the user closes all windows.
///
///     case plushie.start(app(), plushie.default_start_opts()) {
///       Ok(rt) -> plushie.wait(rt)
///       Error(err) -> io.println_error(plushie.start_error_to_string(err))
///     }
pub fn wait(rt: Subject(runtime.RuntimeMessage)) -> Nil {
  case process.subject_owner(rt) {
    Ok(pid) -> {
      let _monitor = process.monitor(pid)
      let selector =
        process.new_selector()
        |> process.select_monitors(fn(_down) { Nil })
      process.selector_receive_forever(selector)
    }
    Error(_) -> Nil
  }
}
