//// Platform effects: file dialogs, clipboard, notifications.
////
//// Each function takes a `tag` string as the first argument and returns
//// a `Command(msg)` that the runtime sends to the bridge as an effect
//// request. The result arrives as an `EffectResponse` event with the
//// matching `tag` for clean pattern matching in `update`.
////
//// Only one effect per tag can be in flight at a time. Starting a new
//// effect with a tag that already has a pending request discards the
//// previous one.
////
//// ## Example
////
//// ```gleam
//// fn update(model, event) {
////   case event {
////     Widget(Click(target: EventTarget(id: "open", ..))) ->
////       #(model, effect.file_open("import", [effect.DialogTitle("Pick")]))
////
////     Effect(EffectEvent(tag: "import", result: EffectOk(data))) ->
////       #(Model(..model, file: data), command.none())
////
////     Effect(EffectEvent(tag: "import", result: EffectCancelled)) ->
////       #(model, command.none())
////     _ -> #(model, command.none())
////   }
//// }
//// ```

import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/command.{type Command}
import plushie/node.{type PropValue, IntVal, ListVal, StringVal}
import plushie/platform

// -- File dialog option types ------------------------------------------------

/// Options for file dialog effects.
pub type FileDialogOpt {
  /// Title shown in the dialog window.
  DialogTitle(String)
  /// Default starting path.
  DefaultPath(String)
  /// File type filters as (label, pattern) pairs.
  /// Example: #("Images", "*.png;*.jpg")
  Filters(List(#(String, String)))
}

// -- Notification option types -----------------------------------------------

/// Options for notification effects.
pub type NotificationOpt {
  /// Path to notification icon.
  NotifIcon(String)
  /// Auto-dismiss timeout in milliseconds.
  NotifTimeout(Int)
  /// Notification urgency level.
  Urgency(NotifUrgency)
  /// Sound theme name to play (e.g. "message-new-instant").
  Sound(String)
}

/// Urgency level for notifications.
pub type NotifUrgency {
  Low
  Normal
  Critical
}

// -- File dialogs ------------------------------------------------------------

/// Open a single file selection dialog.
pub fn file_open(tag: String, opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect(tag, "file_open", file_dialog_payload(opts))
}

/// Open a multiple file selection dialog.
pub fn file_open_multiple(
  tag: String,
  opts: List(FileDialogOpt),
) -> Command(msg) {
  make_effect(tag, "file_open_multiple", file_dialog_payload(opts))
}

/// Open a file save dialog.
pub fn file_save(tag: String, opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect(tag, "file_save", file_dialog_payload(opts))
}

/// Open a directory selection dialog.
pub fn directory_select(tag: String, opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect(tag, "directory_select", file_dialog_payload(opts))
}

/// Open a multiple directory selection dialog.
pub fn directory_select_multiple(
  tag: String,
  opts: List(FileDialogOpt),
) -> Command(msg) {
  make_effect(tag, "directory_select_multiple", file_dialog_payload(opts))
}

// -- Clipboard ---------------------------------------------------------------

/// Read text from the system clipboard.
pub fn clipboard_read(tag: String) -> Command(msg) {
  make_effect(tag, "clipboard_read", [])
}

/// Write text to the system clipboard.
pub fn clipboard_write(tag: String, text: String) -> Command(msg) {
  make_effect(tag, "clipboard_write", [#("text", StringVal(text))])
}

/// Read HTML from the system clipboard.
pub fn clipboard_read_html(tag: String) -> Command(msg) {
  make_effect(tag, "clipboard_read_html", [])
}

/// Write HTML to the system clipboard, with optional plain-text fallback.
pub fn clipboard_write_html(
  tag: String,
  html: String,
  alt: Option(String),
) -> Command(msg) {
  let payload = [#("html", StringVal(html))]
  let payload = case alt {
    Some(t) -> [#("alt_text", StringVal(t)), ..payload]
    None -> payload
  }
  make_effect(tag, "clipboard_write_html", payload)
}

/// Clear the system clipboard.
pub fn clipboard_clear(tag: String) -> Command(msg) {
  make_effect(tag, "clipboard_clear", [])
}

/// Read text from the primary selection (X11).
pub fn clipboard_read_primary(tag: String) -> Command(msg) {
  make_effect(tag, "clipboard_read_primary", [])
}

/// Write text to the primary selection (X11).
pub fn clipboard_write_primary(tag: String, text: String) -> Command(msg) {
  make_effect(tag, "clipboard_write_primary", [#("text", StringVal(text))])
}

// -- Notifications -----------------------------------------------------------

/// Show a desktop notification.
pub fn notification(
  tag: String,
  title: String,
  body: String,
  opts: List(NotificationOpt),
) -> Command(msg) {
  let payload = [
    #("title", StringVal(title)),
    #("body", StringVal(body)),
    ..notif_payload(opts)
  ]
  make_effect(tag, "notification", payload)
}

// -- Timeouts ----------------------------------------------------------------

/// Returns the default timeout in milliseconds for the given effect kind.
/// File dialogs get 120s (user interaction), clipboard and notification
/// ops get 5s. Unknown kinds fall back to 30s.
pub fn default_timeout(kind: String) -> Int {
  case
    string.starts_with(kind, "file_") || string.starts_with(kind, "directory_")
  {
    True -> 120_000
    False ->
      case string.starts_with(kind, "clipboard_") || kind == "notification" {
        True -> 5000
        False -> 30_000
      }
  }
}

// -- Internal helpers --------------------------------------------------------

fn make_effect(
  tag: String,
  kind: String,
  payload: List(#(String, PropValue)),
) -> Command(msg) {
  let id = platform.unique_id()
  command.Effect(id:, tag:, kind:, payload: dict.from_list(payload))
}

fn file_dialog_payload(opts: List(FileDialogOpt)) -> List(#(String, PropValue)) {
  list.fold(opts, [], fn(acc, opt) {
    case opt {
      DialogTitle(t) -> [#("title", StringVal(t)), ..acc]
      DefaultPath(p) -> [#("default_path", StringVal(p)), ..acc]
      Filters(filters) -> {
        let filter_list =
          list.map(filters, fn(f) { ListVal([StringVal(f.0), StringVal(f.1)]) })
        [#("filters", ListVal(filter_list)), ..acc]
      }
    }
  })
}

fn notif_payload(opts: List(NotificationOpt)) -> List(#(String, PropValue)) {
  list.fold(opts, [], fn(acc, opt) {
    case opt {
      NotifIcon(path) -> [#("icon", StringVal(path)), ..acc]
      NotifTimeout(ms) -> [#("timeout", IntVal(ms)), ..acc]
      Urgency(u) -> {
        let s = case u {
          Low -> "low"
          Normal -> "normal"
          Critical -> "critical"
        }
        [#("urgency", StringVal(s)), ..acc]
      }
      Sound(s) -> [#("sound", StringVal(s)), ..acc]
    }
  })
}
