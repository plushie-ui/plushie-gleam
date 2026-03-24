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
//// import plushie/widget/window
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
////       ui.window("main", [window.Title("Counter")], [
////         ui.text_("count", "Count: " <> int.to_string(model.count)),
////         ui.button_("inc", "+"),
////       ])
////     },
////   )
////   let assert Ok(_) = plushie.start(counter, plushie.default_start_opts())
//// }
//// ```

@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/erlang/process.{type Pid, type Subject}
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import gleam/otp/actor
@target(erlang)
import gleam/otp/static_supervisor as supervisor
@target(erlang)
import gleam/otp/supervision
@target(erlang)
import gleam/result
@target(erlang)
import plushie/app.{type App}
@target(erlang)
import plushie/binary
@target(erlang)
import plushie/bridge
@target(erlang)
import plushie/dev_server
@target(erlang)
import plushie/event.{type Event}
@target(erlang)
import plushie/node
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/runtime

@target(erlang)
/// Transport mode for communicating with the renderer.
///
/// - `Spawn` (default): spawns the renderer binary as a child process
///   using an Erlang Port.
/// - `Stdio`: reads/writes the BEAM's own stdin/stdout. Used when the
///   renderer spawns the Gleam process (e.g. `plushie-renderer --exec`).
/// - `Iostream`: sends and receives protocol messages via an external
///   process. Used for custom transports like SSH channels, TCP sockets,
///   or WebSockets where an adapter process handles the underlying I/O.
pub type Transport {
  Spawn
  Stdio
  Iostream(adapter: Subject(bridge.IoStreamMessage))
}

@target(erlang)
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
    /// Authentication token for socket transport. Sent in the
    /// settings message for renderer verification. Default: None.
    token: Option(String),
  )
}

@target(erlang)
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
    token: None,
  )
}

@target(erlang)
/// A running plushie application instance, parameterized over the
/// application's model type.
///
/// The model type flows from the `App(model, msg)` passed to `start`.
/// Use `get_model` to query state with full type safety, `stop` to
/// shut down, or `wait` to block until exit.
pub opaque type Instance(model) {
  Instance(supervisor: Pid, runtime: Subject(runtime.RuntimeMessage))
}

@target(erlang)
/// Get the supervisor pid from a running instance.
/// Useful for linking, monitoring, or integration with other OTP code.
pub fn supervisor_pid(instance: Instance(_)) -> Pid {
  instance.supervisor
}

@target(erlang)
/// Errors that can occur when starting a plushie application.
pub type StartError {
  /// The plushie binary could not be found.
  BinaryNotFound(binary.BinaryError)
  /// The supervisor failed to start.
  SupervisorStartFailed(actor.StartError)
}

@target(erlang)
/// Format a start error as a human-readable string.
pub fn start_error_to_string(err: StartError) -> String {
  case err {
    BinaryNotFound(binary_err) ->
      "binary not found: " <> binary.error_to_string(binary_err)
    SupervisorStartFailed(actor.InitTimeout) ->
      "supervisor failed to start: child init timed out"
    SupervisorStartFailed(actor.InitFailed(reason)) ->
      "supervisor failed to start: child init failed (" <> reason <> ")"
    SupervisorStartFailed(actor.InitExited(_)) ->
      "supervisor failed to start: child process exited during init"
  }
}

@target(erlang)
/// Start a plushie application under an OTP supervisor.
///
/// Creates a RestForOne supervisor with Bridge and Runtime as children.
/// Bridge starts first and opens the port to the renderer binary.
/// Runtime starts second, registers with the bridge, and enters the
/// Elm update loop. If dev mode is enabled, a DevServer child is added.
///
/// Returns an `Instance(model)` that can be used with `get_model`,
/// `dispatch_event`, `wait`, and `stop`.
pub fn start(
  app: App(model, msg),
  opts: StartOpts,
) -> Result(Instance(model), StartError) {
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
      token: opts.token,
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

  let runtime_subject = process.named_subject(runtime_name)

  case supervisor.start(sup_builder) {
    Ok(started) ->
      Ok(Instance(supervisor: started.pid, runtime: runtime_subject))
    Error(err) -> Error(SupervisorStartFailed(err))
  }
}

@target(erlang)
/// Stop a running plushie application.
///
/// Sends a shutdown exit to the supervisor, which terminates all
/// children (bridge, runtime, dev server) in reverse start order.
pub fn stop(instance: Instance(_)) -> Nil {
  // Send :shutdown exit to the supervisor -- the OTP-standard way
  // to stop a supervisor. It will terminate children gracefully.
  shutdown_pid(instance.supervisor)
  Nil
}

@target(erlang)
@external(erlang, "plushie_ffi", "shutdown_pid")
fn shutdown_pid(pid: Pid) -> Nil

@target(erlang)
/// Narrow identity for the Dynamic -> model boundary in get_model.
@external(erlang, "plushie_ffi", "identity")
fn from_dynamic(value: Dynamic) -> a

@target(erlang)
/// Query the current model from a running application.
///
/// Returns the model with full type safety -- the type parameter
/// flows from the `App(model, msg)` passed to `start`.
///
/// The first call may block briefly if the runtime is still
/// completing its init sequence (settings, snapshot, subscriptions).
/// The reply always reflects the post-init model state.
pub fn get_model(instance: Instance(model)) -> Result(model, Nil) {
  let reply: Subject(Dynamic) = process.new_subject()
  process.send(instance.runtime, runtime.GetModel(reply:))
  case process.receive(reply, 5000) {
    Ok(dyn) -> Ok(from_dynamic(dyn))
    Error(Nil) -> Error(Nil)
  }
}

@target(erlang)
/// Query the current normalized tree from a running application.
///
/// Returns `None` if the runtime hasn't rendered yet (shouldn't
/// happen in practice -- the initial render runs before `start`
/// returns).
pub fn get_tree(instance: Instance(_)) -> Result(Option(node.Node), Nil) {
  let reply = process.new_subject()
  process.send(instance.runtime, runtime.GetTree(reply:))
  process.receive(reply, 5000)
}

@target(erlang)
/// Dispatch an event directly to the runtime's message loop.
///
/// Bypasses the bridge/renderer -- the event is processed through
/// the normal handle_event -> update -> view -> diff -> patch cycle
/// as if it came from the renderer.
///
/// Useful for integration tests that need to trigger state changes
/// (clicks, toggles, etc.) in a running application.
pub fn dispatch_event(instance: Instance(_), event: Event) -> Nil {
  process.send(instance.runtime, runtime.InternalEvent(event))
}

@target(erlang)
/// Register an effect stub with the renderer.
///
/// When the renderer receives an effect request of this kind, it
/// returns the given response immediately without executing the
/// real effect. Used for testing (controlled effect responses)
/// and scripting (no user interaction required).
///
/// The response value is returned as-is in an EffectOk result.
/// To simulate cancellation, use `dispatch_event` with an
/// `EffectResponse(result: EffectCancelled)` instead.
pub fn register_effect_stub(
  instance: Instance(_),
  kind: String,
  response: node.PropValue,
) -> Result(Nil, Nil) {
  let reply = process.new_subject()
  process.send(
    instance.runtime,
    runtime.RegisterEffectStub(kind:, response:, reply:),
  )
  process.receive(reply, 5000)
}

@target(erlang)
/// Remove a previously registered effect stub.
///
/// Blocks until the renderer confirms the stub is removed.
/// Subsequent effects of this kind will be handled normally by
/// the renderer (or return EffectUnsupported if the backend
/// doesn't support it).
pub fn unregister_effect_stub(
  instance: Instance(_),
  kind: String,
) -> Result(Nil, Nil) {
  let reply = process.new_subject()
  process.send(instance.runtime, runtime.UnregisterEffectStub(kind:, reply:))
  process.receive(reply, 5000)
}

@target(erlang)
/// Query and clear accumulated prop validation warnings.
///
/// Returns a list of (node_id, node_type, warnings) tuples for
/// each node that had validation issues since the last query.
/// Warnings are cleared after retrieval.
pub fn get_prop_warnings(
  instance: Instance(_),
) -> Result(List(#(String, String, List(String))), Nil) {
  let reply = process.new_subject()
  process.send(instance.runtime, runtime.GetPropWarnings(reply:))
  process.receive(reply, 5000)
}

@target(erlang)
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
pub fn wait(instance: Instance(_)) -> Nil {
  let _monitor = process.monitor(instance.supervisor)
  let selector =
    process.new_selector()
    |> process.select_monitors(fn(_down) { Nil })
  process.selector_receive_forever(selector)
}
