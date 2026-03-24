import gleeunit/should
import plushie/binary
import plushie/platform

pub fn find_returns_error_for_nonexistent_env_path_test() {
  // Set PLUSHIE_BINARY_PATH to a path that definitely does not exist.
  // This always returns EnvVarPointsToMissing regardless of whether
  // the binary is available in standard search paths.
  platform.set_env(
    "PLUSHIE_BINARY_PATH",
    "/tmp/nonexistent_plushie_binary_12345",
  )
  let result = binary.find()
  should.be_error(result)
  case result {
    Error(binary.EnvVarPointsToMissing(path:)) ->
      should.equal(path, "/tmp/nonexistent_plushie_binary_12345")
    _ -> should.fail()
  }
  platform.unset_env("PLUSHIE_BINARY_PATH")
}

pub fn find_with_env_var_pointing_to_real_file_test() {
  // /bin/sh exists on any POSIX system
  platform.set_env("PLUSHIE_BINARY_PATH", "/bin/sh")
  let result = binary.find()
  should.equal(result, Ok("/bin/sh"))
  platform.unset_env("PLUSHIE_BINARY_PATH")
}
