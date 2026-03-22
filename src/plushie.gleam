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
import gleam/erlang/process.{type Pid, type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
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

/// A running plushie application instance.
///
/// Wraps the supervisor pid. Use `wait` to block until the application
/// exits, or `stop` to shut it down.
pub opaque type Instance {
  Instance(supervisor: Pid)
}

/// Get the supervisor pid from a running instance.
/// Useful for linking, monitoring, or integration with other OTP code.
pub fn supervisor_pid(instance: Instance) -> Pid {
  instance.supervisor
}

/// Errors that can occur when starting a plushie application.
pub type StartError {
  /// The plushie binary could not be found.
  BinaryNotFound(binary.BinaryError)
  /// The supervisor failed to start.
  SupervisorStartFailed(actor.StartError)
}

/// Format a start error as a human-readable string.
pub fn start_error_to_string(err: StartError) -> String {
  case err {
    BinaryNotFound(binary_err) ->
      "binary not found: " <> binary.error_to_string(binary_err)
    SupervisorStartFailed(_) -> "supervisor failed to start"
  }
}

/// Start a plushie application under an OTP supervisor.
///
/// Creates a RestForOne supervisor with Bridge and Runtime as children.
/// Bridge starts first and opens the port to the renderer binary.
/// Runtime starts second, registers with the bridge, and enters the
/// Elm update loop. If dev mode is enabled, a DevServer child is added.
///
/// Returns an `Instance` that can be used with `wait` and `stop`.
pub fn start(
  app: App(model, msg),
  opts: StartOpts,
) -> Result(Instance, StartError) {
  // Resolve binary path
  use binary_path <- result.try(case opts.binary_path {
    Some(path) -> Ok(path)
    None -> binary.find() |> result.map_error(BinaryNotFound)
  })

  let runtime_opts =
    runtime.RuntimeOpts(
      format: opts.format,
      session: opts.session,
      daemon: opts.daemon,
      app_opts: opts.app_opts,
      renderer_args: opts.renderer_args,
    )

  // Generate unique names for bridge and runtime
  let bridge_name = process.new_name(prefix: "plushie.bridge")
  let runtime_name = process.new_name(prefix: "plushie.runtime")

  // Map transport to bridge transport type
  let bridge_transport = case opts.transport {
    Spawn -> bridge.TransportSpawn
    Stdio -> bridge.TransportStdio
    Iostream(adapter:) -> bridge.TransportIoStream(adapter:)
  }

  // Build supervisor children
  let bridge_child =
    supervision.worker(fn() {
      bridge.start_supervised(
        bridge_name,
        binary_path,
        opts.format,
        opts.session,
        opts.renderer_args,
        bridge_transport,
      )
    })
    |> supervision.restart(supervision.Transient)
    |> supervision.significant(True)
    |> supervision.timeout(ms: 2000)

  let bridge_subject = process.named_subject(bridge_name)

  let runtime_child =
    supervision.worker(fn() {
      runtime.start_supervised(
        app,
        bridge_subject,
        runtime_opts,
        binary_path,
        runtime_name,
      )
    })
    |> supervision.restart(supervision.Transient)
    |> supervision.significant(True)
    |> supervision.timeout(ms: 2000)

  let sup_builder =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.auto_shutdown(supervisor.AnySignificant)
    |> supervisor.add(bridge_child)
    |> supervisor.add(runtime_child)

  // Add dev server if enabled
  let sup_builder = case opts.dev {
    True -> {
      let runtime_subject = process.named_subject(runtime_name)
      let dev_child =
        supervision.worker(fn() { dev_server.start_supervised(runtime_subject) })
        |> supervision.restart(supervision.Transient)
      supervisor.add(sup_builder, dev_child)
    }
    False -> sup_builder
  }

  case supervisor.start(sup_builder) {
    Ok(started) -> Ok(Instance(supervisor: started.pid))
    Error(err) -> Error(SupervisorStartFailed(err))
  }
}

/// Stop a running plushie application.
///
/// Sends a shutdown exit to the supervisor, which terminates all
/// children (bridge, runtime, dev server) in reverse start order.
pub fn stop(instance: Instance) -> Nil {
  // Send :shutdown exit to the supervisor -- the OTP-standard way
  // to stop a supervisor. It will terminate children gracefully.
  shutdown_pid(instance.supervisor)
  Nil
}

@external(erlang, "plushie_ffi", "shutdown_pid")
fn shutdown_pid(pid: Pid) -> Nil

/// Block the caller until the plushie application exits.
///
/// Monitors the supervisor process and returns when it stops.
/// Use this instead of `process.sleep_forever()` so that the
/// caller exits cleanly when the user closes all windows.
///
///     case plushie.start(app(), plushie.default_start_opts()) {
///       Ok(instance) -> plushie.wait(instance)
///       Error(err) -> io.println_error(plushie.start_error_to_string(err))
///     }
pub fn wait(instance: Instance) -> Nil {
  let _monitor = process.monitor(instance.supervisor)
  let selector =
    process.new_selector()
    |> process.select_monitors(fn(_down) { Nil })
  process.selector_receive_forever(selector)
}
