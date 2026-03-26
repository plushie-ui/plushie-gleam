import gleam/dynamic
import gleam/option
import plushie
import plushie/protocol

pub fn default_start_opts_test() {
  let opts = plushie.default_start_opts()
  assert opts.binary_path == option.None
  assert opts.format == protocol.Msgpack
  assert opts.daemon == False
  assert opts.session == ""
}

pub fn custom_start_opts_test() {
  let opts =
    plushie.StartOpts(
      binary_path: option.Some("/usr/bin/plushie"),
      format: protocol.Json,
      daemon: True,
      session: "my-session",
      app_opts: dynamic.nil(),
      required_extensions: [],
      renderer_args: ["--headless"],
      transport: plushie.Spawn,
      dev: False,
      token: option.None,
    )
  assert opts.binary_path == option.Some("/usr/bin/plushie")
  assert opts.format == protocol.Json
  assert opts.daemon == True
  assert opts.session == "my-session"
}
