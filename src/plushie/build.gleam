//// Build the plushie renderer binary or WASM bundle.
////
//// Ships in the hex package. Users run:
////
//// ```sh
//// gleam run -m plushie/build                        # native binary (default)
//// gleam run -m plushie/build -- --release            # optimized build
//// gleam run -m plushie/build -- --wasm               # WASM renderer only
//// gleam run -m plushie/build -- --bin --wasm         # both
//// gleam run -m plushie/build -- --verbose            # print cargo output
//// gleam run -m plushie/build -- --bin-file PATH      # custom binary dest
//// gleam run -m plushie/build -- --wasm-dir PATH      # custom WASM dest
//// ```
////
//// The heavy lifting is delegated to `cargo-plushie`. This module
//// only prepares a tiny virtual app crate under
//// `_build/plushie-renderer-spec/` that declares the project's native
//// widget crates as path dependencies, then shells out to:
////
////   <cargo-plushie> build --manifest-path <virtual>/Cargo.toml [--release]
////
//// `cargo-plushie` resolves its workspace under
//// `_build/plushie-renderer-spec/target/plushie-renderer/`, generates a
//// `main.rs` registering every widget, and runs `cargo build`.
////
//// Resolution for `cargo-plushie`:
////
//// 1. `PLUSHIE_RUST_SOURCE_PATH` env var points at a plushie-rust
////    checkout: invoke via `cargo run -p cargo-plushie ...`.
//// 2. `cargo-plushie` on PATH at matching version: invoke directly.
//// 3. Fail with install instructions.
////
//// See `plushie/cargo_plushie` for details.
////
//// ## Native widget metadata (important)
////
//// Each widget crate listed under `[plushie].native_widgets` in the
//// project's `gleam.toml` MUST declare
//// `[package.metadata.plushie.widget]` in its own `Cargo.toml` with
//// `type_name` and `constructor` keys. `cargo-plushie` discovers
//// widgets via `cargo metadata` and refuses to build a crate without
//// that table. Use `cargo plushie new-widget <name>` to scaffold a
//// widget crate with the correct layout.

@target(erlang)
import gleam/io
@target(erlang)
import gleam/list
@target(erlang)
import gleam/string
@target(erlang)
import plushie/binary
@target(erlang)
import plushie/cargo_plushie.{type CargoPlushie}
@target(erlang)
import plushie/config.{type NativeWidgetConfig}
@target(erlang)
import plushie/platform

@target(erlang)
const min_rust_version = "1.92.0"

@target(erlang)
/// Entry point for `gleam run -m plushie/build`.
pub fn main() -> Nil {
  let release = has_flag("--release")
  let verbose = has_flag("--verbose")

  let bin_file =
    get_flag_value("--bin-file")
    |> or_config("bin_file")
  let wasm_dir =
    get_flag_value("--wasm-dir")
    |> or_config("wasm_dir")

  let cli_bin_file = get_flag_value("--bin-file")
  let cli_wasm_dir = get_flag_value("--wasm-dir")
  let #(want_bin, want_wasm) = resolve_artifacts(cli_bin_file, cli_wasm_dir)

  case want_bin {
    True -> build_bin(release, verbose, bin_file)
    False -> Nil
  }

  case want_wasm {
    True -> build_wasm(release, verbose, wasm_dir)
    False -> Nil
  }
}

// -- Native binary build ------------------------------------------------------

@target(erlang)
fn build_bin(
  release: Bool,
  verbose: Bool,
  bin_file_override: Result(String, Nil),
) -> Nil {
  check_rust_toolchain()

  let expected_version = require_plushie_rust_version()
  let tool = require_cargo_plushie(expected_version)

  let widgets = config.get_native_widgets()
  let proj_name = project_name() |> result_or("plushie")
  let bin_name = binary.build_name(Ok(proj_name))

  let cwd = get_cwd()
  let spec_dir = "_build/plushie-renderer-spec"
  let src_dir = spec_dir <> "/src"
  ensure_dir(spec_dir)
  ensure_dir(src_dir)

  let virtual_cargo_toml =
    render_virtual_cargo_toml(
      cwd,
      proj_name,
      bin_name,
      expected_version,
      widgets,
    )
  write_if_changed(spec_dir <> "/Cargo.toml", virtual_cargo_toml)
  // cargo_metadata refuses a package with no targets. A stub lib.rs
  // satisfies that without adding a binary of our own; the real
  // renderer binary is emitted by the workspace cargo-plushie
  // generates under target/plushie-renderer/.
  write_if_changed(
    src_dir <> "/lib.rs",
    "// Stub for cargo_metadata. Do not edit.\n",
  )

  let manifest_path = cwd <> "/" <> spec_dir <> "/Cargo.toml"
  let label = case widgets, release {
    [], True -> "Building " <> bin_name <> " (release)..."
    [], False -> "Building " <> bin_name <> "..."
    _, True ->
      "Building "
      <> bin_name
      <> " with native widgets ("
      <> string.join(list.map(widgets, fn(w) { w.crate_path }), ", ")
      <> ", release)..."
    _, False ->
      "Building "
      <> bin_name
      <> " with native widgets ("
      <> string.join(list.map(widgets, fn(w) { w.crate_path }), ", ")
      <> ")..."
  }
  io.println(label)

  let args = build_args(manifest_path, release, verbose)
  case run_cargo_plushie(tool, args) {
    Ok(output) -> {
      io.println("Build succeeded.")
      case verbose {
        True -> io.println(output)
        False -> Nil
      }
    }
    Error(output) -> {
      io.println_error("Build failed:")
      io.println_error(output)
      halt(1)
    }
  }

  install_binary_from_spec(
    spec_dir,
    bin_name,
    release,
    bin_file_override,
    verbose,
  )
}

@target(erlang)
fn build_args(
  manifest_path: String,
  release: Bool,
  verbose: Bool,
) -> List(String) {
  let base = ["build", "--manifest-path", manifest_path]
  let base = case release {
    True -> list.append(base, ["--release"])
    False -> base
  }
  case verbose {
    True -> list.append(base, ["--verbose"])
    False -> base
  }
}

@target(erlang)
fn require_plushie_rust_version() -> String {
  case config.plushie_rust_version() {
    Ok(v) -> v
    Error(_) -> {
      io.println_error(config.missing_plushie_rust_version_message())
      halt(1)
      panic as "unreachable"
    }
  }
}

@target(erlang)
fn require_cargo_plushie(expected_version: String) -> CargoPlushie {
  case cargo_plushie.resolve(expected_version) {
    Ok(tool) -> tool
    Error(err) -> {
      io.println_error(cargo_plushie.resolve_error_message(err))
      halt(1)
      panic as "unreachable"
    }
  }
}

@target(erlang)
/// Render the virtual app `Cargo.toml` that `cargo-plushie` consumes.
///
/// Declares every native widget crate as a path dependency and carries
/// metadata overrides under `[package.metadata.plushie]`:
///
///   - `binary_name` fixes the produced binary name to `{proj}-renderer`.
///   - `source_path`, if `PLUSHIE_RUST_SOURCE_PATH` is set, pins patch
///     deps at the local plushie-rust checkout.
pub fn render_virtual_cargo_toml(
  cwd: String,
  project: String,
  bin_name: String,
  version: String,
  widgets: List(NativeWidgetConfig),
) -> String {
  let package_name = project <> "_renderer_spec"
  let abs_widgets =
    list.map(widgets, fn(w) {
      let abs = to_absolute(cwd, w.crate_path)
      let dep_name = basename(w.crate_path)
      #(dep_name, abs)
    })

  let header =
    "# Auto-generated by plushie/build. Do not edit.\n\n"
    <> "[package]\n"
    <> "name = \""
    <> package_name
    <> "\"\n"
    <> "version = \""
    <> version
    <> "\"\n"
    <> "edition = \"2024\"\n"
    <> "publish = false\n"
    <> "\n"

  let deps_header = "[dependencies]\n"
  let deps_body = case abs_widgets {
    [] -> ""
    _ ->
      abs_widgets
      |> list.map(fn(pair) {
        let #(name, path) = pair
        name <> " = { path = \"" <> path <> "\" }\n"
      })
      |> string.join("")
  }
  let deps = deps_header <> deps_body <> "\n"

  let meta_header = "[package.metadata.plushie]\n"
  let meta_bin = "binary_name = \"" <> bin_name <> "\"\n"
  let meta_source = case platform.get_env("PLUSHIE_RUST_SOURCE_PATH") {
    Ok(path) -> "source_path = \"" <> path <> "\"\n"
    Error(_) -> ""
  }
  let metadata = meta_header <> meta_bin <> meta_source

  header <> deps <> metadata
}

@target(erlang)
fn install_binary_from_spec(
  spec_dir: String,
  bin_name: String,
  release: Bool,
  bin_file_override: Result(String, Nil),
  verbose: Bool,
) -> Nil {
  // cargo-plushie generates its workspace at
  // {spec_dir}/target/plushie-renderer/ and cargo builds into
  // {spec_dir}/target/plushie-renderer/target/{profile}/<bin-name>.
  let profile = case release {
    True -> "release"
    False -> "debug"
  }
  let src =
    spec_dir <> "/target/plushie-renderer/target/" <> profile <> "/" <> bin_name

  case file_exists(src) {
    False -> {
      io.println_error(missing_binary_message(src, verbose))
      halt(1)
    }
    True -> Nil
  }

  let dest = case bin_file_override {
    Ok(path) -> path
    Error(_) -> binary.download_dir() <> "/" <> binary.download_name()
  }
  let dest_dir = dirname(dest)
  ensure_dir(dest_dir)
  copy_file(src, dest)
  chmod(dest, 0o755)

  io.println("Installed to " <> dest)
}

@target(erlang)
pub fn missing_binary_message(path: String, verbose: Bool) -> String {
  let guidance = case verbose {
    True -> "Check the cargo-plushie output above for compilation issues."
    False ->
      "Rerun the build with `--verbose`, for example `gleam run -m plushie/build -- --verbose`, and check the cargo-plushie output for compilation issues."
  }

  "Build succeeded but binary not found at " <> path <> "\n" <> guidance
}

@target(erlang)
fn write_if_changed(path: String, content: String) -> Nil {
  case read_file(path) {
    Ok(existing) ->
      case existing == content {
        True -> Nil
        False -> write_file(path, content)
      }
    Error(_) -> write_file(path, content)
  }
}

// -- WASM build ---------------------------------------------------------------

@target(erlang)
fn build_wasm(
  release: Bool,
  verbose: Bool,
  wasm_dir_override: Result(String, Nil),
) -> Nil {
  // WASM is always built out of a plushie-rust source checkout. The
  // renderer has no published wasm-pack artifact to fall back on.
  let source_dir = case platform.get_env("PLUSHIE_RUST_SOURCE_PATH") {
    Ok(p) -> p
    Error(_) ->
      case config.get_string("source_path") {
        Ok(p) -> p
        Error(_) -> {
          io.println_error(
            "Error: WASM build requires PLUSHIE_RUST_SOURCE_PATH or gleam.toml [plushie] source_path.",
          )
          halt(1)
          panic as "unreachable"
        }
      }
  }

  case check_wasm_pack() {
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
    Ok(_) -> Nil
  }

  let wasm_crate = source_dir <> "/crates/plushie-renderer-wasm"
  case dir_exists(wasm_crate) {
    False -> {
      io.println_error(
        "plushie-renderer-wasm crate not found at " <> wasm_crate <> ".",
      )
      halt(1)
    }
    True -> Nil
  }

  let label = case release {
    True -> "Building plushie-renderer-wasm (release)..."
    False -> "Building plushie-renderer-wasm..."
  }
  io.println(label)

  case wasm_pack_build(wasm_crate, release) {
    Ok(output) -> {
      io.println("WASM build succeeded.")
      case verbose {
        True -> io.println(output)
        False -> Nil
      }
      install_wasm(wasm_crate, wasm_dir_override)
    }
    Error(output) -> {
      io.println_error("WASM build failed:")
      io.println_error(output)
      halt(1)
    }
  }
}

@target(erlang)
fn install_wasm(
  wasm_crate: String,
  wasm_dir_override: Result(String, Nil),
) -> Nil {
  let pkg_dir = wasm_crate <> "/pkg"
  let dest_dir = case wasm_dir_override {
    Ok(dir) -> dir
    Error(_) -> "priv/wasm"
  }
  ensure_dir(dest_dir)

  copy_wasm_file(pkg_dir, dest_dir, "plushie_renderer_wasm.js")
  copy_wasm_file(pkg_dir, dest_dir, "plushie_renderer_wasm_bg.wasm")

  io.println("Installed WASM files to " <> dest_dir)
}

@target(erlang)
fn copy_wasm_file(pkg_dir: String, dest_dir: String, name: String) -> Nil {
  let src = pkg_dir <> "/" <> name
  let dest = dest_dir <> "/" <> name
  case platform.file_exists(src) {
    True -> copy_file(src, dest)
    False ->
      io.println_error(
        "Warning: expected " <> src <> " not found in wasm-pack output",
      )
  }
}

// -- Shared -------------------------------------------------------------------

@target(erlang)
fn check_rust_toolchain() -> Nil {
  case executable_exists("cargo") {
    False -> {
      io.println_error(
        "Error: cargo not found. Install the Rust toolchain: https://rustup.rs",
      )
      halt(1)
    }
    True -> Nil
  }

  case rustc_version() {
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
    Ok(version_str) -> {
      case compare_versions(version_str, min_rust_version) {
        Error(_) ->
          io.println(
            "Warning: could not parse rustc version from: " <> version_str,
          )
        Ok(is_ok) ->
          case is_ok {
            False ->
              io.println(
                "Warning: rustc "
                <> version_str
                <> " detected, but plushie requires >= "
                <> min_rust_version
                <> ". Consider upgrading with `rustup update`.",
              )
            True -> Nil
          }
      }
    }
  }
}

@target(erlang)
fn run_cargo_plushie(
  tool: CargoPlushie,
  sub_args: List(String),
) -> Result(String, String) {
  let args = cargo_plushie.args(tool, sub_args)
  run_command(tool.command, args)
}

@target(erlang)
fn compare_versions(actual: String, minimum: String) -> Result(Bool, Nil) {
  let actual_parts = string.split(actual, ".")
  let min_parts = string.split(minimum, ".")
  case actual_parts, min_parts {
    [a_maj, a_min, a_patch], [m_maj, m_min, m_patch] -> {
      case
        parse_int(a_maj),
        parse_int(a_min),
        parse_int(a_patch),
        parse_int(m_maj),
        parse_int(m_min),
        parse_int(m_patch)
      {
        Ok(am), Ok(ai), Ok(ap), Ok(mm), Ok(mi), Ok(mp) ->
          Ok(
            am > mm
            || { am == mm && ai > mi }
            || { am == mm && ai == mi && ap >= mp },
          )
        _, _, _, _, _, _ -> Error(Nil)
      }
    }
    _, _ -> Error(Nil)
  }
}

// -- Helpers ------------------------------------------------------------------

@target(erlang)
fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

@target(erlang)
fn result_or(result: Result(a, b), default: a) -> a {
  case result {
    Ok(v) -> v
    Error(_) -> default
  }
}

@target(erlang)
/// Resolve which artifacts to build.
fn resolve_artifacts(
  bin_file: Result(String, Nil),
  wasm_dir: Result(String, Nil),
) -> #(Bool, Bool) {
  let cli_bin = has_flag("--bin") || is_ok(bin_file)
  let cli_wasm = has_flag("--wasm") || is_ok(wasm_dir)

  case cli_bin || cli_wasm {
    True -> #(cli_bin, cli_wasm)
    False ->
      case config.get_artifacts() {
        Ok(artifacts) -> #(
          list.contains(artifacts, "bin"),
          list.contains(artifacts, "wasm"),
        )
        Error(_) -> #(True, False)
      }
  }
}

@target(erlang)
/// Use a gleam.toml config value as fallback when the CLI flag is absent.
fn or_config(
  flag_result: Result(String, Nil),
  config_key: String,
) -> Result(String, Nil) {
  case flag_result {
    Ok(_) -> flag_result
    Error(_) -> config.get_string(config_key)
  }
}

@target(erlang)
fn basename(path: String) -> String {
  let parts = string.split(path, "/")
  case list_reverse(parts) {
    [last, ..] -> last
    [] -> path
  }
}

@target(erlang)
fn to_absolute(base: String, path: String) -> String {
  case string.starts_with(path, "/") {
    True -> path
    False -> normalize_path(base <> "/" <> path)
  }
}

@target(erlang)
fn normalize_path(path: String) -> String {
  let parts = string.split(path, "/")
  let normalized = normalize_parts(parts, [])
  "/" <> string.join(normalized, "/")
}

@target(erlang)
fn normalize_parts(parts: List(String), stack: List(String)) -> List(String) {
  case parts {
    [] -> list_reverse(stack)
    [part, ..rest] ->
      case part {
        "" -> normalize_parts(rest, stack)
        "." -> normalize_parts(rest, stack)
        ".." ->
          case stack {
            [_, ..parent] -> normalize_parts(rest, parent)
            [] -> normalize_parts(rest, [])
          }
        _ -> normalize_parts(rest, [part, ..stack])
      }
  }
}

@target(erlang)
fn dirname(path: String) -> String {
  case string.split(path, "/") {
    [_] -> "."
    parts -> {
      let reversed = list_reverse(parts)
      case reversed {
        [_, ..parent] -> list_reverse(parent) |> string.join("/")
        _ -> "."
      }
    }
  }
}

@target(erlang)
fn list_reverse(items: List(a)) -> List(a) {
  do_reverse(items, [])
}

@target(erlang)
fn do_reverse(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [first, ..rest] -> do_reverse(rest, [first, ..acc])
  }
}

// -- FFI bindings -------------------------------------------------------------

@target(erlang)
@external(erlang, "plushie_build_ffi", "rustc_version")
fn rustc_version() -> Result(String, String)

@target(erlang)
@external(erlang, "plushie_build_ffi", "executable_exists")
fn executable_exists(name: String) -> Bool

@target(erlang)
@external(erlang, "plushie_build_ffi", "run_command")
fn run_command(cmd: String, args: List(String)) -> Result(String, String)

@target(erlang)
@external(erlang, "plushie_build_ffi", "has_flag")
fn has_flag(flag: String) -> Bool

@target(erlang)
@external(erlang, "plushie_build_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@target(erlang)
@external(erlang, "plushie_build_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Nil

@target(erlang)
@external(erlang, "plushie_build_ffi", "copy_file")
fn copy_file(src: String, dest: String) -> Nil

@target(erlang)
@external(erlang, "plushie_build_ffi", "chmod")
fn chmod(path: String, mode: Int) -> Nil

@target(erlang)
@external(erlang, "plushie_build_ffi", "dir_exists")
fn dir_exists(path: String) -> Bool

@target(erlang)
@external(erlang, "plushie_build_ffi", "parse_int")
fn parse_int(s: String) -> Result(Int, Nil)

@target(erlang)
@external(erlang, "plushie_build_ffi", "check_wasm_pack")
fn check_wasm_pack() -> Result(Nil, String)

@target(erlang)
@external(erlang, "plushie_build_ffi", "wasm_pack_build")
fn wasm_pack_build(crate_dir: String, release: Bool) -> Result(String, String)

@target(erlang)
@external(erlang, "plushie_build_ffi", "write_file")
fn write_file(path: String, content: String) -> Nil

@target(erlang)
@external(erlang, "plushie_build_ffi", "read_file")
fn read_file(path: String) -> Result(String, String)

@target(erlang)
@external(erlang, "plushie_build_ffi", "file_exists")
fn file_exists(path: String) -> Bool

@target(erlang)
@external(erlang, "plushie_build_ffi", "project_name")
fn project_name() -> Result(String, String)

@target(erlang)
@external(erlang, "plushie_build_ffi", "get_cwd")
fn get_cwd() -> String

@target(erlang)
@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
