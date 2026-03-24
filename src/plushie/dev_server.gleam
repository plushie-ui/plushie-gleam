//// Dev server: file watcher and recompiler for live reload.
////
//// Watches source directories for `.gleam` file changes, runs
//// `gleam build`, detects changed BEAM modules, reloads them, and
//// tells the runtime to re-render. The UI updates without losing
//// application state.
////
//// Started automatically when `dev: True` is set in StartOpts.
//// Requires the `file_system` Erlang package.

@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/erlang/process.{type Subject}
@target(erlang)
import gleam/otp/actor
@target(erlang)
import gleam/string
@target(erlang)
import plushie/platform
@target(erlang)
import plushie/runtime

@target(erlang)
const default_debounce_ms = 100

@target(erlang)
const default_watch_dirs = ["src/"]

@target(erlang)
const gleam_extension = ".gleam"

@target(erlang)
const build_dir = "build/dev/erlang"

// -- Types -------------------------------------------------------------------

@target(erlang)
/// Messages handled by the dev server actor.
pub opaque type DevMessage {
  /// Debounce timer expired -- time to recompile.
  Recompile
  /// Raw file event from the watcher (decoded from Dynamic).
  RawFileEvent(Dynamic)
}

@target(erlang)
/// Dev server actor state.
type DevState {
  DevState(
    runtime: Subject(runtime.RuntimeMessage),
    watcher: Dynamic,
    debounce_pending: Bool,
    last_mtimes: List(#(Dynamic, Dynamic)),
    self: Subject(DevMessage),
  )
}

// -- Public API --------------------------------------------------------------

@target(erlang)
/// Start the dev server actor, watching src/ for changes.
pub fn start(runtime: Subject(runtime.RuntimeMessage)) -> Nil {
  let _result = start_actor(runtime)
  platform.log_info(
    "plushie dev: watching " <> string.join(default_watch_dirs, ", "),
  )
  Nil
}

@target(erlang)
/// Start the dev server under a supervisor.
///
/// Returns `Started` for use as a supervisor child spec.
pub fn start_supervised(
  runtime: Subject(runtime.RuntimeMessage),
) -> Result(actor.Started(Subject(DevMessage)), actor.StartError) {
  case start_actor(runtime) {
    Ok(started) -> {
      platform.log_info(
        "plushie dev: watching " <> string.join(default_watch_dirs, ", "),
      )
      Ok(started)
    }
    Error(err) -> Error(err)
  }
}

@target(erlang)
fn start_actor(
  runtime: Subject(runtime.RuntimeMessage),
) -> Result(actor.Started(Subject(DevMessage)), actor.StartError) {
  // Snapshot initial BEAM mtimes
  let initial_mtimes = list_beam_files(build_dir)

  // Start file watcher
  let watcher = start_file_watcher(default_watch_dirs)
  file_watcher_subscribe(watcher)

  actor.new_with_initialiser(5000, fn(self: Subject(DevMessage)) {
    let initial_state =
      DevState(
        runtime:,
        watcher:,
        debounce_pending: False,
        last_mtimes: initial_mtimes,
        self:,
      )

    // Set up a selector that receives both our own messages
    // and raw file events from the watcher process
    let selector =
      process.new_selector()
      |> process.select(self)
      |> process.select_other(fn(msg) { RawFileEvent(msg) })

    actor.initialised(initial_state)
    |> actor.selecting(selector)
    |> actor.returning(self)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

// -- Actor loop --------------------------------------------------------------

@target(erlang)
fn handle_message(
  state: DevState,
  msg: DevMessage,
) -> actor.Next(DevState, DevMessage) {
  case msg {
    RawFileEvent(raw) -> {
      // file_system sends {file_event, Pid, {Path, Events}}
      // Try to extract the path from the raw message
      case extract_file_path(raw) {
        Ok(path) -> {
          case is_gleam_file(path) {
            True -> {
              case state.debounce_pending {
                True -> actor.continue(state)
                False -> {
                  process.send_after(state.self, default_debounce_ms, Recompile)
                  actor.continue(DevState(..state, debounce_pending: True))
                }
              }
            }
            False -> actor.continue(state)
          }
        }
        Error(_) -> actor.continue(state)
      }
    }

    Recompile -> {
      let state = DevState(..state, debounce_pending: False)

      platform.log_info("plushie dev: recompiling...")
      let output = gleam_build()

      case string.contains(output, "error") {
        True -> {
          platform.log_error("plushie dev: build failed:\n" <> output)
          actor.continue(state)
        }
        False -> {
          // Detect changed modules by comparing mtimes
          let new_mtimes = list_beam_files(build_dir)
          let changed = find_changed_modules(state.last_mtimes, new_mtimes)

          case changed {
            [] -> {
              platform.log_info("plushie dev: no modules changed")
              actor.continue(DevState(..state, last_mtimes: new_mtimes))
            }
            modules -> {
              reload_modules(modules)
              process.send(state.runtime, runtime.ForceRerender)
              platform.log_info("plushie dev: reload complete")
              actor.continue(DevState(..state, last_mtimes: new_mtimes))
            }
          }
        }
      }
    }
  }
}

// -- Helpers -----------------------------------------------------------------

@target(erlang)
/// Check if a path is a Gleam source file worth watching.
/// Excludes _build/ and build/ only when they appear as directory
/// boundaries, not as substrings of other directory names.
fn is_gleam_file(path: String) -> Bool {
  string.ends_with(path, gleam_extension)
  && !string.contains(path, "/_build/")
  && !string.starts_with(path, "_build/")
  && !is_build_output_dir(path)
}

@target(erlang)
/// Check if a path is inside a top-level build output directory.
/// Matches "/build/dev/" or "build/dev/" but not "/my_build/".
fn is_build_output_dir(path: String) -> Bool {
  string.contains(path, "/build/dev/") || string.starts_with(path, "build/dev/")
}

@target(erlang)
/// Extract a file path from a raw file_system event.
@external(erlang, "plushie_dev_server_ffi", "extract_file_path")
fn extract_file_path(msg: Dynamic) -> Result(String, Nil)

@target(erlang)
/// Find modules whose mtimes changed between two snapshots.
@external(erlang, "plushie_dev_server_ffi", "find_changed_modules")
fn find_changed_modules(
  old: List(#(Dynamic, Dynamic)),
  new: List(#(Dynamic, Dynamic)),
) -> List(Dynamic)

@target(erlang)
/// Run `gleam build` and return the output.
@external(erlang, "plushie_ffi", "gleam_build")
fn gleam_build() -> String

@target(erlang)
/// Reload a list of module atoms (purge + load_file).
@external(erlang, "plushie_ffi", "reload_modules")
fn reload_modules(modules: List(Dynamic)) -> Nil

@target(erlang)
/// List .beam files in a directory, returning (module_atom, mtime) tuples.
@external(erlang, "plushie_ffi", "list_beam_files")
fn list_beam_files(dir: String) -> List(#(Dynamic, Dynamic))

@target(erlang)
/// Start a file_system watcher on the given directories.
@external(erlang, "plushie_ffi", "start_file_watcher")
fn start_file_watcher(dirs: List(String)) -> Dynamic

@target(erlang)
/// Subscribe the calling process to file events from the watcher.
@external(erlang, "plushie_ffi", "file_watcher_subscribe")
fn file_watcher_subscribe(pid: Dynamic) -> Nil
