import gleeunit/should
import plushie/platform
import plushie/testing/timeout

const env_name = "PLUSHIE_TEST_TIMEOUT"

pub fn scale_uses_base_when_env_unset_test() {
  with_timeout_unset(fn() {
    timeout.scale(500)
    |> should.equal(500)
  })
}

pub fn scale_multiplies_base_when_env_is_positive_integer_test() {
  with_timeout("3", fn() {
    timeout.scale(500)
    |> should.equal(1500)
  })
}

pub fn scale_uses_base_when_env_is_invalid_test() {
  with_timeout("slow", fn() {
    timeout.scale(500)
    |> should.equal(500)
  })
}

pub fn scale_uses_base_when_env_is_non_positive_test() {
  with_timeout("0", fn() {
    timeout.scale(500)
    |> should.equal(500)
  })

  with_timeout("-2", fn() {
    timeout.scale(500)
    |> should.equal(500)
  })
}

fn with_timeout(value: String, f: fn() -> a) -> a {
  let saved = platform.get_env(env_name)
  platform.set_env(env_name, value)
  let result = f()
  restore_timeout(saved)
  result
}

fn with_timeout_unset(f: fn() -> a) -> a {
  let saved = platform.get_env(env_name)
  platform.unset_env(env_name)
  let result = f()
  restore_timeout(saved)
  result
}

fn restore_timeout(saved: Result(String, Nil)) -> Nil {
  case saved {
    Ok(value) -> platform.set_env(env_name, value)
    Error(_) -> platform.unset_env(env_name)
  }
}
