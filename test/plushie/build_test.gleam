import gleam/string
import gleeunit/should
import plushie/build

pub fn missing_binary_message_points_to_cargo_output_when_verbose_test() {
  let msg = build.missing_binary_message("/tmp/app-renderer", True)

  should.be_true(string.contains(
    msg,
    "Build succeeded but binary not found at /tmp/app-renderer",
  ))
  should.be_true(string.contains(
    msg,
    "Check the cargo-plushie output above for compilation issues.",
  ))
}

pub fn missing_binary_message_tells_quiet_runs_how_to_show_output_test() {
  let msg = build.missing_binary_message("/tmp/app-renderer", False)

  should.be_true(string.contains(msg, "Rerun the build with `--verbose`"))
  should.be_true(string.contains(msg, "gleam run -m plushie/build -- --verbose"))
  should.be_true(string.contains(
    msg,
    "check the cargo-plushie output for compilation issues.",
  ))
}
