//// Integration tests for window lifecycle against the real renderer
//// binary (--mock mode).
////
//// These tests verify that the runtime detects window nodes in the
//// tree and sends the appropriate open/close operations to the
//// renderer. In mock mode, window ops are accepted by the protocol
//// but no real windows are created.

import gleam/option
import plushie/app.{type App}
import plushie/command
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/support
import plushie/ui
import plushie/widget/window

// ---------------------------------------------------------------------------
// Window app: main window always present, secondary toggled by event
// ---------------------------------------------------------------------------

type WindowModel {
  WindowModel(show_secondary: Bool)
}

fn window_init() -> #(WindowModel, command.Command(Event)) {
  #(WindowModel(show_secondary: False), command.none())
}

fn window_update(
  model: WindowModel,
  event: Event,
) -> #(WindowModel, command.Command(Event)) {
  case event {
    event.WidgetClick(window_id: "main", id: "toggle", ..) -> #(
      WindowModel(show_secondary: !model.show_secondary),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn window_view(model: WindowModel) -> Node {
  case model.show_secondary {
    False ->
      ui.window("main", [window.Title("Main Window")], [
        ui.button_("toggle", "Open Secondary"),
      ])
    True ->
      node.new("root", "container")
      |> node.with_children([
        ui.window("main", [window.Title("Main Window")], [
          ui.button_("toggle", "Close Secondary"),
        ]),
        ui.window("secondary", [window.Title("Secondary")], [
          ui.text_("info", "Second window"),
        ]),
      ])
  }
}

fn window_app() -> App(WindowModel, Event) {
  app.simple(window_init, window_update, window_view)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// App with a window node starts without crashing.
pub fn window_opens_on_start_test() -> Nil {
  let rt = support.start(window_app(), [])
  let assert Ok(model) = support.model(rt)
  let assert False = model.show_secondary
  // Verify tree has the window
  let assert Ok(option.Some(tree)) = support.tree(rt)
  let assert "main" = tree.id
  let assert "window" = tree.kind
  support.stop(rt)
  Nil
}

/// Toggling a second window on and off doesn't crash the runtime.
pub fn conditional_window_toggle_test() -> Nil {
  let rt = support.start(window_app(), [])

  // Open secondary window
  support.dispatch_event(
    rt,
    event.WidgetClick(window_id: "main", id: "toggle", scope: []),
  )
  let result = support.await(rt, fn(m) { m.show_secondary }, 500)
  let assert Ok(_) = result

  // Close secondary window
  support.dispatch_event(
    rt,
    event.WidgetClick(window_id: "main", id: "toggle", scope: []),
  )
  let result = support.await(rt, fn(m) { !m.show_secondary }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}
