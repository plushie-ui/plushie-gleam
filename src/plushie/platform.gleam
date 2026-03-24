//// Cross-target platform utilities.
////
//// Functions that need different implementations on BEAM vs JavaScript
//// but are used by modules that are otherwise pure Gleam. Each function
//// has dual @external annotations so both targets compile.

import gleam/dynamic.{type Dynamic}

/// Log at info level.
@external(erlang, "plushie_ffi", "log_info")
@external(javascript, "../plushie_platform_ffi.mjs", "logInfo")
pub fn log_info(message: String) -> Nil

/// Log at warning level.
@external(erlang, "plushie_ffi", "log_warning")
@external(javascript, "../plushie_platform_ffi.mjs", "logWarning")
pub fn log_warning(message: String) -> Nil

/// Log at error level.
@external(erlang, "plushie_ffi", "log_error")
@external(javascript, "../plushie_platform_ffi.mjs", "logError")
pub fn log_error(message: String) -> Nil

/// Generate a unique monotonic ID string.
@external(erlang, "plushie_ffi", "unique_id")
@external(javascript, "../plushie_platform_ffi.mjs", "uniqueId")
pub fn unique_id() -> String

/// Return the current monotonic time in milliseconds.
@external(erlang, "plushie_ffi", "monotonic_time_ms")
@external(javascript, "../plushie_platform_ffi.mjs", "monotonicTimeMs")
pub fn monotonic_time_ms() -> Int

/// Call a function with error handling.
/// Catches panics/exceptions, returning Result.
@external(erlang, "plushie_ffi", "try_call")
@external(javascript, "../plushie_platform_ffi.mjs", "tryCall")
pub fn try_call(f: fn() -> a) -> Result(a, Dynamic)

/// Return a stable hash key for any value as a string.
@external(erlang, "plushie_ffi", "stable_hash_key")
@external(javascript, "../plushie_platform_ffi.mjs", "stableHashKey")
pub fn stable_hash_key(value: Dynamic) -> String

/// Sine function.
@external(erlang, "math", "sin")
@external(javascript, "../plushie_platform_ffi.mjs", "mathSin")
pub fn math_sin(x: Float) -> Float

/// Power function.
@external(erlang, "math", "pow")
@external(javascript, "../plushie_platform_ffi.mjs", "mathPow")
pub fn math_pow(base: Float, exponent: Float) -> Float
