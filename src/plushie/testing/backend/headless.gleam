//// Headless test backend using the Rust renderer with software rendering.
////
//// Spawns `plushie --headless` as a Port and communicates via the negotiated
//// wire format (msgpack by default, json opt-in). Provides structural tree
//// snapshots and real widget rendering for regression testing. No display
//// server required.
////
//// ## Limitations
////
//// - No real windows or GPU rendering (use windowed for that).
//// - Effects (file dialogs, clipboard) return cancelled.
//// - Subscriptions are tracked but not fired (no event loop).

import gleam/option.{type Option, None, Some}
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node
import plushie/protocol
import plushie/testing/backend.{type TestBackend, TestBackend}
import plushie/testing/renderer
import plushie/testing/session.{type TestSession}

/// Options for the headless backend.
pub type HeadlessOpts {
  HeadlessOpts(
    /// Wire format. Default: Msgpack.
    format: protocol.Format,
    /// Path to the plushie binary. None = auto-resolve.
    renderer_path: Option(String),
  )
}

/// Default headless options.
pub fn default_opts() -> HeadlessOpts {
  HeadlessOpts(format: protocol.Msgpack, renderer_path: None)
}

/// Create a headless test backend with default options.
pub fn backend() -> TestBackend(model) {
  backend_with_opts(default_opts())
}

/// Create a headless test backend with custom options.
pub fn backend_with_opts(opts: HeadlessOpts) -> TestBackend(model) {
  let args = case opts.format {
    protocol.Json -> ["--headless", "--json"]
    protocol.Msgpack -> ["--headless"]
  }

  let config =
    renderer.RendererConfig(
      args:,
      format: opts.format,
      renderer_path: opts.renderer_path,
      send_settings: False,
      screenshot_size: Some(#(1024, 768)),
    )

  TestBackend(
    start: fn(app) { start_headless(app, config) },
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

fn start_headless(
  app: App(model, Event),
  config: renderer.RendererConfig,
) -> TestSession(model, Event) {
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
    Error(_) -> panic as "headless backend: no renderer -- call start first"
  }
}

// -- FFI for process dictionary -----------------------------------------------

@external(erlang, "plushie_test_renderer_ffi", "put_renderer")
fn put_renderer(subject: renderer.RendererSubject) -> Nil

@external(erlang, "plushie_test_renderer_ffi", "get_renderer")
fn get_renderer() -> Result(renderer.RendererSubject, Nil)

@external(erlang, "plushie_test_renderer_ffi", "erase_renderer")
fn erase_renderer() -> Nil

@external(erlang, "plushie_test_ffi", "identity")
fn coerce(value: a) -> b
