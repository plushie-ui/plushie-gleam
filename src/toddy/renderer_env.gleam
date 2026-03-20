//// Build a safe environment for the renderer Port child process.
////
//// Erlang ports inherit the parent process environment by default,
//// which can leak sensitive variables. This module builds a whitelist
//// of display, rendering, and system variables.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Options for building the renderer environment.
pub type EnvOpts {
  EnvOpts(
    /// Override RUST_LOG level (default: "error").
    rust_log: Option(String),
    /// Extra environment variables to include.
    extra: Dict(String, String),
  )
}

/// Default environment options.
pub fn default_opts() -> EnvOpts {
  EnvOpts(rust_log: None, extra: dict.new())
}

/// Whitelisted environment variable prefixes.
/// Variables matching these prefixes are included in the child env.
const allowed_prefixes = [
  // Display
  "DISPLAY", "WAYLAND_",
  // GPU/Rendering
  "WGPU_", "MESA_", "LIBGL_", "VK_", "GALLIUM_", "DRI_",
  // System
  "PATH", "LD_LIBRARY_PATH", "HOME", "USER", "SHELL",
  // Locale
  "LANG", "LC_", "LANGUAGE",
  // Accessibility
  "DBUS_", "AT_SPI_",
  // Fonts
  "FONTCONFIG_",
  // XDG
  "XDG_",
]

/// Build an environment variable list for the renderer port.
///
/// Returns a list of (key, value) pairs suitable for passing to
/// the port spawn options.
pub fn build(opts: EnvOpts) -> List(#(String, String)) {
  let env = get_system_env()

  // Filter to allowed prefixes
  let filtered =
    dict.filter(env, fn(key, _val) {
      list.any(allowed_prefixes, fn(prefix) { string.starts_with(key, prefix) })
    })

  // Add RUST_LOG
  let filtered = case opts.rust_log {
    Some(level) -> dict.insert(filtered, "RUST_LOG", level)
    None -> dict.insert(filtered, "RUST_LOG", "error")
  }

  // Add RUST_BACKTRACE if not present
  let filtered = case dict.has_key(filtered, "RUST_BACKTRACE") {
    True -> filtered
    False -> dict.insert(filtered, "RUST_BACKTRACE", "1")
  }

  // Merge extra vars
  let filtered = dict.merge(filtered, opts.extra)

  dict.to_list(filtered)
}

@external(erlang, "toddy_renderer_env_ffi", "get_env")
fn get_system_env() -> Dict(String, String)
