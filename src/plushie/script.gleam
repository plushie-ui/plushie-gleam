//// Run .plushie test scripts.
////
//// Discovers .plushie script files, parses them, and executes them
//// against the mock backend. Reports pass/fail results.
////
//// ```gleam
//// import plushie/script
////
//// pub fn main() {
////   script.run(["test/scripts"], my_app.app())
//// }
//// ```

import gleam/int
import gleam/io
import gleam/list
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/testing/script as script_parser
import plushie/testing/script/runner
import plushie/testing/session

/// Run .plushie test scripts from the given paths.
///
/// If paths is empty, searches for .plushie files under test/scripts/.
/// Parses each file and executes it against a fresh test session.
/// Prints pass/fail results and exits with status 1 on any failure.
pub fn run(paths: List(String), app: App(model, Event)) -> Nil {
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
      let results = list.map(script_paths, run_script(_, app))
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

fn run_script(path: String, app: App(model, Event)) -> Result(Nil, Nil) {
  io.println("Running " <> path <> "...")
  case script_parser.parse_file(path) {
    Error(reason) -> {
      io.println("  FAIL (parse error: " <> reason <> ")")
      Error(Nil)
    }
    Ok(script_val) -> {
      let sess = session.start(app)
      case runner.run(script_val, sess) {
        Ok(Nil) -> {
          io.println("  PASS")
          Ok(Nil)
        }
        Error(failures) -> {
          list.each(failures, fn(f) { io.println("  FAIL: " <> f.reason) })
          Error(Nil)
        }
      }
    }
  }
}

fn discover_scripts(_dir: String) -> List(String) {
  // Known limitation: automatic discovery of .plushie files is not
  // implemented. Gleam has no built-in recursive directory traversal,
  // and adding FFI for this is not worthwhile given the narrow use
  // case. Callers should pass explicit paths to the run function instead
  // of relying on empty-path auto-discovery.
  []
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
