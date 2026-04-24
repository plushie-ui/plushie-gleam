//// Shared timeout scaling for renderer-backed test infrastructure.

import gleam/int
import plushie/platform

const env_name = "PLUSHIE_TEST_TIMEOUT"

/// Scale a test infrastructure timeout by `PLUSHIE_TEST_TIMEOUT`.
///
/// The variable is an integer multiplier. Unset, invalid, and
/// non-positive values use a multiplier of 1.
pub fn scale(base_ms: Int) -> Int {
  base_ms * multiplier()
}

fn multiplier() -> Int {
  case platform.get_env(env_name) {
    Ok(value) ->
      case int.parse(value) {
        Ok(n) if n > 0 -> n
        _ -> 1
      }
    Error(_) -> 1
  }
}
