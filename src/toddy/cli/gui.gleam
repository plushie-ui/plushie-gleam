//// Start a toddy GUI application.
////
//// This is the primary entry point for desktop apps. It resolves the
//// toddy binary, starts the runtime (which spawns the Rust renderer
//// as a child port), and blocks the calling process indefinitely.
//// The runtime manages its own lifecycle in a spawned process.
////
//// Users call `gui.run` from their own `main` function:
////
//// ```gleam
//// import toddy/cli/gui
////
//// pub fn main() {
////   gui.run(my_app.app(), gui.default_opts())
//// }
//// ```
////
//// Set `dev: True` in `GuiOpts` to enable live reload -- the dev
//// server watches `src/` for changes, recompiles, hot-reloads BEAM
//// modules, and triggers a re-render without losing app state.

import gleam/erlang/process
import gleam/io
import gleam/option.{Some}
import toddy
import toddy/app.{type App}
import toddy/cli/helpers
import toddy/event.{type Event}
import toddy/protocol

/// Options for starting a GUI application.
pub type GuiOpts {
  GuiOpts(
    /// Use JSON wire format instead of MessagePack. Default: False.
    json: Bool,
    /// Keep running after all windows close. Default: False.
    daemon: Bool,
    /// Enable dev-mode live reload. Default: False.
    dev: Bool,
    /// File watch debounce interval in milliseconds. Default: 100.
    debounce: Int,
    /// Explicit path to the toddy binary. Error(Nil) = auto-resolve.
    binary_path: Result(String, Nil),
  )
}

/// Default GUI options.
pub fn default_opts() -> GuiOpts {
  GuiOpts(
    json: False,
    daemon: False,
    dev: False,
    debounce: 100,
    binary_path: Error(Nil),
  )
}

/// Start a toddy GUI application, blocking until it exits.
///
/// Resolves the binary, starts the runtime with the given options,
/// and blocks the calling process indefinitely. The runtime runs
/// in a spawned process and handles its own lifecycle.
pub fn run(app: App(model, Event), opts: GuiOpts) -> Nil {
  let resolve_opts = helpers.ResolveOpts(binary_path: opts.binary_path)

  case helpers.resolve_binary(resolve_opts) {
    Error(err) -> {
      io.println_error(helpers.resolve_error_message(err))
      halt(1)
    }
    Ok(binary_path) -> {
      let format = case opts.json {
        True -> protocol.Json
        False -> protocol.Msgpack
      }

      let start_opts =
        toddy.StartOpts(
          ..toddy.default_start_opts(),
          binary_path: Some(binary_path),
          format:,
          daemon: opts.daemon,
          dev: opts.dev,
        )

      case toddy.start(app, start_opts) {
        Ok(_runtime_subject) -> {
          // Block until the runtime exits
          process.sleep_forever()
        }
        Error(_err) -> {
          io.println_error("Failed to start toddy")
          halt(1)
        }
      }
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
