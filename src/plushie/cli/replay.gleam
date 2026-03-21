//// Replay a .plushie script with real timing and windows.
////
//// Parses a script file and executes it with the windowed backend,
//// respecting wait timings for demos and debugging.
////
//// This module is a structural placeholder -- full functionality
//// depends on the renderer backend infrastructure (Batch 20).
////
//// ```gleam
//// import plushie/cli/replay
////
//// pub fn main() {
////   replay.run("demo.plushie", my_app.app())
//// }
//// ```

import gleam/io
import plushie/app.{type App}
import plushie/event.{type Event}

/// Replay a .plushie script file with real windows and timing.
///
/// Parses the script, forces the windowed backend, and executes
/// with timing preserved. Used for demos and visual debugging.
pub fn run(path: String, _app: App(model, Event)) -> Nil {
  io.println("Replaying " <> path <> "...")
  // Placeholder: actual replay depends on testing/script module
  // and the windowed renderer backend (Batch 20).
  io.println("Replay runner not yet available (requires Batch 20 backends)")
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
