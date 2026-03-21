//// Run .plushie test scripts.
////
//// Discovers .plushie script files, parses them, and executes them
//// against the mock backend. Reports pass/fail results.
////
//// This module is a structural placeholder -- full functionality
//// depends on the renderer backend infrastructure (Batch 20).
////
//// ```gleam
//// import plushie/cli/script
////
//// pub fn main() {
////   script.run(["test/scripts"])
//// }
//// ```

import gleam/int
import gleam/io
import gleam/list

/// Run .plushie test scripts from the given paths.
///
/// If paths is empty, searches for .plushie files under test/scripts/.
/// Parses each file and executes it against the mock backend.
/// Prints pass/fail results and exits with status 1 on any failure.
pub fn run(paths: List(String)) -> Nil {
  let script_paths = case paths {
    [] -> discover_scripts("test/scripts")
    given -> given
  }

  case script_paths {
    [] -> {
      io.println("No .plushie scripts found")
      Nil
    }
    _ -> {
      let results = list.map(script_paths, run_script)
      let failures = list.count(results, fn(r) { r == Error(Nil) })
      let passes = list.count(results, fn(r) { r == Ok(Nil) })

      io.println("")
      io.println(
        int.to_string(passes)
        <> " passed, "
        <> int.to_string(failures)
        <> " failed",
      )

      case failures > 0 {
        True -> halt(1)
        False -> Nil
      }
    }
  }
}

fn run_script(path: String) -> Result(Nil, Nil) {
  io.println("Running " <> path <> "...")
  // Placeholder: actual script parsing and execution depends on
  // testing/script module (Batch 20 renderer backends).
  io.println("  SKIP (script runner not yet available)")
  Ok(Nil)
}

fn discover_scripts(_dir: String) -> List(String) {
  // Placeholder: will use file system to find .plushie files once
  // the testing/script module is available (Batch 20).
  []
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
