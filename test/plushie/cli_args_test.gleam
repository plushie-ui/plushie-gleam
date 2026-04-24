import gleeunit/should

pub fn get_flag_value_accepts_split_value_test() {
  get_flag_value("--bin-file", ["--bin-file", "renderer"])
  |> should.equal(Ok("renderer"))
}

pub fn get_flag_value_accepts_equals_value_test() {
  get_flag_value("--bin-file", ["--bin-file=renderer"])
  |> should.equal(Ok("renderer"))
}

pub fn get_flag_value_rejects_next_flag_as_value_test() {
  get_flag_value("--bin-file", ["--bin-file", "--wasm-dir", "pkg"])
  |> should.be_error
}

pub fn get_flag_value_stops_at_separator_test() {
  get_flag_value("--bin-file", ["--", "--bin-file", "renderer"])
  |> should.be_error
}

pub fn has_flag_matches_before_separator_test() {
  has_flag("--release", ["--release", "--", "--verbose"])
  |> should.equal(True)
}

pub fn has_flag_stops_at_separator_test() {
  has_flag("--verbose", ["--release", "--", "--verbose"])
  |> should.equal(False)
}

@external(erlang, "plushie_cli_args_ffi", "has_flag")
fn has_flag(flag: String, args: List(String)) -> Bool

@external(erlang, "plushie_cli_args_ffi", "get_flag_value")
fn get_flag_value(flag: String, args: List(String)) -> Result(String, Nil)
