//// Dev server: file watcher and recompiler for live reload.
////
//// Watches source directories for `.gleam` file changes, runs
//// `gleam build`, detects changed BEAM modules, reloads them, and
//// tells the runtime to re-render. The UI updates without losing
//// application state.
////
//// Started automatically when `dev: True` is set in StartOpts.
//// Requires the `file_system` Erlang package.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor
import gleam/string
import toddy/ffi
import toddy/runtime

const default_debounce_ms = 100

const default_watch_dirs = ["src/"]

const gleam_extension = ".gleam"

const build_dir = "build/dev/erlang"

// -- Types -------------------------------------------------------------------

/// Messages handled by the dev server actor.
pub opaque type DevMessage {
  /// Debounce timer expired -- time to recompile.
  Recompile
  /// Raw file event from the watcher (decoded from Dynamic).
  RawFileEvent(Dynamic)
}

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

/// Start the dev server actor, watching src/ for changes.
pub fn start(runtime: Subject(runtime.RuntimeMessage)) -> Nil {
  // Snapshot initial BEAM mtimes
  let initial_mtimes = ffi.list_beam_files(build_dir)

  // Start file watcher
  let watcher = ffi.start_file_watcher(default_watch_dirs)
  ffi.file_watcher_subscribe(watcher)

  let _actor =
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
      |> Ok
    })
    |> actor.on_message(handle_message)
    |> actor.start()

  io.println("toddy dev: watching " <> string.join(default_watch_dirs, ", "))
  Nil
}

// -- Actor loop --------------------------------------------------------------

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

      io.println("toddy dev: recompiling...")
      let output = ffi.gleam_build()

      case string.contains(output, "error") {
        True -> {
          io.println("toddy dev: build failed:")
          io.println(output)
          actor.continue(state)
        }
        False -> {
          // Detect changed modules by comparing mtimes
          let new_mtimes = ffi.list_beam_files(build_dir)
          let changed = find_changed_modules(state.last_mtimes, new_mtimes)

          case changed {
            [] -> {
              io.println("toddy dev: no modules changed")
              actor.continue(DevState(..state, last_mtimes: new_mtimes))
            }
            modules -> {
              ffi.reload_modules(modules)
              process.send(state.runtime, runtime.ForceRerender)
              io.println("toddy dev: reload complete")
              actor.continue(DevState(..state, last_mtimes: new_mtimes))
            }
          }
        }
      }
    }
  }
}

// -- Helpers -----------------------------------------------------------------

/// Check if a path ends with the Gleam file extension.
fn is_gleam_file(path: String) -> Bool {
  string.ends_with(path, gleam_extension)
  && !string.contains(path, "/_build/")
  && !string.contains(path, "/build/")
}

/// Extract a file path from a raw file_system event.
@external(erlang, "toddy_dev_server_ffi", "extract_file_path")
fn extract_file_path(msg: Dynamic) -> Result(String, Nil)

/// Find modules whose mtimes changed between two snapshots.
@external(erlang, "toddy_dev_server_ffi", "find_changed_modules")
fn find_changed_modules(
  old: List(#(Dynamic, Dynamic)),
  new: List(#(Dynamic, Dynamic)),
) -> List(Dynamic)
