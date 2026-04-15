//// Build the plushie binary and/or WASM renderer from source.
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
//// Requires PLUSHIE_SOURCE_PATH env var pointing to the plushie Rust
//// source checkout. Checks Rust toolchain version, runs cargo build,
//// and installs the binary to build/plushie/bin/. Creates a
//// bin/plushie symlink. WASM files go to priv/wasm/.
////
//// `--bin-file` overrides the default binary destination. The parent
//// directory is created automatically. `--wasm-dir` overrides the
//// default WASM output directory (priv/wasm/).
////
//// ## Native widgets
////
//// When `gleam.toml` contains `native_widgets` entries, the build
//// generates a Cargo workspace in `_build/plushie-renderer/` with a
//// custom main.rs that registers each widget extension. The generated
//// binary is named `{project}-renderer` instead of `plushie-renderer`.
////
//// ```toml
//// [plushie]
//// source_path = "../plushie-rust"
//// native_widgets = [
////   "native/gauge|gauge::GaugeExtension::new()",
////   "native/sparkline|sparkline::SparklineExtension::new()",
//// ]
//// ```

@target(erlang)
import gleam/io
@target(erlang)
import gleam/list
@target(erlang)
import gleam/string
@target(erlang)
import plushie/binary
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

  // Resolve paths: CLI flag > gleam.toml [plushie] > default
  let bin_file =
    get_flag_value("--bin-file")
    |> or_config("bin_file")
  let wasm_dir =
    get_flag_value("--wasm-dir")
    |> or_config("wasm_dir")

  // Only CLI flags (not config paths) imply artifact selection
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

  let source_dir = resolve_source_path()

  case dir_exists(source_dir) {
    False -> {
      io.println_error(
        "Error: plushie source not found at " <> source_dir <> ".",
      )
      halt(1)
    }
    True -> Nil
  }

  // Check for native widgets configuration
  let native_widgets = config.get_native_widgets()
  case native_widgets {
    [] -> build_stock_bin(source_dir, release, verbose, bin_file_override)
    _ ->
      build_with_native_widgets(
        source_dir,
        release,
        verbose,
        bin_file_override,
        native_widgets,
      )
  }
}

@target(erlang)
fn build_stock_bin(
  source_dir: String,
  release: Bool,
  verbose: Bool,
  bin_file_override: Result(String, Nil),
) -> Nil {
  let label = case release {
    True -> "Building plushie (release)..."
    False -> "Building plushie..."
  }
  io.println(label)

  case cargo_build(source_dir, release) {
    Ok(output) -> {
      io.println("Build succeeded.")
      case verbose {
        True -> io.println(output)
        False -> Nil
      }
      install_binary(source_dir, release, bin_file_override)
    }
    Error(output) -> {
      io.println_error("Build failed:")
      io.println_error(output)
      halt(1)
    }
  }
}

// -- Native widget build ------------------------------------------------------

@target(erlang)
fn build_with_native_widgets(
  source_dir: String,
  release: Bool,
  verbose: Bool,
  bin_file_override: Result(String, Nil),
  widgets: List(NativeWidgetConfig),
) -> Nil {
  let proj_name = case project_name() {
    Ok(name) -> name
    Error(_) -> "plushie"
  }
  let bin_name = binary.build_name(Ok(proj_name))

  io.println(
    "Building "
    <> bin_name
    <> " with native widgets ("
    <> string.join(list.map(widgets, fn(w) { w.crate_path }), ", ")
    <> ")...",
  )

  // Validate all widget crate paths
  validate_native_widgets(widgets)

  let cwd = get_cwd()
  let workspace_dir = "_build/plushie-renderer"
  let src_dir = workspace_dir <> "/src"
  ensure_dir(workspace_dir)
  ensure_dir(src_dir)

  // Generate workspace Cargo.toml
  let cargo_toml = generate_cargo_toml(cwd, source_dir, bin_name, widgets)
  write_if_changed(workspace_dir <> "/Cargo.toml", cargo_toml)

  // Generate main.rs
  let main_rs = generate_main_rs(widgets)
  write_if_changed(src_dir <> "/main.rs", main_rs)

  // Copy Cargo.lock from lockfile stash if available
  let lock_stash = "native/plushie/Cargo.lock"
  case file_exists(lock_stash) {
    True -> copy_file(lock_stash, workspace_dir <> "/Cargo.lock")
    False -> Nil
  }

  let manifest_path = cwd <> "/" <> workspace_dir <> "/Cargo.toml"

  let label = case release {
    True -> "Running cargo build (release)..."
    False -> "Running cargo build..."
  }
  io.println(label)

  case cargo_build_workspace(manifest_path, release, verbose) {
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

  // Copy Cargo.lock back to lockfile stash
  let ws_lock = workspace_dir <> "/Cargo.lock"
  case file_exists(ws_lock) {
    True -> {
      ensure_dir("native/plushie")
      copy_file(ws_lock, lock_stash)
      io.println("Saved Cargo.lock to " <> lock_stash)
    }
    False -> Nil
  }

  // Install the built binary
  install_native_binary(workspace_dir, bin_name, release, bin_file_override)
}

@target(erlang)
fn validate_native_widgets(widgets: List(NativeWidgetConfig)) -> Nil {
  // Validate crate paths exist and contain Cargo.toml
  list.each(widgets, fn(w) {
    case dir_exists(w.crate_path) {
      False -> {
        io.println_error(
          "Error: native widget crate not found at " <> w.crate_path,
        )
        halt(1)
      }
      True -> Nil
    }
    let cargo_path = w.crate_path <> "/Cargo.toml"
    case file_exists(cargo_path) {
      False -> {
        io.println_error("Error: Cargo.toml not found at " <> cargo_path)
        halt(1)
      }
      True -> Nil
    }
  })

  // Validate constructor expressions match expected pattern
  list.each(widgets, fn(w) {
    case validate_constructor(w.constructor) {
      True -> Nil
      False -> {
        io.println_error(
          "Error: invalid constructor expression: " <> w.constructor,
        )
        io.println_error(
          "Expected format: module::Type::method() "
          <> "(e.g. gauge::GaugeExtension::new())",
        )
        halt(1)
      }
    }
  })

  // Check for duplicate crate basenames
  let basenames = list.map(widgets, fn(w) { basename(w.crate_path) })
  check_duplicates(basenames, [])
}

@target(erlang)
fn validate_constructor(ctor: String) -> Bool {
  // Must end with "()" and contain at least one identifier segment
  case string.ends_with(ctor, "()") {
    False -> False
    True -> {
      let without_parens = string.drop_end(ctor, 2)
      case without_parens {
        "" -> False
        _ -> {
          // Split on "::" and verify each segment is a valid Rust identifier
          let segments = string.split(without_parens, "::")
          list.all(segments, fn(seg) {
            case seg {
              "" -> False
              _ -> is_valid_rust_ident(seg)
            }
          })
        }
      }
    }
  }
}

@target(erlang)
fn is_valid_rust_ident(s: String) -> Bool {
  let chars = string.to_graphemes(s)
  case chars {
    [] -> False
    [first, ..rest] -> {
      let first_ok = is_alpha_or_underscore(first)
      let rest_ok = list.all(rest, is_alnum_or_underscore)
      first_ok && rest_ok
    }
  }
}

@target(erlang)
fn is_alpha_or_underscore(c: String) -> Bool {
  case c {
    "_"
    | "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    _ -> False
  }
}

@target(erlang)
fn is_alnum_or_underscore(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> is_alpha_or_underscore(c)
  }
}

@target(erlang)
fn check_duplicates(names: List(String), seen: List(String)) -> Nil {
  case names {
    [] -> Nil
    [name, ..rest] ->
      case list.contains(seen, name) {
        True -> {
          io.println_error(
            "Error: duplicate native widget crate basename: " <> name,
          )
          halt(1)
        }
        False -> check_duplicates(rest, [name, ..seen])
      }
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
fn generate_cargo_toml(
  cwd: String,
  source_dir: String,
  bin_name: String,
  widgets: List(NativeWidgetConfig),
) -> String {
  // Resolve source_dir to absolute path
  let abs_source = to_absolute(cwd, source_dir)

  let widget_sdk_dep =
    "plushie-widget-sdk = { path = \""
    <> abs_source
    <> "/crates/plushie-widget-sdk\" }\n"

  let renderer_lib_dep =
    "plushie-renderer-lib = { path = \""
    <> abs_source
    <> "/crates/plushie-renderer-lib\" }\n"

  let renderer_dep =
    "plushie-renderer = { path = \""
    <> abs_source
    <> "/crates/plushie-renderer\" }\n"

  // Widget crate dependencies (use absolute paths)
  let widget_deps =
    list.map(widgets, fn(w) {
      let abs_crate = to_absolute(cwd, w.crate_path)
      let dep_name = basename(w.crate_path)
      dep_name <> " = { path = \"" <> abs_crate <> "\" }\n"
    })
    |> string.join("")

  // Forward [patch.crates-io] from the plushie-rust workspace and add
  // patches for plushie crates so native widget crates that depend on
  // published versions get redirected to the local source checkout.
  let patch_section = forward_patches_with_sdk(abs_source)

  "[package]\n"
  <> "name = \""
  <> bin_name
  <> "\"\n"
  <> "version = \"0.1.0\"\n"
  <> "edition = \"2024\"\n"
  <> "rust-version = \"1.92\"\n"
  <> "\n"
  <> "[[bin]]\n"
  <> "name = \""
  <> bin_name
  <> "\"\n"
  <> "path = \"src/main.rs\"\n"
  <> "\n"
  <> "[dependencies]\n"
  <> widget_sdk_dep
  <> renderer_lib_dep
  <> renderer_dep
  <> widget_deps
  <> "\n"
  <> patch_section
}

@target(erlang)
fn generate_main_rs(widgets: List(NativeWidgetConfig)) -> String {
  let widget_calls =
    list.map(widgets, fn(w) { "            .widget(" <> w.constructor <> ")\n" })
    |> string.join("")

  "// Generated by plushie/build. Do not edit.\n"
  <> "\n"
  <> "fn main() -> plushie_widget_sdk::iced::Result {\n"
  <> "    plushie_renderer::run(\n"
  <> "        plushie_widget_sdk::app::PlushieAppBuilder::new()\n"
  <> widget_calls
  <> "    )\n"
  <> "}\n"
}

@target(erlang)
fn forward_patches(abs_source: String) -> String {
  let cargo_toml_path = abs_source <> "/Cargo.toml"
  case read_file(cargo_toml_path) {
    Ok(content) -> extract_and_resolve_patches(content, abs_source)
    Error(_) -> ""
  }
}

@target(erlang)
fn forward_patches_with_sdk(abs_source: String) -> String {
  // Start with patches forwarded from the plushie-rust workspace
  let base_patches = forward_patches(abs_source)

  // Add path patches for plushie SDK crates so native widget crates
  // that depend on published versions (e.g. plushie-widget-sdk = "0.6")
  // resolve to the local source checkout instead of crates.io.
  let sdk_patches =
    sdk_crate_patches(abs_source)
    |> list.filter(fn(patch) {
      // Only add patches not already present from the workspace
      !string.contains(base_patches, patch.name)
    })
    |> list.filter(fn(patch) { dir_exists(patch.path) })
    |> list.map(fn(patch) {
      patch.name <> " = { path = \"" <> patch.path <> "\" }\n"
    })
    |> string.join("")

  case base_patches, sdk_patches {
    "", "" -> ""
    "", _ -> "[patch.crates-io]\n" <> sdk_patches
    _, "" -> base_patches
    _, _ -> string.trim_end(base_patches) <> "\n" <> sdk_patches <> "\n"
  }
}

/// Crate name and local path for SDK patch entries.
type CratePatch {
  CratePatch(name: String, path: String)
}

@target(erlang)
fn sdk_crate_patches(abs_source: String) -> List(CratePatch) {
  [
    CratePatch("plushie-widget-sdk", abs_source <> "/crates/plushie-widget-sdk"),
    CratePatch("plushie-renderer", abs_source <> "/crates/plushie-renderer"),
    CratePatch(
      "plushie-renderer-lib",
      abs_source <> "/crates/plushie-renderer-lib",
    ),
    CratePatch("plushie-core", abs_source <> "/crates/plushie-core"),
  ]
}

@target(erlang)
fn extract_and_resolve_patches(content: String, abs_source: String) -> String {
  let lines = string.split(content, "\n")
  let patch_lines = collect_patch_section(lines, False, [])
  case patch_lines {
    [] -> ""
    _ -> {
      let resolved =
        list.map(patch_lines, fn(line) { resolve_patch_path(line, abs_source) })
      "[patch.crates-io]\n" <> string.join(resolved, "\n") <> "\n"
    }
  }
}

@target(erlang)
fn collect_patch_section(
  lines: List(String),
  in_section: Bool,
  acc: List(String),
) -> List(String) {
  case lines {
    [] -> list_reverse(acc)
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case in_section {
        False ->
          case trimmed == "[patch.crates-io]" {
            True -> collect_patch_section(rest, True, acc)
            False -> collect_patch_section(rest, False, acc)
          }
        True ->
          case trimmed {
            "" -> collect_patch_section(rest, True, acc)
            _ ->
              case string.starts_with(trimmed, "[") {
                True -> list_reverse(acc)
                False ->
                  case string.starts_with(trimmed, "#") {
                    True -> collect_patch_section(rest, True, acc)
                    False -> collect_patch_section(rest, True, [trimmed, ..acc])
                  }
              }
          }
      }
    }
  }
}

@target(erlang)
fn resolve_patch_path(line: String, abs_source: String) -> String {
  // Transform relative paths in patch entries to absolute paths.
  // Input:  plushie-iced = { path = "../plushie-iced" }
  // Output: plushie-iced = { path = "/abs/path/to/plushie-iced" }
  case string.split_once(line, "path = \"") {
    Ok(#(before, after)) ->
      case string.split_once(after, "\"") {
        Ok(#(rel_path, rest)) -> {
          let abs_path = to_absolute(abs_source, rel_path)
          before <> "path = \"" <> abs_path <> "\"" <> rest
        }
        Error(_) -> line
      }
    Error(_) -> line
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
fn install_native_binary(
  workspace_dir: String,
  bin_name: String,
  release: Bool,
  bin_file_override: Result(String, Nil),
) -> Nil {
  let profile = case release {
    True -> "release"
    False -> "debug"
  }
  let plat = platform.platform_string()
  let arch = platform.arch_string()
  let platform_name = bin_name <> "-" <> plat <> "-" <> arch
  let src = workspace_dir <> "/target/" <> profile <> "/" <> bin_name

  case file_exists(src) {
    False -> {
      io.println_error("Build succeeded but binary not found at " <> src)
      halt(1)
    }
    True -> Nil
  }

  let dest = case bin_file_override {
    Ok(path) -> path
    Error(_) -> binary.download_dir() <> "/" <> platform_name
  }
  let dest_dir = dirname(dest)
  ensure_dir(dest_dir)
  copy_file(src, dest)
  chmod(dest, 0o755)

  // Create bin/ symlink using the custom binary name
  let link_dir = "bin"
  let link_path = link_dir <> "/" <> bin_name
  ensure_dir(link_dir)
  delete_file(link_path)
  case make_symlink(dest, link_path) {
    Ok(_) -> io.println("Created symlink " <> link_path <> " -> " <> dest)
    Error(_) -> io.println("Warning: could not create symlink at " <> link_path)
  }

  // Also create the standard plushie-renderer symlink in bin/
  let std_link = link_dir <> "/plushie-renderer"
  delete_file(std_link)
  case make_symlink(dest, std_link) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }

  // Create a standard-named symlink in the download dir so the binary
  // resolution in binary.gleam can find the custom binary without
  // needing PLUSHIE_BINARY_PATH. Use just the filename as the target
  // since the symlink lives in the same directory as the binary.
  let std_name = "plushie-renderer-" <> plat <> "-" <> arch
  let std_dest = binary.download_dir() <> "/" <> std_name
  case dest == std_dest {
    True -> Nil
    False -> {
      delete_file(std_dest)
      case make_symlink(platform_name, std_dest) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
    }
  }

  io.println("Installed to " <> dest)
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
  case check_wasm_pack() {
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
    Ok(_) -> Nil
  }

  let source_dir = resolve_source_path()

  let wasm_crate = source_dir <> "/plushie-renderer-wasm"

  case dir_exists(wasm_crate) {
    False -> {
      io.println_error(
        "plushie-renderer-wasm crate not found at " <> wasm_crate <> ".",
      )
      io.println_error("")
      io.println_error(
        "The WASM build requires the plushie source checkout to include",
      )
      io.println_error("the plushie-renderer-wasm crate directory.")
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
  // Validate cargo is available before checking versions
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
        Error(_) -> {
          io.println(
            "Warning: could not parse rustc version from: " <> version_str,
          )
        }
        Ok(is_ok) ->
          case is_ok {
            False -> {
              io.println(
                "Warning: rustc "
                <> version_str
                <> " detected, but plushie requires >= "
                <> min_rust_version
                <> ". Consider upgrading with `rustup update`.",
              )
            }
            True -> Nil
          }
      }
    }
  }
}

@target(erlang)
fn install_binary(
  source_dir: String,
  release: Bool,
  bin_file_override: Result(String, Nil),
) -> Nil {
  let profile = case release {
    True -> "release"
    False -> "debug"
  }
  let plat = platform.platform_string()
  let arch = platform.arch_string()
  let binary_name = "plushie-renderer-" <> plat <> "-" <> arch
  let src = source_dir <> "/target/" <> profile <> "/plushie-renderer"

  case platform.file_exists(src) {
    False -> {
      io.println_error("Build succeeded but binary not found at " <> src)
      halt(1)
    }
    True -> Nil
  }

  let dest = case bin_file_override {
    Ok(path) -> path
    Error(_) -> binary.download_dir() <> "/" <> binary_name
  }
  let dest_dir = dirname(dest)
  ensure_dir(dest_dir)
  copy_file(src, dest)
  chmod(dest, 0o755)
  create_bin_symlink(dest)
  copy_cargo_lock(source_dir, dest_dir)
  io.println("Installed to " <> dest)
}

@target(erlang)
fn copy_cargo_lock(source_dir: String, dest_dir: String) -> Nil {
  let lock_src = source_dir <> "/Cargo.lock"
  let lock_dest = dest_dir <> "/Cargo.lock"
  case platform.file_exists(lock_src) {
    True -> {
      copy_file(lock_src, lock_dest)
      io.println("Copied Cargo.lock to " <> dest_dir)
    }
    False -> io.println("Warning: Cargo.lock not found at " <> lock_src)
  }
}

@target(erlang)
fn create_bin_symlink(target_path: String) -> Nil {
  let link_dir = "bin"
  let link_path = link_dir <> "/plushie-renderer"
  ensure_dir(link_dir)
  // Remove existing symlink/file before creating
  delete_file(link_path)
  case make_symlink(target_path, link_path) {
    Ok(_) ->
      io.println("Created symlink " <> link_path <> " -> " <> target_path)
    Error(_) -> io.println("Warning: could not create symlink at " <> link_path)
  }
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

// -- FFI bindings -------------------------------------------------------------

@external(erlang, "plushie_build_ffi", "rustc_version")
fn rustc_version() -> Result(String, String)

@external(erlang, "plushie_build_ffi", "executable_exists")
fn executable_exists(name: String) -> Bool

@external(erlang, "plushie_build_ffi", "cargo_build")
fn cargo_build(source_dir: String, release: Bool) -> Result(String, String)

@external(erlang, "plushie_build_ffi", "cargo_build_workspace")
fn cargo_build_workspace(
  manifest_path: String,
  release: Bool,
  verbose: Bool,
) -> Result(String, String)

@external(erlang, "plushie_build_ffi", "has_flag")
fn has_flag(flag: String) -> Bool

@external(erlang, "plushie_build_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@external(erlang, "plushie_build_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Nil

@external(erlang, "plushie_build_ffi", "copy_file")
fn copy_file(src: String, dest: String) -> Nil

@external(erlang, "plushie_build_ffi", "chmod")
fn chmod(path: String, mode: Int) -> Nil

@external(erlang, "plushie_build_ffi", "dir_exists")
fn dir_exists(path: String) -> Bool

@external(erlang, "plushie_build_ffi", "delete_file")
fn delete_file(path: String) -> Nil

@external(erlang, "plushie_build_ffi", "make_symlink")
fn make_symlink(target: String, link: String) -> Result(Nil, String)

@external(erlang, "plushie_build_ffi", "parse_int")
fn parse_int(s: String) -> Result(Int, Nil)

@external(erlang, "plushie_build_ffi", "check_wasm_pack")
fn check_wasm_pack() -> Result(Nil, String)

@external(erlang, "plushie_build_ffi", "wasm_pack_build")
fn wasm_pack_build(crate_dir: String, release: Bool) -> Result(String, String)

@external(erlang, "plushie_build_ffi", "write_file")
fn write_file(path: String, content: String) -> Nil

@external(erlang, "plushie_build_ffi", "read_file")
fn read_file(path: String) -> Result(String, String)

@external(erlang, "plushie_build_ffi", "file_exists")
fn file_exists(path: String) -> Bool

@external(erlang, "plushie_build_ffi", "project_name")
fn project_name() -> Result(String, String)

@external(erlang, "plushie_build_ffi", "get_cwd")
fn get_cwd() -> String

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

// -- Helpers ------------------------------------------------------------------

@target(erlang)
fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

@target(erlang)
/// Resolve which artifacts to build.
///
/// CLI flags > gleam.toml [plushie] artifacts > default (bin only).
fn resolve_artifacts(
  bin_file: Result(String, Nil),
  wasm_dir: Result(String, Nil),
) -> #(Bool, Bool) {
  let cli_bin = has_flag("--bin") || is_ok(bin_file)
  let cli_wasm = has_flag("--wasm") || is_ok(wasm_dir)

  case cli_bin || cli_wasm {
    True -> #(cli_bin, cli_wasm)
    False ->
      // No CLI flags; check gleam.toml config
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
/// Resolve the plushie source path.
///
/// Resolution: PLUSHIE_SOURCE_PATH env > gleam.toml source_path > error.
fn resolve_source_path() -> String {
  case platform.get_env("PLUSHIE_SOURCE_PATH") {
    Ok(path) -> path
    Error(_) ->
      case config.get_string("source_path") {
        Ok(path) -> path
        Error(_) -> {
          io.println_error("Error: plushie source path not configured.")
          io.println_error("")
          io.println_error("Set one of:")
          io.println_error(
            "  export PLUSHIE_SOURCE_PATH=/path/to/plushie-renderer",
          )
          io.println_error("")
          io.println_error("  # or in gleam.toml:")
          io.println_error("  [plushie]")
          io.println_error("  source_path = \"/path/to/plushie-renderer\"")
          halt(1)
          panic as "unreachable"
        }
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
