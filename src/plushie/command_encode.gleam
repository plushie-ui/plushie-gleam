//// Command-to-wire classification.
////
//// Converts a `Command(msg)` into a `WireOp(msg)` -- a tagged union that
//// separates the payload construction (shared between BEAM and JS runtimes)
//// from the actual send mechanism (runtime-specific). Both runtimes
//// pattern-match on `WireOp` and dispatch to their own transport layer.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option
import plushie/command.{type Command}
import plushie/node.{
  type PropValue, BinaryVal, BoolVal, FloatVal, IntVal, StringVal,
}

/// Wire operations that both runtimes handle identically on the encoding
/// side -- only the send mechanism differs.
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

  /// Widget operation (focus, scroll, select, pane ops, announce, etc.).
  WidgetOp(op: String, payload: List(#(String, PropValue)))
  /// Window lifecycle operation (resize, move, maximize, etc.).
  WindowOp(op: String, window_id: String, settings: List(#(String, PropValue)))
  /// Window query (get_size, get_position, etc.) -- a window_op with a tag.
  WindowQuery(op: String, window_id: String, tag: String)
  /// System-wide operation not tied to a specific window.
  SystemOp(op: String, settings: List(#(String, PropValue)))
  /// System-wide query.
  SystemQuery(op: String, tag: String)
  /// Image operation (create, update, delete).
  ImageOp(op: String, payload: List(#(String, PropValue)))
  /// Platform effect request (file dialog, clipboard, notification).
  EffectRequest(id: String, kind: String, payload: Dict(String, PropValue))
  /// Single widget command for a native extension widget.
  WidgetCmd(node_id: String, op: String, payload: Dict(String, PropValue))
  /// Batch of widget commands for native extension widgets.
  WidgetCmdBatch(commands: List(#(String, String, Dict(String, PropValue))))
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

    // -- Widget ops --
    command.Focus(widget_id:) ->
      WidgetOp("focus", [#("target", StringVal(widget_id))])
    command.FocusElement(canvas_id:, element_id:) ->
      WidgetOp("focus_element", [
        #("target", StringVal(canvas_id)),
        #("element_id", StringVal(element_id)),
      ])
    command.FocusNext -> WidgetOp("focus_next", [])
    command.FocusPrevious -> WidgetOp("focus_previous", [])
    command.SelectAll(widget_id:) ->
      WidgetOp("select_all", [#("target", StringVal(widget_id))])
    command.MoveCursorToFront(widget_id:) ->
      WidgetOp("move_cursor_to_front", [#("target", StringVal(widget_id))])
    command.MoveCursorToEnd(widget_id:) ->
      WidgetOp("move_cursor_to_end", [#("target", StringVal(widget_id))])
    command.MoveCursorTo(widget_id:, position:) ->
      WidgetOp("move_cursor_to", [
        #("target", StringVal(widget_id)),
        #("position", IntVal(position)),
      ])
    command.SelectRange(widget_id:, start:, end:) ->
      WidgetOp("select_range", [
        #("target", StringVal(widget_id)),
        #("start", IntVal(start)),
        #("end", IntVal(end)),
      ])
    command.ScrollTo(widget_id:, offset_x:, offset_y:) -> {
      let payload = [#("target", StringVal(widget_id))]
      let payload = case offset_x {
        option.Some(x) -> [#("offset_x", FloatVal(x)), ..payload]
        option.None -> payload
      }
      let payload = case offset_y {
        option.Some(y) -> [#("offset_y", FloatVal(y)), ..payload]
        option.None -> payload
      }
      WidgetOp("scroll_to", payload)
    }
    command.SnapTo(widget_id:, x:, y:) ->
      WidgetOp("snap_to", [
        #("target", StringVal(widget_id)),
        #("x", FloatVal(x)),
        #("y", FloatVal(y)),
      ])
    command.SnapToEnd(widget_id:) ->
      WidgetOp("snap_to_end", [#("target", StringVal(widget_id))])
    command.ScrollBy(widget_id:, x:, y:) ->
      WidgetOp("scroll_by", [
        #("target", StringVal(widget_id)),
        #("x", FloatVal(x)),
        #("y", FloatVal(y)),
      ])
    command.CloseWindow(window_id:) ->
      WidgetOp("close_window", [#("window_id", StringVal(window_id))])
    command.Announce(text:) ->
      WidgetOp("announce", [#("text", StringVal(text))])
    command.TreeHashQuery(tag:) ->
      WidgetOp("tree_hash", [#("tag", StringVal(tag))])
    command.FindFocused(tag:) ->
      WidgetOp("find_focused", [#("tag", StringVal(tag))])
    command.LoadFont(data:) ->
      WidgetOp("load_font", [
        #("data", StringVal(bit_array.base64_encode(data, True))),
      ])
    command.ListImages(tag:) ->
      WidgetOp("list_images", [#("tag", StringVal(tag))])
    command.ClearImages -> WidgetOp("clear_images", [])

    // -- Pane grid ops (widget_op) --
    command.PaneSplit(pane_grid_id:, pane_id:, axis:, new_pane_id:) ->
      WidgetOp("pane_split", [
        #("target", StringVal(pane_grid_id)),
        #("pane", StringVal(pane_id)),
        #("axis", StringVal(axis)),
        #("new_pane_id", StringVal(new_pane_id)),
      ])
    command.PaneClose(pane_grid_id:, pane_id:) ->
      WidgetOp("pane_close", [
        #("target", StringVal(pane_grid_id)),
        #("pane", StringVal(pane_id)),
      ])
    command.PaneSwap(pane_grid_id:, pane_a:, pane_b:) ->
      WidgetOp("pane_swap", [
        #("target", StringVal(pane_grid_id)),
        #("a", StringVal(pane_a)),
        #("b", StringVal(pane_b)),
      ])
    command.PaneMaximize(pane_grid_id:, pane_id:) ->
      WidgetOp("pane_maximize", [
        #("target", StringVal(pane_grid_id)),
        #("pane", StringVal(pane_id)),
      ])
    command.PaneRestore(pane_grid_id:) ->
      WidgetOp("pane_restore", [#("target", StringVal(pane_grid_id))])

    // -- Window ops --
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
    command.GainFocus(window_id:) -> WindowOp("gain_focus", window_id, [])
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
    command.AllowAutomaticTabbing(enabled:) ->
      SystemOp("allow_automatic_tabbing", [
        #("enabled", BoolVal(enabled)),
      ])
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
    command.GetSystemTheme(tag:) -> SystemQuery("get_system_theme", tag)
    command.GetSystemInfo(tag:) -> SystemQuery("get_system_info", tag)

    // -- Image ops --
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

    // -- Effect, widget command, advance frame --
    command.Effect(id:, kind:, payload:) -> EffectRequest(id, kind, payload)
    command.WidgetCommand(node_id:, op:, payload:) ->
      WidgetCmd(node_id, op, payload)
    command.WidgetCommands(commands:) -> WidgetCmdBatch(commands)
    command.AdvanceFrame(timestamp:) -> AdvanceFrame(timestamp)
  }
}
