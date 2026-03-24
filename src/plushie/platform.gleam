//// Cross-target platform utilities.
////
//// Provides functions that need different implementations on BEAM vs
//// JavaScript but are used by modules that should compile on both
//// targets. Each function has dual `@external` annotations.
////
//// On BEAM, these delegate to `plushie_ffi.erl` or the Erlang
//// standard library. On JavaScript, they delegate to
//// `plushie_platform_ffi.mjs` which uses Node.js APIs where
//// available and degrades gracefully in browser contexts.
////
//// BEAM-only operations (Erlang ports, OTP process management)
//// live in `plushie/ffi.gleam` instead.

import gleam/dynamic.{type Dynamic}

// -- Logging ------------------------------------------------------------------

/// Log at info level.
///
/// BEAM: Erlang `logger:info/1`. JS: `console.info`.
@external(erlang, "plushie_ffi", "log_info")
@external(javascript, "../plushie_platform_ffi.mjs", "logInfo")
pub fn log_info(message: String) -> Nil

/// Log at warning level.
///
/// BEAM: Erlang `logger:warning/1`. JS: `console.warn`.
@external(erlang, "plushie_ffi", "log_warning")
@external(javascript, "../plushie_platform_ffi.mjs", "logWarning")
pub fn log_warning(message: String) -> Nil

/// Log at error level.
///
/// BEAM: Erlang `logger:error/1`. JS: `console.error`.
@external(erlang, "plushie_ffi", "log_error")
@external(javascript, "../plushie_platform_ffi.mjs", "logError")
pub fn log_error(message: String) -> Nil

// -- Identity and time --------------------------------------------------------

/// Generate a unique ID string.
///
/// BEAM: `erlang:unique_integer([monotonic, positive])` converted
/// to string -- globally unique within the node lifetime.
/// JS: timestamp-prefixed monotonic counter -- unique within a
/// single page/process lifetime.
@external(erlang, "plushie_ffi", "unique_id")
@external(javascript, "../plushie_platform_ffi.mjs", "uniqueId")
pub fn unique_id() -> String

/// Return the current monotonic time in milliseconds.
///
/// BEAM: `erlang:monotonic_time(millisecond)`.
/// JS: `Math.floor(performance.now())`.
///
/// Both are monotonically increasing and start from an arbitrary
/// origin. Suitable for measuring elapsed time and coalesce windows,
/// not for wall-clock timestamps.
@external(erlang, "plushie_ffi", "monotonic_time_ms")
@external(javascript, "../plushie_platform_ffi.mjs", "monotonicTimeMs")
pub fn monotonic_time_ms() -> Int

// -- Error handling -----------------------------------------------------------

/// Call a function with error handling.
///
/// Catches panics and exceptions, returning `Ok(value)` on success
/// or `Error(reason)` on failure. Used by the runtime to protect
/// against crashes in user-provided `update` and `view` functions.
///
/// BEAM: Erlang `:try/:catch`. JS: try/catch.
@external(erlang, "plushie_ffi", "try_call")
@external(javascript, "../plushie_platform_ffi.mjs", "tryCall")
pub fn try_call(f: fn() -> a) -> Result(a, Dynamic)

/// Return a stable string key for a value, for deduplication.
///
/// Used by the runtime to deduplicate `SendAfter` timers for the
/// same message value. Not a cryptographic hash. Accepts any type
/// since both BEAM and JS implementations handle arbitrary values.
///
/// BEAM: `erlang:phash2/1` (32-bit hash). JS: `JSON.stringify`.
@external(erlang, "plushie_ffi", "stable_hash_key")
@external(javascript, "../plushie_platform_ffi.mjs", "stableHashKey")
pub fn stable_hash_key(value: a) -> String

// -- Math ---------------------------------------------------------------------

/// Sine function.
@external(erlang, "math", "sin")
@external(javascript, "../plushie_platform_ffi.mjs", "mathSin")
pub fn math_sin(x: Float) -> Float

/// Power function.
@external(erlang, "math", "pow")
@external(javascript, "../plushie_platform_ffi.mjs", "mathPow")
pub fn math_pow(base: Float, exponent: Float) -> Float

// -- Environment and filesystem -----------------------------------------------
// These functions degrade gracefully in browser contexts:
// get_env returns Error, set_env/unset_env are no-ops, file_exists
// returns False, platform/arch return "unknown".

/// Get an environment variable.
///
/// BEAM: `os:getenv/1`. JS: `process.env[name]` (Node.js) or
/// `Error(Nil)` in browser.
@external(erlang, "plushie_ffi", "get_env")
@external(javascript, "../plushie_platform_ffi.mjs", "getEnv")
pub fn get_env(name: String) -> Result(String, Nil)

/// Set an environment variable.
///
/// BEAM: `os:putenv/2`. JS: `process.env[name] = value` (Node.js)
/// or no-op in browser.
@external(erlang, "plushie_ffi", "set_env")
@external(javascript, "../plushie_platform_ffi.mjs", "setEnv")
pub fn set_env(name: String, value: String) -> Nil

/// Unset an environment variable.
///
/// BEAM: `os:unsetenv/1`. JS: `delete process.env[name]` (Node.js)
/// or no-op in browser.
@external(erlang, "plushie_ffi", "unset_env")
@external(javascript, "../plushie_platform_ffi.mjs", "unsetEnv")
pub fn unset_env(name: String) -> Nil

/// Check whether a file exists at the given path.
///
/// BEAM: `filelib:is_regular/1`. JS: `fs.existsSync` (Node.js)
/// or `False` in browser.
@external(erlang, "plushie_ffi", "file_exists")
@external(javascript, "../plushie_platform_ffi.mjs", "fileExists")
pub fn file_exists(path: String) -> Bool

/// Return the platform as a string.
///
/// Returns one of: `"linux"`, `"darwin"`, `"windows"`, `"unknown"`.
/// BEAM: `:os.type/0`. JS: `process.platform` (Node.js) or
/// `"unknown"` in browser.
@external(erlang, "plushie_ffi", "platform_string")
@external(javascript, "../plushie_platform_ffi.mjs", "platformString")
pub fn platform_string() -> String

/// Return the CPU architecture as a string.
///
/// Returns one of: `"x86_64"`, `"aarch64"`, or the raw platform
/// value. BEAM: `erlang:system_info(system_architecture)`.
/// JS: `process.arch` (Node.js) or `"unknown"` in browser.
@external(erlang, "plushie_ffi", "arch_string")
@external(javascript, "../plushie_platform_ffi.mjs", "archString")
pub fn arch_string() -> String

// -- Hashing and compression --------------------------------------------------
// Used by testing infrastructure (snapshots, screenshots, tree
// hashes). JS implementations require Node.js crypto/zlib modules
// and will throw in browser contexts.

/// Compute SHA-256 hash and return as lowercase hex string.
///
/// BEAM: `crypto:hash/2`. JS: Node.js `crypto.createHash`.
/// Not available in browser -- will throw.
@external(erlang, "plushie_ffi", "sha256_hex")
@external(javascript, "../plushie_platform_ffi.mjs", "sha256Hex")
pub fn sha256_hex(data: BitArray) -> String

/// CRC32 checksum of binary data.
///
/// BEAM: `erlang:crc32/1`. JS: pure lookup-table implementation.
@external(erlang, "plushie_ffi", "crc32")
@external(javascript, "../plushie_platform_ffi.mjs", "crc32")
pub fn crc32(data: BitArray) -> Int

/// Zlib-compress binary data (deflate).
///
/// BEAM: `zlib:compress/1`. JS: Node.js `zlib.deflateSync`.
/// Not available in browser -- will throw.
@external(erlang, "plushie_ffi", "zlib_compress")
@external(javascript, "../plushie_platform_ffi.mjs", "zlibCompress")
pub fn zlib_compress(data: BitArray) -> BitArray
