import gleam/option
import toddy
import toddy/app
import toddy/command
import toddy/event.{type Event}
import toddy/node
import toddy/protocol

type Model {
  Model(count: Int)
}

pub fn default_start_opts_test() {
  let opts = toddy.default_start_opts()
  assert opts.binary_path == option.None
  assert opts.format == protocol.Msgpack
  assert opts.daemon == False
  assert opts.session == ""
}

pub fn custom_start_opts_test() {
  let opts =
    toddy.StartOpts(
      binary_path: option.Some("/usr/bin/toddy"),
      format: protocol.Json,
      daemon: True,
      session: "my-session",
    )
  assert opts.binary_path == option.Some("/usr/bin/toddy")
  assert opts.format == protocol.Json
  assert opts.daemon == True
  assert opts.session == "my-session"
}

pub fn start_error_binary_not_found_test() {
  let my_app =
    app.simple(
      fn() { #(Model(0), command.none()) },
      fn(model: Model, _event: Event) { #(model, command.none()) },
      fn(_model: Model) { node.new("root", "container") },
    )
  let opts = toddy.default_start_opts()
  case toddy.start(my_app, opts) {
    Error(toddy.BinaryNotFound(_)) -> Nil
    Error(toddy.RuntimeStartFailed(_)) -> Nil
    Ok(_) -> Nil
  }
}
