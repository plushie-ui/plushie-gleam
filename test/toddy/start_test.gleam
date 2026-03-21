import gleam/dynamic
import gleam/option
import toddy
import toddy/protocol

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
      app_opts: dynamic.nil(),
      renderer_args: ["--headless"],
      transport: toddy.Spawn,
      dev: False,
    )
  assert opts.binary_path == option.Some("/usr/bin/toddy")
  assert opts.format == protocol.Json
  assert opts.daemon == True
  assert opts.session == "my-session"
}
