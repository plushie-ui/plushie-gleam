//// Replay a .plushie script with real timing and windows.
////
//// Parses a script file and executes it with the windowed backend,
//// respecting wait timings for demos and debugging.
////
//// ```gleam
//// import plushie/replay
////
//// pub fn main() {
////   replay.run("demo.plushie", my_app.app())
//// }
//// ```

import gleam/io
import gleam/list
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/testing/script as script_parser
import plushie/testing/script/runner
import plushie/testing/session

/// Replay a .plushie script file with real windows and timing.
///
/// Parses the script, executes it step by step, and reports results.
/// For visual debugging, use the windowed test backend
/// (PLUSHIE_TEST_BACKEND=windowed).
pub fn run(path: String, app: App(model, Event)) -> Nil {
  io.println("Replaying " <> path <> "...")
  case script_parser.parse_file(path) {
    Error(reason) -> {
      io.println("Failed to parse script: " <> reason)
      halt(1)
    }
    Ok(script_val) -> {
      let sess = session.start(app)
      case runner.run(script_val, sess) {
        Ok(Nil) -> {
          io.println("Replay complete: all assertions passed")
          Nil
        }
        Error(failures) -> {
          list.each(failures, fn(f) { io.println("FAIL: " <> f.reason) })
          halt(1)
        }
      }
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
