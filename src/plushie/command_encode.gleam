//// Command-to-wire classification.
////
//// Converts a `Command(msg)` into a `WireOp(msg)`, a tagged union that
//// separates the payload construction (shared between BEAM and JS runtimes)
//// from the actual send mechanism (runtime-specific). Both runtimes
//// pattern-match on `WireOp` and dispatch to their own transport layer.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option
import plushie/command.{type Command}
import plushie/node.{
  type PropValue, BinaryVal, BoolVal, FloatVal, IntVal, StringVal,
}

/// Wire operations that both runtimes handle identically on the encoding
/// side; only the send mechanism differs.
pub type WireOp(msg) {
  /// No side effect.
  NoOp
  /// Shut down the runtime.
  Exit
  /// Execute sub-commands in list order.
  RunBatch(commands: List(Command(msg)))
  /// Inject an already-resolved msg into the update loop.
  DoneImmediate(value: Dynamic, mapper: fn(Dynamic) -> msg)
  /// Schedule a msg delivery after a delay.
  ScheduleTimer(delay_ms: Int, msg: msg)
  /// Run a function on a background process / Promise.
  SpawnAsync(tag: String, work: fn() -> Dynamic)
  /// Run a streaming function that can emit multiple values.
  SpawnStream(tag: String, work: fn(fn(Dynamic) -> Nil) -> Dynamic)
  /// Cancel a running async/stream task.
  CancelTask(tag: String)

  /// Unified widget-targeted command (focus, scroll, text, pane, custom).
  /// Wire format: {type: "command", id, family, value}
  Command(id: String, family: String, value: Dict(String, PropValue))
  /// Batch of widget-targeted commands.
  /// Wire format: {type: "commands", commands: [{id, family, value}, ...]}
  CommandBatch(commands: List(#(String, String, Dict(String, PropValue))))
  /// Global widget operation (no target ID: focus_next, announce, etc.).
  WidgetOp(op: String, payload: List(#(String, PropValue)))
  /// Window lifecycle operation (resize, move, maximize, etc.).
  WindowOp(op: String, window_id: String, settings: List(#(String, PropValue)))
  /// Window query (get_size, get_position, etc.): a window_op with a tag.
  WindowQuery(op: String, window_id: String, tag: String)
  /// System-wide operation not tied to a specific window.
  SystemOp(op: String, settings: List(#(String, PropValue)))
  /// System-wide query.
  SystemQuery(op: String, tag: String)
  /// Image operation (create, update, delete).
  ImageOp(op: String, payload: List(#(String, PropValue)))
  /// Platform effect request (file dialog, clipboard, notification).
  EffectRequest(
    id: String,
    tag: String,
    kind: String,
    payload: Dict(String, PropValue),
  )
  /// Advance one frame in test/headless mode.
  AdvanceFrame(timestamp: Int)
}

/// Classify a command into a wire operation. All payload construction
/// happens here; the caller only needs to route the result to the
/// appropriate transport.
pub fn classify(cmd: Command(msg)) -> WireOp(msg) {
  case cmd {
    command.None -> NoOp
    command.Exit -> Exit
    command.Batch(commands:) -> RunBatch(commands)
    command.Done(value:, mapper:) -> DoneImmediate(value, mapper)
    command.SendAfter(delay_ms:, msg:) -> ScheduleTimer(delay_ms, msg)
    command.Async(work:, tag:) -> SpawnAsync(tag, work)
    command.Stream(work:, tag:) -> SpawnStream(tag, work)
    command.Cancel(tag:) -> CancelTask(tag)
    command.Renderer(renderer_cmd) -> classify_renderer(renderer_cmd)
  }
}

fn classify_renderer(cmd: command.RendererCommand) -> WireOp(msg) {
  case cmd {
    // -- Widget-targeted commands (unified format) --
    command.Focus(widget_id:) -> Command(widget_id, "focus", dict.new())
    command.FocusNext -> WidgetOp("focus_next", [])
    command.FocusPrevious -> WidgetOp("focus_previous", [])
    command.FocusNextWithin(scope:) ->
      WidgetOp("focus_next_within", [#("scope", StringVal(scope))])
    command.FocusPreviousWithin(scope:) ->
      WidgetOp("focus_previous_within", [#("scope", StringVal(scope))])
    command.SelectAll(widget_id:) ->
      Command(widget_id, "select_all", dict.new())
    command.MoveCursorToFront(widget_id:) ->
      Command(widget_id, "move_cursor_to_front", dict.new())
    command.MoveCursorToEnd(widget_id:) ->
      Command(widget_id, "move_cursor_to_end", dict.new())
    command.MoveCursorTo(widget_id:, position:) ->
      Command(
        widget_id,
        "move_cursor_to",
        dict.from_list([#("position", IntVal(position))]),
      )
    command.SelectRange(widget_id:, start_pos:, end_pos:) ->
      Command(
        widget_id,
        "select_range",
        dict.from_list([
          #("start_pos", IntVal(start_pos)),
          #("end_pos", IntVal(end_pos)),
        ]),
      )
    command.ScrollTo(widget_id:, x:, y:) ->
      Command(
        widget_id,
        "scroll_to",
        dict.from_list([#("x", FloatVal(x)), #("y", FloatVal(y))]),
      )
    command.SnapTo(widget_id:, x:, y:) ->
      Command(
        widget_id,
        "snap_to",
        dict.from_list([#("x", FloatVal(x)), #("y", FloatVal(y))]),
      )
    command.SnapToEnd(widget_id:) ->
      Command(widget_id, "snap_to_end", dict.new())
    command.ScrollBy(widget_id:, x:, y:) ->
      Command(
        widget_id,
        "scroll_by",
        dict.from_list([#("x", FloatVal(x)), #("y", FloatVal(y))]),
      )

    // -- Global ops (no target ID, stay as widget_op) --
    command.Announce(text:, politeness:) ->
      WidgetOp("announce", [
        #("text", StringVal(text)),
        #("politeness", StringVal(politeness_to_wire(politeness))),
      ])
    command.TreeHashQuery(tag:) ->
      WidgetOp("tree_hash", [#("tag", StringVal(tag))])
    command.FindFocused(tag:) ->
      WidgetOp("find_focused", [#("tag", StringVal(tag))])
    command.LoadFont(family:, data:) ->
      WidgetOp("load_font", [
        #("family", StringVal(family)),
        #("data", StringVal(bit_array.base64_encode(data, True))),
      ])

    // -- Pane grid commands (widget-targeted) --
    command.PaneSplit(pane_grid_id:, pane_id:, axis:, new_pane_id:) ->
      Command(
        pane_grid_id,
        "pane_split",
        dict.from_list([
          #("pane", StringVal(pane_id)),
          #("axis", StringVal(axis)),
          #("new_pane_id", StringVal(new_pane_id)),
        ]),
      )
    command.PaneClose(pane_grid_id:, pane_id:) ->
      Command(
        pane_grid_id,
        "pane_close",
        dict.from_list([#("pane", StringVal(pane_id))]),
      )
    command.PaneSwap(pane_grid_id:, pane_a:, pane_b:) ->
      Command(
        pane_grid_id,
        "pane_swap",
        dict.from_list([#("a", StringVal(pane_a)), #("b", StringVal(pane_b))]),
      )
    command.PaneMaximize(pane_grid_id:, pane_id:) ->
      Command(
        pane_grid_id,
        "pane_maximize",
        dict.from_list([#("pane", StringVal(pane_id))]),
      )
    command.PaneRestore(pane_grid_id:) ->
      Command(pane_grid_id, "pane_restore", dict.new())

    // -- Window, system, image (delegated) --
    command.Window(window_cmd) -> classify_window(window_cmd)
    command.System(system_cmd) -> classify_system(system_cmd)
    command.Image(image_cmd) -> classify_image(image_cmd)

    // -- Effect, widget command, advance frame --
    command.Effect(id:, tag:, kind:, payload:) ->
      EffectRequest(id, tag, kind, payload)
    command.NativeCommand(node_id:, op:, payload:) ->
      case command.is_valid_native_op(op) {
        True -> Command(node_id, op, payload)
        False -> NoOp
      }
    command.NativeCommands(commands:) ->
      case list.all(commands, fn(cmd) { command.is_valid_native_op(cmd.1) }) {
        True -> CommandBatch(commands)
        False -> NoOp
      }
    command.AdvanceFrame(timestamp:) -> AdvanceFrame(timestamp)
  }
}

fn classify_window(cmd: command.WindowCommand) -> WireOp(msg) {
  case cmd {
    command.CloseWindow(window_id:) -> WindowOp("close", window_id, [])
    command.ResizeWindow(window_id:, width:, height:) ->
      WindowOp("resize", window_id, [
        #("width", FloatVal(width)),
        #("height", FloatVal(height)),
      ])
    command.MoveWindow(window_id:, x:, y:) ->
      WindowOp("move", window_id, [
        #("x", FloatVal(x)),
        #("y", FloatVal(y)),
      ])
    command.MaximizeWindow(window_id:, maximized:) ->
      WindowOp("maximize", window_id, [#("maximized", BoolVal(maximized))])
    command.MinimizeWindow(window_id:, minimized:) ->
      WindowOp("minimize", window_id, [#("minimized", BoolVal(minimized))])
    command.SetWindowMode(window_id:, mode:) ->
      WindowOp("set_mode", window_id, [#("mode", StringVal(mode))])
    command.ToggleMaximize(window_id:) ->
      WindowOp("toggle_maximize", window_id, [])
    command.ToggleDecorations(window_id:) ->
      WindowOp("toggle_decorations", window_id, [])
    command.FocusWindow(window_id:) -> WindowOp("gain_focus", window_id, [])
    command.SetWindowLevel(window_id:, level:) ->
      WindowOp("set_level", window_id, [#("level", StringVal(level))])
    command.DragWindow(window_id:) -> WindowOp("drag", window_id, [])
    command.DragResizeWindow(window_id:, direction:) ->
      WindowOp("drag_resize", window_id, [
        #("direction", StringVal(direction)),
      ])
    command.RequestUserAttention(window_id:, urgency:) -> {
      let payload = case urgency {
        option.Some(u) -> [#("urgency", StringVal(u))]
        option.None -> []
      }
      WindowOp("request_attention", window_id, payload)
    }
    command.Screenshot(window_id:, tag:) ->
      WindowOp("screenshot", window_id, [#("tag", StringVal(tag))])
    command.SetResizable(window_id:, resizable:) ->
      WindowOp("set_resizable", window_id, [
        #("resizable", BoolVal(resizable)),
      ])
    command.SetMinSize(window_id:, width:, height:) ->
      WindowOp("set_min_size", window_id, [
        #("width", FloatVal(width)),
        #("height", FloatVal(height)),
      ])
    command.SetMaxSize(window_id:, width:, height:) ->
      WindowOp("set_max_size", window_id, [
        #("width", FloatVal(width)),
        #("height", FloatVal(height)),
      ])
    command.EnableMousePassthrough(window_id:) ->
      WindowOp("mouse_passthrough", window_id, [#("enabled", BoolVal(True))])
    command.DisableMousePassthrough(window_id:) ->
      WindowOp("mouse_passthrough", window_id, [#("enabled", BoolVal(False))])
    command.ShowSystemMenu(window_id:) ->
      WindowOp("show_system_menu", window_id, [])
    command.SetResizeIncrements(window_id:, width:, height:) -> {
      let payload = case width, height {
        option.Some(w), option.Some(h) -> [
          #("width", FloatVal(w)),
          #("height", FloatVal(h)),
        ]
        option.Some(w), option.None -> [#("width", FloatVal(w))]
        option.None, option.Some(h) -> [#("height", FloatVal(h))]
        option.None, option.None -> []
      }
      WindowOp("set_resize_increments", window_id, payload)
    }
    command.SetIcon(window_id:, rgba_data:, width:, height:) ->
      WindowOp("set_icon", window_id, [
        #("data", StringVal(bit_array.base64_encode(rgba_data, True))),
        #("width", IntVal(width)),
        #("height", IntVal(height)),
      ])

    // -- Window queries --
    command.GetWindowSize(window_id:, tag:) ->
      WindowQuery("get_size", window_id, tag)
    command.GetWindowPosition(window_id:, tag:) ->
      WindowQuery("get_position", window_id, tag)
    command.IsMaximized(window_id:, tag:) ->
      WindowQuery("is_maximized", window_id, tag)
    command.IsMinimized(window_id:, tag:) ->
      WindowQuery("is_minimized", window_id, tag)
    command.GetMode(window_id:, tag:) -> WindowQuery("get_mode", window_id, tag)
    command.GetScaleFactor(window_id:, tag:) ->
      WindowQuery("get_scale_factor", window_id, tag)
    command.RawWindowId(window_id:, tag:) ->
      WindowQuery("raw_id", window_id, tag)
    command.MonitorSize(window_id:, tag:) ->
      WindowQuery("monitor_size", window_id, tag)
  }
}

fn classify_system(cmd: command.SystemCommand) -> WireOp(msg) {
  case cmd {
    command.AllowAutomaticTabbing(enabled:) ->
      SystemOp("allow_automatic_tabbing", [
        #("enabled", BoolVal(enabled)),
      ])
    command.GetSystemTheme(tag:) -> SystemQuery("get_system_theme", tag)
    command.GetSystemInfo(tag:) -> SystemQuery("get_system_info", tag)
  }
}

fn classify_image(cmd: command.ImageCommand) -> WireOp(msg) {
  case cmd {
    command.CreateImage(handle:, data:) ->
      ImageOp("create_image", [
        #("handle", StringVal(handle)),
        #("data", BinaryVal(data)),
      ])
    command.CreateImageRgba(handle:, width:, height:, pixels:) ->
      ImageOp("create_image", [
        #("handle", StringVal(handle)),
        #("width", IntVal(width)),
        #("height", IntVal(height)),
        #("pixels", BinaryVal(pixels)),
      ])
    command.UpdateImage(handle:, data:) ->
      ImageOp("update_image", [
        #("handle", StringVal(handle)),
        #("data", BinaryVal(data)),
      ])
    command.UpdateImageRgba(handle:, width:, height:, pixels:) ->
      ImageOp("update_image", [
        #("handle", StringVal(handle)),
        #("width", IntVal(width)),
        #("height", IntVal(height)),
        #("pixels", BinaryVal(pixels)),
      ])
    command.DeleteImage(handle:) ->
      ImageOp("delete_image", [#("handle", StringVal(handle))])
    command.ListImages(tag:) ->
      WidgetOp("list_images", [#("tag", StringVal(tag))])
    command.ClearImages -> WidgetOp("clear_images", [])
  }
}

fn politeness_to_wire(politeness: command.Politeness) -> String {
  case politeness {
    command.Polite -> "polite"
    command.Assertive -> "assertive"
  }
}
