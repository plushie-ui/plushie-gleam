//// Windowed test backend with real iced windows.
////
//// Spawns `toddy` as a daemon with real GPU rendering. All protocol
//// messages including scripting messages (Query, Interact, Screenshot,
//// Reset) work in this mode.
////
//// ## Requirements
////
//// Requires DISPLAY or WAYLAND_DISPLAY environment variable to be set.
//// For CI (headless environment), use Xvfb:
////
////     sudo apt-get install -y xvfb mesa-vulkan-drivers
////     Xvfb :99 -screen 0 1024x768x24 &
////     export DISPLAY=:99
////     export WINIT_UNIX_BACKEND=x11
////
//// ## When to use
////
//// End-to-end integration tests that verify the full stack including
//// window lifecycle, real rendering, and platform effects. Slowest
//// backend but highest confidence.

import gleam/option.{type Option, None, Some}
import toddy/app.{type App}
import toddy/event.{type Event}
import toddy/ffi
import toddy/node
import toddy/protocol
import toddy/testing/backend.{type TestBackend, TestBackend}
import toddy/testing/renderer
import toddy/testing/session.{type TestSession}

/// Options for the windowed backend.
pub type WindowedOpts {
  WindowedOpts(
    /// Wire format. Default: Msgpack.
    format: protocol.Format,
    /// Path to the toddy binary. None = auto-resolve.
    renderer_path: Option(String),
  )
}

/// Default windowed options.
pub fn default_opts() -> WindowedOpts {
  WindowedOpts(format: protocol.Msgpack, renderer_path: None)
}

/// Create a windowed test backend with default options.
pub fn backend() -> TestBackend(model) {
  backend_with_opts(default_opts())
}

/// Create a windowed test backend with custom options.
pub fn backend_with_opts(opts: WindowedOpts) -> TestBackend(model) {
  let args = case opts.format {
    protocol.Json -> ["--json"]
    protocol.Msgpack -> []
  }

  let config =
    renderer.RendererConfig(
      args:,
      format: opts.format,
      renderer_path: opts.renderer_path,
      // Windowed backend sends settings before the initial snapshot
      // (required by the daemon's read_initial_settings).
      send_settings: True,
      // No fixed screenshot size -- windowed captures actual window pixels.
      screenshot_size: None,
    )

  TestBackend(
    start: fn(app) { start_windowed(app, config) },
    stop: fn(_sess) { stop_renderer() },
    find: fn(_sess, id) {
      let subj = require_renderer()
      renderer.find(subj, "#" <> id)
    },
    click: fn(sess, id) {
      let subj = require_renderer()
      renderer.click(subj, "#" <> id)
      sess
    },
    type_text: fn(sess, id, text) {
      let subj = require_renderer()
      renderer.type_text(subj, "#" <> id, text)
      sess
    },
    submit: fn(sess, id) {
      let subj = require_renderer()
      renderer.submit(subj, "#" <> id)
      sess
    },
    toggle: fn(sess, id) {
      let subj = require_renderer()
      renderer.toggle(subj, "#" <> id)
      sess
    },
    select: fn(sess, id, value) {
      let subj = require_renderer()
      renderer.select(subj, "#" <> id, value)
      sess
    },
    slide: fn(sess, id, value) {
      let subj = require_renderer()
      renderer.slide(subj, "#" <> id, value)
      sess
    },
    model: fn(_sess) {
      let subj = require_renderer()
      coerce(renderer.model(subj))
    },
    tree: fn(_sess) {
      let subj = require_renderer()
      case renderer.get_tree(subj) {
        Some(data) -> coerce(data)
        None -> node.new("", "empty")
      }
    },
    reset: fn(sess) {
      let subj = require_renderer()
      renderer.reset(subj)
      sess
    },
    send_event: fn(sess, _ev) {
      // Wire events are dispatched by the renderer, not directly
      sess
    },
  )
}

// -- Internal -----------------------------------------------------------------

fn start_windowed(
  app: App(model, Event),
  config: renderer.RendererConfig,
) -> TestSession(model, Event) {
  // Require a display server
  case ffi.get_env("DISPLAY"), ffi.get_env("WAYLAND_DISPLAY") {
    Error(_), Error(_) ->
      panic as "windowed backend requires DISPLAY or WAYLAND_DISPLAY env var (use Xvfb in CI)"
    _, _ -> Nil
  }

  let assert Ok(subj) = renderer.start(app, config)
  put_renderer(subj)
  session.start(app)
}

fn stop_renderer() -> Nil {
  case get_renderer() {
    Ok(subj) -> {
      renderer.stop(subj)
      erase_renderer()
    }
    Error(_) -> Nil
  }
}

fn require_renderer() -> renderer.RendererSubject {
  case get_renderer() {
    Ok(subj) -> subj
    Error(_) -> panic as "windowed backend: no renderer -- call start first"
  }
}

// -- FFI for process dictionary -----------------------------------------------

@external(erlang, "toddy_test_renderer_ffi", "put_renderer")
fn put_renderer(subject: renderer.RendererSubject) -> Nil

@external(erlang, "toddy_test_renderer_ffi", "get_renderer")
fn get_renderer() -> Result(renderer.RendererSubject, Nil)

@external(erlang, "toddy_test_renderer_ffi", "erase_renderer")
fn erase_renderer() -> Nil

@external(erlang, "toddy_test_ffi", "identity")
fn coerce(value: a) -> b
