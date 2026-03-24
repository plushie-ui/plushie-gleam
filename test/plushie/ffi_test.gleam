import gleeunit/should
import plushie/platform

pub fn unique_id_generates_different_ids_test() {
  let id1 = platform.unique_id()
  let id2 = platform.unique_id()
  should.not_equal(id1, id2)
}

pub fn try_call_succeeds_test() {
  let result = platform.try_call(fn() { 42 })
  should.equal(result, Ok(42))
}

pub fn try_call_catches_panic_test() {
  let result = platform.try_call(fn() { panic as "boom" })
  should.be_error(result)
}

pub fn file_exists_returns_false_for_missing_file_test() {
  platform.file_exists("/tmp/nonexistent_plushie_file_99999")
  |> should.equal(False)
}

pub fn platform_string_returns_known_value_test() {
  let platform = platform.platform_string()
  let is_known =
    platform == "linux"
    || platform == "darwin"
    || platform == "windows"
    || platform == "unknown"
  should.equal(is_known, True)
}

pub fn arch_string_returns_nonempty_test() {
  let arch = platform.arch_string()
  should.not_equal(arch, "")
}

pub fn get_env_returns_error_for_unset_var_test() {
  platform.unset_env("PLUSHIE_TEST_NONEXISTENT_VAR_12345")
  platform.get_env("PLUSHIE_TEST_NONEXISTENT_VAR_12345")
  |> should.be_error
}

pub fn set_and_get_env_round_trips_test() {
  platform.set_env("PLUSHIE_TEST_FFI_VAR", "hello")
  platform.get_env("PLUSHIE_TEST_FFI_VAR")
  |> should.equal(Ok("hello"))
  platform.unset_env("PLUSHIE_TEST_FFI_VAR")
}
