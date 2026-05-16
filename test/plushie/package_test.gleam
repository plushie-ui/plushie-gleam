import gleam/string
import gleeunit/should

pub fn default_icons_command_uses_source_checkout_test() {
  let #(command, args) =
    default_icons_command(Ok("/src/plushie-rust"), "dist/payload/assets")

  command
  |> should.equal("cargo")
  args
  |> should.equal([
    "run",
    "--manifest-path",
    "/src/plushie-rust/Cargo.toml",
    "-p",
    "cargo-plushie",
    "--bin",
    "plushie",
    "--release",
    "--",
    "default-icons",
    "--out",
    "dist/payload/assets",
  ])
}

pub fn default_icons_command_uses_installed_tool_test() {
  let #(command, args) =
    default_icons_command(Error(Nil), "dist/payload/assets")

  command
  |> should.equal("bin/plushie")
  args
  |> should.equal(["default-icons", "--out", "dist/payload/assets"])
}

pub fn default_icon_path_is_payload_relative_test() {
  default_icon_path()
  |> should.equal("assets/default-app-icon-512.png")
}

pub fn platform_manifest_section_declares_icon_test() {
  let section = platform_manifest_section(Ok(default_icon_path()))

  section
  |> string.contains("[platform]\n")
  |> should.equal(True)
  section
  |> string.contains("icon = \"assets/default-app-icon-512.png\"")
  |> should.equal(True)
}

pub fn platform_manifest_section_omitted_without_icon_test() {
  platform_manifest_section(Error(Nil))
  |> should.equal("")
}

pub fn manifest_string_fields_escape_toml_strings_test() {
  let text = manifest_escape_probe("value \"quoted\"")

  text
  |> string.contains("value \\\"quoted\\\"")
  |> should.equal(True)
  text
  |> string.contains("value \"quoted\"")
  |> should.equal(False)
  text
  |> string.contains("archive = \"value \\\"quoted\\\"\"")
  |> should.equal(True)
}

pub fn manifest_string_fields_escape_toml_controls_test() {
  let text = manifest_escape_probe("nul \u{0}")

  text
  |> string.contains("nul \\u0000")
  |> should.equal(True)
}

pub fn app_name_manifest_line_is_omitted_without_name_test() {
  app_name_manifest_line(Error(Nil))
  |> should.equal("")
}

pub fn app_name_manifest_line_declares_display_name_test() {
  app_name_manifest_line(Ok("Test App"))
  |> should.equal("app_name = \"Test App\"\n")
}

pub fn app_name_manifest_line_escapes_toml_string_test() {
  app_name_manifest_line(Ok("Test \"App\""))
  |> should.equal("app_name = \"Test \\\"App\\\"\"\n")
}

pub fn package_config_text_contains_real_start_values_test() {
  let text = package_config_text()

  text
  |> string.contains("config_version = 1")
  |> should.equal(True)
  text
  |> string.contains("[start]\n")
  |> should.equal(True)
  text
  |> string.contains("working_dir = \".\"")
  |> should.equal(True)
  text
  |> string.contains("command = [\"bin/connect\"]")
  |> should.equal(True)
  text
  |> string.contains("\"WAYLAND_DISPLAY\"")
  |> should.equal(True)
}

pub fn package_config_text_documents_windows_cmd_convention_test() {
  let text = package_config_text()

  text
  |> string.contains("bin/connect is the POSIX entry point")
  |> should.equal(True)
  text
  |> string.contains(
    "windows-* targets the SDK automatically uses bin/connect.cmd",
  )
  |> should.equal(True)
}

pub fn package_config_parser_reads_start_settings_test() {
  let text =
    "config_version = 1\n\n[start]\nworking_dir = \"app\"\ncommand = [\"app/bin/connect\", \"--profile\", \"release\"]\nforward_env = [\n  \"PATH\",\n  \"HOME\",\n]\n"

  parse_package_config_text(text)
  |> should.equal(
    Ok(#("app", ["app/bin/connect", "--profile", "release"], ["PATH", "HOME"])),
  )
}

pub fn package_tools_check_requires_managed_tool_set_test() {
  package_tools_check(
    "/tmp/plushie-missing-tool",
    "/tmp/plushie-missing-renderer",
    "/tmp/plushie-missing-launcher",
  )
  |> should.equal(
    Error([
      "/tmp/plushie-missing-tool",
      "/tmp/plushie-missing-renderer",
      "/tmp/plushie-missing-launcher",
    ]),
  )

  package_tools_check("/bin/sh", "/bin/sh", "/bin/sh")
  |> should.equal(Ok(Nil))
}

pub fn portable_tools_check_does_not_require_stock_renderer_test() {
  portable_tools_check("/bin/sh", "/bin/sh")
  |> should.equal(Ok(Nil))

  portable_tools_check("/bin/sh", "/tmp/plushie-missing-launcher")
  |> should.equal(Error(["/tmp/plushie-missing-launcher"]))
}

pub fn package_target_accepts_windows_test() {
  package_target_supported("windows-x86_64")
  |> should.equal(Ok(Nil))

  package_target_supported("linux-x86_64")
  |> should.equal(Ok(Nil))
}

pub fn connect_script_windows_uses_cmd_filename_test() {
  let #(filename, _content) = connect_script("windows", "my_app@connect")

  filename
  |> should.equal("bin/connect.cmd")
}

pub fn connect_script_windows_invokes_erl_exe_test() {
  let #(_filename, content) = connect_script("windows", "my_app@connect")

  content
  |> string.contains("erl.exe")
  |> should.equal(True)
  content
  |> string.contains("my_app@connect:main().")
  |> should.equal(True)
  content
  |> string.contains("runtime\\erlang\\bin\\erl.exe")
  |> should.equal(True)
}

pub fn connect_script_windows_starts_with_echo_off_test() {
  let #(_filename, content) = connect_script("windows", "my_app@connect")

  content
  |> string.starts_with("@echo off")
  |> should.equal(True)
}

pub fn connect_script_posix_uses_plain_filename_test() {
  let #(filename, _content) = connect_script("linux", "my_app@connect")

  filename
  |> should.equal("bin/connect")
}

pub fn connect_script_posix_invokes_erl_test() {
  let #(_filename, content) = connect_script("linux", "my_app@connect")

  content
  |> string.contains("runtime/erlang/bin/erl")
  |> should.equal(True)
  content
  |> string.contains("my_app@connect:main().")
  |> should.equal(True)
}

pub fn portable_handoff_text_keeps_default_manual_step_test() {
  portable_handoff_text("dist/plushie-package.toml", False)
  |> should.equal(
    "Build launcher with:\n  bin/plushie package portable --manifest dist/plushie-package.toml\n",
  )
}

pub fn portable_handoff_text_passes_strict_tools_test() {
  portable_handoff_text("dist/plushie-package.toml", True)
  |> should.equal(
    "Build launcher with:\n  bin/plushie package portable --manifest dist/plushie-package.toml --strict-tools\n",
  )
}

pub fn portable_package_command_uses_structured_args_test() {
  let #(command, args) =
    portable_package_command("dist/plushie-package.toml", Error(Nil), False)

  command
  |> should.equal("bin/plushie")
  args
  |> should.equal([
    "package",
    "portable",
    "--manifest",
    "dist/plushie-package.toml",
  ])
}

pub fn portable_package_command_passes_out_path_test() {
  let #(command, args) =
    portable_package_command("dist/plushie-package.toml", Ok("dist/app"), False)

  command
  |> should.equal("bin/plushie")
  args
  |> should.equal([
    "package",
    "portable",
    "--manifest",
    "dist/plushie-package.toml",
    "--out",
    "dist/app",
  ])
}

pub fn portable_package_command_passes_strict_tools_test() {
  let #(command, args) =
    portable_package_command("dist/plushie-package.toml", Ok("dist/app"), True)

  command
  |> should.equal("bin/plushie")
  args
  |> should.equal([
    "package",
    "portable",
    "--manifest",
    "dist/plushie-package.toml",
    "--out",
    "dist/app",
    "--strict-tools",
  ])
}

pub fn package_config_parser_rejects_unsafe_start_settings_test() {
  parse_package_config_text(
    "config_version = 1\n\n[start]\nworking_dir = \"../app\"\ncommand = [\"bin/connect\"]\nforward_env = []\n",
  )
  |> should.be_error

  parse_package_config_text(
    "config_version = 1\n\n[start]\nworking_dir = \".\"\ncommand = [\"/usr/bin/connect\"]\nforward_env = []\n",
  )
  |> should.be_error

  parse_package_config_text(
    "config_version = 1\n\n[start]\nworking_dir = \".\"\ncommand = [\"bin/connect\"]\nforward_env = [\"PLUSHIE_BINARY_PATH\"]\n",
  )
  |> should.be_error

  parse_package_config_text(
    "config_version = 1\n\n[start]\nworking_dir = \".\"\ncommand = [\"bin/connect\"]\nforward_env = [\"PLUSHIE_PACKAGE_READY_FILE\"]\n",
  )
  |> should.be_error
}

@external(erlang, "plushie_package_ffi", "default_icons_command")
fn default_icons_command(
  source_path: Result(String, Nil),
  assets_dir: String,
) -> #(String, List(String))

@external(erlang, "plushie_package_ffi", "default_icon_path")
fn default_icon_path() -> String

@external(erlang, "plushie_package_ffi", "platform_manifest_section")
fn platform_manifest_section(icon_path: Result(String, Nil)) -> String

@external(erlang, "plushie_package_ffi", "manifest_escape_probe")
fn manifest_escape_probe(value: String) -> String

@external(erlang, "plushie_package_ffi", "portable_handoff_text")
fn portable_handoff_text(manifest_path: String, strict_tools: Bool) -> String

@external(erlang, "plushie_package_ffi", "portable_package_command")
fn portable_package_command(
  manifest_path: String,
  portable_out: Result(String, Nil),
  strict_tools: Bool,
) -> #(String, List(String))

@external(erlang, "plushie_package_ffi", "app_name_manifest_line")
fn app_name_manifest_line(app_name: Result(String, Nil)) -> String

@external(erlang, "plushie_package_ffi", "package_config_text")
fn package_config_text() -> String

@external(erlang, "plushie_package_ffi", "parse_package_config_text")
fn parse_package_config_text(
  text: String,
) -> Result(#(String, List(String), List(String)), String)

@external(erlang, "plushie_package_ffi", "package_tools_check")
fn package_tools_check(
  tool: String,
  renderer: String,
  launcher: String,
) -> Result(Nil, List(String))

@external(erlang, "plushie_package_ffi", "portable_tools_check")
fn portable_tools_check(
  tool: String,
  launcher: String,
) -> Result(Nil, List(String))

@external(erlang, "plushie_package_ffi", "package_target_supported")
fn package_target_supported(target: String) -> Result(Nil, List(String))

@external(erlang, "plushie_package_ffi", "connect_script")
fn connect_script(os: String, connect_module: String) -> #(String, String)
