//// Build a safe environment for the renderer Port child process.
////
//// Erlang ports inherit the parent process environment by default,
//// which can leak sensitive variables (API keys, tokens, database
//// URLs). This module builds the canonical plushie whitelist and
//// actively unsets everything else via `{Name, false}` in the port
//// `:env` option.
////
//// The whitelist matches the canonical list shared across every host
//// SDK: exact entries for display/rendering/locale/accessibility/font
//// vars, prefix entries for families (`LC_`, `MESA_`, ...), and the
//// `PLUSHIE_` prefix for plushie-reserved debug toggles.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
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

/// Exact variable names to forward. Canonical list shared across SDKs.
const allowed_exact = [
  "DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "WINIT_UNIX_BACKEND",
  "XDG_RUNTIME_DIR", "XDG_DATA_DIRS", "XDG_DATA_HOME", "PATH", "LD_LIBRARY_PATH",
  "DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH", "LANG", "LANGUAGE",
  "DBUS_SESSION_BUS_ADDRESS", "GTK_MODULES", "NO_AT_BRIDGE", "WGPU_BACKEND",
  "RUST_LOG", "RUST_BACKTRACE", "HOME", "USER",
]

/// Prefixes: any variable starting with one of these is forwarded.
/// `PLUSHIE_` catches plushie-reserved debug toggles without per-var
/// maintenance (e.g. `PLUSHIE_NO_CATCH_UNWIND`).
const allowed_prefixes = [
  "LC_", "MESA_", "LIBGL_", "__GLX_", "VK_", "GALLIUM_", "AT_SPI_",
  "FONTCONFIG_", "PLUSHIE_",
]

/// Returns True if `key` is on the canonical whitelist.
pub fn is_allowed(key: String) -> Bool {
  case list.contains(allowed_exact, key) {
    True -> True
    False ->
      list.any(allowed_prefixes, fn(prefix) { string.starts_with(key, prefix) })
  }
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

  let allowed_keys: Set(String) = set.from_list(dict.keys(allowed))
  let unset_entries =
    dict.to_list(env)
    |> list.filter(fn(pair) { !set.contains(allowed_keys, pair.0) })
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
