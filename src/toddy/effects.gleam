//// Platform effects: file dialogs, clipboard, notifications.
////
//// Each function returns a `Command(msg)` that the runtime sends
//// to the bridge as an effect request. Results arrive as
//// `EffectResponse` events with a correlated `request_id`.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import toddy/command.{type Command}
import toddy/ffi
import toddy/node.{type PropValue, IntVal, ListVal, StringVal}

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
pub fn file_open(opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect("file_open", file_dialog_payload(opts))
}

/// Open a multiple file selection dialog.
pub fn file_open_multiple(opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect("file_open_multiple", file_dialog_payload(opts))
}

/// Open a file save dialog.
pub fn file_save(opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect("file_save", file_dialog_payload(opts))
}

/// Open a directory selection dialog.
pub fn directory_select(opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect("directory_select", file_dialog_payload(opts))
}

/// Open a multiple directory selection dialog.
pub fn directory_select_multiple(opts: List(FileDialogOpt)) -> Command(msg) {
  make_effect("directory_select_multiple", file_dialog_payload(opts))
}

// -- Clipboard ---------------------------------------------------------------

/// Read text from the system clipboard.
pub fn clipboard_read() -> Command(msg) {
  make_effect("clipboard_read", [])
}

/// Write text to the system clipboard.
pub fn clipboard_write(text: String) -> Command(msg) {
  make_effect("clipboard_write", [#("text", StringVal(text))])
}

/// Read HTML from the system clipboard.
pub fn clipboard_read_html() -> Command(msg) {
  make_effect("clipboard_read_html", [])
}

/// Write HTML to the system clipboard, with optional plain-text fallback.
pub fn clipboard_write_html(html: String, alt: Option(String)) -> Command(msg) {
  let payload = [#("html", StringVal(html))]
  let payload = case alt {
    Some(t) -> [#("alt_text", StringVal(t)), ..payload]
    None -> payload
  }
  make_effect("clipboard_write_html", payload)
}

/// Clear the system clipboard.
pub fn clipboard_clear() -> Command(msg) {
  make_effect("clipboard_clear", [])
}

/// Read text from the primary selection (X11).
pub fn clipboard_read_primary() -> Command(msg) {
  make_effect("clipboard_read_primary", [])
}

/// Write text to the primary selection (X11).
pub fn clipboard_write_primary(text: String) -> Command(msg) {
  make_effect("clipboard_write_primary", [#("text", StringVal(text))])
}

// -- Notifications -----------------------------------------------------------

/// Show a desktop notification.
pub fn notification(
  title: String,
  body: String,
  opts: List(NotificationOpt),
) -> Command(msg) {
  let payload = [
    #("title", StringVal(title)),
    #("body", StringVal(body)),
    ..notif_payload(opts)
  ]
  make_effect("notification", payload)
}

// -- Timeouts ----------------------------------------------------------------

/// Returns the default timeout in milliseconds for the given effect kind.
/// File dialogs get 120s (user interaction), clipboard and notification
/// ops get 5s. Unknown kinds fall back to 30s.
pub fn default_timeout(kind: String) -> Int {
  case string.starts_with(kind, "file_") || string.starts_with(kind, "directory_") {
    True -> 120_000
    False ->
      case
        string.starts_with(kind, "clipboard_") || kind == "notification"
      {
        True -> 5_000
        False -> 30_000
      }
  }
}

// -- Internal helpers --------------------------------------------------------

fn make_effect(
  kind: String,
  payload: List(#(String, PropValue)),
) -> Command(msg) {
  let id = ffi.unique_id()
  command.Effect(id:, kind:, payload: dict.from_list(payload))
}

fn file_dialog_payload(opts: List(FileDialogOpt)) -> List(#(String, PropValue)) {
  list.fold(opts, [], fn(acc, opt) {
    case opt {
      DialogTitle(t) -> [#("title", StringVal(t)), ..acc]
      DefaultPath(p) -> [#("default_path", StringVal(p)), ..acc]
      Filters(filters) -> {
        let filter_list =
          list.map(filters, fn(f) {
            ListVal([StringVal(f.0), StringVal(f.1)])
          })
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
