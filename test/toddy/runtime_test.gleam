import toddy/protocol
import toddy/runtime

pub fn default_opts_format_test() {
  let opts = runtime.default_opts()
  assert opts.format == protocol.Msgpack
}

pub fn default_opts_session_test() {
  let opts = runtime.default_opts()
  assert opts.session == ""
}

pub fn default_opts_daemon_test() {
  let opts = runtime.default_opts()
  assert opts.daemon == False
}

pub fn custom_opts_test() {
  let opts =
    runtime.RuntimeOpts(
      format: protocol.Json,
      session: "test-session",
      daemon: True,
    )
  assert opts.format == protocol.Json
  assert opts.session == "test-session"
  assert opts.daemon == True
}
