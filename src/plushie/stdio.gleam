//// Run a plushie application in stdio transport mode.
////
//// In stdio mode, the Rust renderer spawns the Gleam process (not
//// the other way around) and communicates over stdin/stdout. This
//// is the inverse of `gui.run` where Gleam spawns the renderer.
//// All log output goes to stderr to avoid corrupting the wire
//// protocol on stdout.
////
//// Use stdio mode when embedding plushie in a larger application
//// that manages the renderer lifecycle externally.
////
//// ```gleam
//// import plushie/stdio
////
//// pub fn main() {
////   stdio.run(my_app.app(), stdio.default_opts())
//// }
//// ```

@target(erlang)
import gleam/erlang/process
@target(erlang)
import gleam/io
@target(erlang)
import gleam/option.{None}
@target(erlang)
import plushie
@target(erlang)
import plushie/app.{type App}
@target(erlang)
import plushie/event.{type Event}
@target(erlang)
import plushie/protocol

@target(erlang)
/// Options for stdio mode.
pub type StdioOpts {
  StdioOpts(
    /// Wire format. Default: MessagePack.
    format: protocol.Format,
    /// Keep running after all windows close. Default: False.
    daemon: Bool,
  )
}

@target(erlang)
/// Default stdio options.
pub fn default_opts() -> StdioOpts {
  StdioOpts(format: protocol.Msgpack, daemon: False)
}

@target(erlang)
/// Run a plushie application in stdio transport mode.
///
/// Starts the runtime with stdio transport and blocks until
/// the process exits (typically on stdin EOF).
pub fn run(app: App(model, Event), opts: StdioOpts) -> Nil {
  let start_opts =
    plushie.StartOpts(
      ..plushie.default_start_opts(),
      binary_path: None,
      format: opts.format,
      daemon: opts.daemon,
      transport: plushie.Stdio,
    )

  case plushie.start(app, start_opts) {
    Ok(_runtime_subject) -> {
      // Block until the runtime exits (stdin EOF)
      process.sleep_forever()
    }
    Error(_err) -> {
      io.println_error("Failed to start plushie in stdio mode")
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
