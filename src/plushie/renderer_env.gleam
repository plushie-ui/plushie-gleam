//// Build a safe environment for the renderer Port child process.
////
//// Erlang ports inherit the parent process environment by default,
//// which can leak sensitive variables. This module builds a whitelist
//// of display, rendering, and system variables and actively unsets
//// everything else via `{Name, false}` in the port `:env` option.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

@target(erlang)
/// An environment variable entry: either set to a value or explicitly unset.
pub type EnvEntry {
  Set(key: String, value: String)
  Unset(key: String)
}

@target(erlang)
/// Options for building the renderer environment.
pub type EnvOpts {
  EnvOpts(
    /// Override RUST_LOG level (default: "error").
    rust_log: Option(String),
    /// Extra environment variables to include.
    extra: Dict(String, String),
  )
}

@target(erlang)
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

fn is_allowed(key: String) -> Bool {
  list.any(allowed_prefixes, fn(prefix) { string.starts_with(key, prefix) })
}

@target(erlang)
/// Build an environment entry list for the renderer port.
///
/// Whitelisted variables are set; all other current env vars are
/// explicitly unset so they don't leak to the child process.
pub fn build(opts: EnvOpts) -> List(EnvEntry) {
  let env = get_system_env()

  // Start with whitelisted vars from the system environment
  let allowed = dict.filter(env, fn(key, _val) { is_allowed(key) })

  // Add RUST_LOG
  let allowed = case opts.rust_log {
    Some(level) -> dict.insert(allowed, "RUST_LOG", level)
    None -> dict.insert(allowed, "RUST_LOG", "error")
  }

  // Add RUST_BACKTRACE if not present
  let allowed = case dict.has_key(allowed, "RUST_BACKTRACE") {
    True -> allowed
    False -> dict.insert(allowed, "RUST_BACKTRACE", "1")
  }

  // Merge extra vars
  let allowed = dict.merge(allowed, opts.extra)

  // Build the final list: Set for allowed, Unset for everything else
  let set_entries =
    dict.to_list(allowed)
    |> list.map(fn(pair) { Set(key: pair.0, value: pair.1) })

  let unset_entries =
    dict.to_list(env)
    |> list.filter(fn(pair) { !dict.has_key(allowed, pair.0) })
    |> list.map(fn(pair) { Unset(key: pair.0) })

  list.append(set_entries, unset_entries)
}

@target(erlang)
/// Convert env entries to Erlang port format for the `:env` option.
/// Set entries become `{Charlist, Charlist}`, Unset entries become
/// `{Charlist, false}`.
@external(erlang, "plushie_renderer_env_ffi", "entries_to_port_env")
pub fn to_port_env(entries: List(EnvEntry)) -> Dynamic

@target(erlang)
@external(erlang, "plushie_renderer_env_ffi", "get_env")
fn get_system_env() -> Dict(String, String)
