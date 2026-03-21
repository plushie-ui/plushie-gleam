//// Run a toddy application in stdio transport mode.
////
//// In stdio mode, the renderer spawns the Gleam process and
//// communicates over stdin/stdout. All log output goes to stderr.
////
//// ```gleam
//// import toddy/cli/stdio
////
//// pub fn main() {
////   stdio.run(my_app.app(), stdio.default_opts())
//// }
//// ```

import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import toddy
import toddy/app.{type App}
import toddy/event.{type Event}
import toddy/protocol

/// Options for stdio mode.
pub type StdioOpts {
  StdioOpts(
    /// Wire format. Default: MessagePack.
    format: protocol.Format,
    /// Keep running after all windows close. Default: False.
    daemon: Bool,
  )
}

/// Default stdio options.
pub fn default_opts() -> StdioOpts {
  StdioOpts(format: protocol.Msgpack, daemon: False)
}

/// Run a toddy application in stdio transport mode.
///
/// Starts the runtime with stdio transport and blocks until
/// the process exits (typically on stdin EOF).
pub fn run(app: App(model, Event), opts: StdioOpts) -> Nil {
  let start_opts =
    toddy.StartOpts(
      ..toddy.default_start_opts(),
      binary_path: None,
      format: opts.format,
      daemon: opts.daemon,
      transport: toddy.Stdio,
    )

  case toddy.start(app, start_opts) {
    Ok(_runtime_subject) -> {
      // Block until the runtime exits (stdin EOF)
      process.sleep_forever()
    }
    Error(_err) -> {
      io.println_error("Failed to start toddy in stdio mode")
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
