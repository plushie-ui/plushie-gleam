//// App type definition and constructors.
////
//// An App bundles the init/update/view functions that define application
//// behavior. Use `simple` for most apps or `application` when you need
//// a custom message type.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import plushie/command.{type Command}
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue}
import plushie/prop/theme.{type Theme}
import plushie/subscription.{type Subscription}

/// App-level settings sent to the Rust binary on startup.
pub type Settings {
  Settings(
    /// Enable anti-aliasing for rendered content. Default: True.
    antialiasing: Bool,
    /// Base text size in logical pixels. Default: 16.0.
    default_text_size: Float,
    /// Override the application theme. None uses the system theme.
    theme: Option(Theme),
    /// Paths to custom font files to load at startup.
    fonts: List(String),
    /// Enable vertical sync. Default: True.
    vsync: Bool,
    /// Global UI scale factor (1.0 = 100%). Default: 1.0.
    scale_factor: Float,
    /// Override the default font family. None uses the built-in default.
    default_font: Option(PropValue),
    /// Maximum events per second for coalescable event sources
    /// (mouse moves, sensor resizes, etc.). None uses the renderer's
    /// built-in default. A value of 0 subscribes but never emits.
    default_event_rate: Option(Int),
  )
}

/// Default settings.
pub fn default_settings() -> Settings {
  Settings(
    antialiasing: True,
    default_text_size: 16.0,
    theme: option.None,
    fonts: [],
    vsync: True,
    scale_factor: 1.0,
    default_font: option.None,
    default_event_rate: option.None,
  )
}

/// Application definition bundling all callbacks.
pub opaque type App(model, msg) {
  App(
    init: fn(Dynamic) -> #(model, Command(msg)),
    update: fn(model, msg) -> #(model, Command(msg)),
    view: fn(model) -> Node,
    subscribe: fn(model) -> List(Subscription),
    settings: fn() -> Settings,
    window_config: fn(model) -> Dict(String, PropValue),
    on_renderer_exit: Option(fn(model, Dynamic) -> model),
    on_event: Option(fn(Event) -> msg),
  )
}

/// Create a simple app where msg = Event.
/// This covers the common case where update receives plushie Events directly.
/// The init function ignores the Dynamic app_opts argument. Use
/// `simple_with_opts` if you need to receive app_opts.
pub fn simple(
  init: fn() -> #(model, Command(Event)),
  update: fn(model, Event) -> #(model, Command(Event)),
  view: fn(model) -> Node,
) -> App(model, Event) {
  App(
    init: fn(_opts) { init() },
    update:,
    view:,
    subscribe: fn(_) { [] },
    settings: default_settings,
    window_config: fn(_) { dict.new() },
    on_renderer_exit: option.None,
    on_event: option.None,
  )
}

/// Create a simple app with app_opts passed to init.
pub fn simple_with_opts(
  init: fn(Dynamic) -> #(model, Command(Event)),
  update: fn(model, Event) -> #(model, Command(Event)),
  view: fn(model) -> Node,
) -> App(model, Event) {
  App(
    init:,
    update:,
    view:,
    subscribe: fn(_) { [] },
    settings: default_settings,
    window_config: fn(_) { dict.new() },
    on_renderer_exit: option.None,
    on_event: option.None,
  )
}

/// Create an app with a custom message type.
/// The `on_event` function maps wire Events to the app's msg type.
pub fn application(
  init: fn() -> #(model, Command(msg)),
  update: fn(model, msg) -> #(model, Command(msg)),
  view: fn(model) -> Node,
  on_event: fn(Event) -> msg,
) -> App(model, msg) {
  App(
    init: fn(_opts) { init() },
    update:,
    view:,
    subscribe: fn(_) { [] },
    settings: default_settings,
    window_config: fn(_) { dict.new() },
    on_renderer_exit: option.None,
    on_event: option.Some(on_event),
  )
}

/// Create an app with a custom message type and app_opts passed to init.
pub fn application_with_opts(
  init: fn(Dynamic) -> #(model, Command(msg)),
  update: fn(model, msg) -> #(model, Command(msg)),
  view: fn(model) -> Node,
  on_event: fn(Event) -> msg,
) -> App(model, msg) {
  App(
    init:,
    update:,
    view:,
    subscribe: fn(_) { [] },
    settings: default_settings,
    window_config: fn(_) { dict.new() },
    on_renderer_exit: option.None,
    on_event: option.Some(on_event),
  )
}

/// Set the subscribe callback (returns subscriptions based on model).
pub fn with_subscriptions(
  app: App(model, msg),
  subscribe: fn(model) -> List(Subscription),
) -> App(model, msg) {
  App(..app, subscribe:)
}

/// Set the settings callback.
pub fn with_settings(
  app: App(model, msg),
  settings: fn() -> Settings,
) -> App(model, msg) {
  App(..app, settings:)
}

/// Set the window_config callback (per-window default settings).
pub fn with_window_config(
  app: App(model, msg),
  window_config: fn(model) -> Dict(String, PropValue),
) -> App(model, msg) {
  App(..app, window_config:)
}

/// Set the renderer exit handler.
pub fn with_on_renderer_exit(
  app: App(model, msg),
  handler: fn(model, Dynamic) -> model,
) -> App(model, msg) {
  App(..app, on_renderer_exit: option.Some(handler))
}

// --- Accessor functions (for the runtime to call) ---

/// Returns the app's init function, called once at startup with app_opts.
pub fn get_init(app: App(model, msg)) -> fn(Dynamic) -> #(model, Command(msg)) {
  app.init
}

/// Returns the app's update function, called on every event with the
/// current model and message.
pub fn get_update(
  app: App(model, msg),
) -> fn(model, msg) -> #(model, Command(msg)) {
  app.update
}

/// Returns the app's view function, called after every update to produce
/// the UI tree.
pub fn get_view(app: App(model, msg)) -> fn(model) -> Node {
  app.view
}

/// Returns the app's subscribe function. The runtime calls this after
/// every update and diffs the result to manage subscription lifecycle.
pub fn get_subscribe(app: App(model, msg)) -> fn(model) -> List(Subscription) {
  app.subscribe
}

/// Returns the app's settings function, called once at startup to
/// configure the renderer (theme, fonts, antialiasing, etc.).
pub fn get_settings(app: App(model, msg)) -> fn() -> Settings {
  app.settings
}

/// Returns the app's window config function, called at startup and on
/// renderer restart to provide default window properties.
pub fn get_window_config(
  app: App(model, msg),
) -> fn(model) -> Dict(String, PropValue) {
  app.window_config
}

/// Returns the optional renderer exit handler. Called when the renderer
/// process exits unexpectedly, allowing the app to adjust the model
/// before the renderer restarts.
pub fn get_on_renderer_exit(
  app: App(model, msg),
) -> Option(fn(model, Dynamic) -> model) {
  app.on_renderer_exit
}

/// Returns the optional event mapper. When set (via `application`),
/// the runtime passes wire Events through this function to produce
/// the app's custom msg type before calling update.
pub fn get_on_event(app: App(model, msg)) -> Option(fn(Event) -> msg) {
  app.on_event
}
