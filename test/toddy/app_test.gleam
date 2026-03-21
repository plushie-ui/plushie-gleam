import gleam/dict
import gleam/dynamic
import gleam/option
import gleeunit/should
import toddy/app
import toddy/command
import toddy/event.{type Event, WidgetClick}
import toddy/node
import toddy/subscription

type Model {
  Model(count: Int)
}

fn test_init() {
  #(Model(count: 0), command.none())
}

fn test_update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "inc", ..) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn test_view(_model: Model) {
  node.new("root", "container")
}

pub fn simple_creates_app_test() {
  let my_app = app.simple(test_init, test_update, test_view)
  // Can call init through accessor
  let #(model, _cmd) = app.get_init(my_app)(dynamic.nil())
  should.equal(model.count, 0)
}

pub fn simple_has_no_on_event_test() {
  let my_app = app.simple(test_init, test_update, test_view)
  should.equal(app.get_on_event(my_app), option.None)
}

pub fn simple_has_empty_subscriptions_test() {
  let my_app = app.simple(test_init, test_update, test_view)
  let subs = app.get_subscribe(my_app)(Model(0))
  should.equal(subs, [])
}

pub fn with_subscriptions_test() {
  let my_app =
    app.simple(test_init, test_update, test_view)
    |> app.with_subscriptions(fn(_model) { [subscription.every(1000, "tick")] })
  let subs = app.get_subscribe(my_app)(Model(0))
  should.equal(subs, [subscription.Every(interval_ms: 1000, tag: "tick")])
}

pub fn default_settings_test() {
  let s = app.default_settings()
  should.equal(s.antialiasing, True)
  should.equal(s.default_text_size, 16.0)
  should.equal(s.theme, option.None)
  should.equal(s.fonts, [])
  should.equal(s.vsync, True)
  should.equal(s.scale_factor, 1.0)
  should.equal(s.default_font, option.None)
  should.equal(s.default_event_rate, option.None)
}

pub fn init_receives_app_opts_test() {
  let my_app =
    app.simple_with_opts(
      fn(opts) {
        // Dynamic opts are passed through
        let _ = opts
        #(Model(count: 42), command.none())
      },
      test_update,
      test_view,
    )
  let #(model, _cmd) = app.get_init(my_app)(dynamic.nil())
  should.equal(model.count, 42)
}

pub fn update_through_accessor_test() {
  let my_app = app.simple(test_init, test_update, test_view)
  let update = app.get_update(my_app)
  let #(model, _cmd) =
    update(Model(count: 5), WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 6)
}

pub fn view_through_accessor_test() {
  let my_app = app.simple(test_init, test_update, test_view)
  let view = app.get_view(my_app)
  let tree = view(Model(count: 0))
  should.equal(tree.id, "root")
}

pub fn window_config_default_empty_test() {
  let my_app = app.simple(test_init, test_update, test_view)
  let config = app.get_window_config(my_app)(Model(0))
  should.equal(dict.size(config), 0)
}

// --- application() tests ---

type Msg {
  TodoEvent(event.Event)
}

fn msg_init() {
  #(Model(count: 0), command.none())
}

fn msg_update(model: Model, msg: Msg) {
  case msg {
    TodoEvent(WidgetClick(id: "inc", ..)) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn msg_view(_model: Model) {
  node.new("root", "container")
}

pub fn application_stores_on_event_test() {
  let my_app =
    app.application(msg_init, msg_update, msg_view, fn(e) { TodoEvent(e) })
  should.be_true(option.is_some(app.get_on_event(my_app)))
}

pub fn application_init_works_test() {
  let my_app =
    app.application(msg_init, msg_update, msg_view, fn(e) { TodoEvent(e) })
  let #(model, _cmd) = app.get_init(my_app)(dynamic.nil())
  should.equal(model.count, 0)
}

pub fn application_update_with_mapped_event_test() {
  let my_app =
    app.application(msg_init, msg_update, msg_view, fn(e) { TodoEvent(e) })
  let on_event = case app.get_on_event(my_app) {
    option.Some(f) -> f
    option.None -> panic as "expected on_event"
  }
  let mapped = on_event(WidgetClick(id: "inc", scope: []))
  let update = app.get_update(my_app)
  let #(model, _cmd) = update(Model(count: 0), mapped)
  should.equal(model.count, 1)
}
