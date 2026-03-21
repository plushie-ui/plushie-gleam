import gleeunit/should
import toddy/binary
import toddy/ffi

pub fn find_returns_error_for_nonexistent_env_path_test() {
  // Set TODDY_BINARY_PATH to a path that definitely does not exist.
  // This always returns EnvVarPointsToMissing regardless of whether
  // the binary is available in standard search paths.
  ffi.set_env("TODDY_BINARY_PATH", "/tmp/nonexistent_toddy_binary_12345")
  let result = binary.find()
  should.be_error(result)
  case result {
    Error(binary.EnvVarPointsToMissing(path:)) ->
      should.equal(path, "/tmp/nonexistent_toddy_binary_12345")
    _ -> should.fail()
  }
  ffi.unset_env("TODDY_BINARY_PATH")
}

pub fn find_with_env_var_pointing_to_real_file_test() {
  // /bin/sh exists on any POSIX system
  ffi.set_env("TODDY_BINARY_PATH", "/bin/sh")
  let result = binary.find()
  should.equal(result, Ok("/bin/sh"))
  ffi.unset_env("TODDY_BINARY_PATH")
}
