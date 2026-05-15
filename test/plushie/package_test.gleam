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
  |> should.equal("cargo-plushie")
  args
  |> should.equal(["default-icons", "--out", "dist/payload/assets"])
}

pub fn default_icon_path_is_payload_relative_test() {
  default_icon_path()
  |> should.equal("assets/plushie-checkbox-512x512.png")
}

pub fn platform_manifest_section_declares_icon_test() {
  let section = platform_manifest_section(default_icon_path())

  section
  |> string.contains("[platform]\n")
  |> should.equal(True)
  section
  |> string.contains("icon = \"assets/plushie-checkbox-512x512.png\"")
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

pub fn package_config_parser_reads_start_settings_test() {
  let text =
    "config_version = 1\n\n[start]\nworking_dir = \"app\"\ncommand = [\"app/bin/connect\", \"--profile\", \"release\"]\nforward_env = [\n  \"PATH\",\n  \"HOME\",\n]\n"

  parse_package_config_text(text)
  |> should.equal(
    Ok(#("app", ["app/bin/connect", "--profile", "release"], ["PATH", "HOME"])),
  )
}

pub fn package_tools_check_requires_tool_and_launcher_test() {
  package_tools_check(
    "/tmp/plushie-missing-tool",
    "/tmp/plushie-missing-launcher",
  )
  |> should.be_error

  package_tools_check("/bin/sh", "/bin/sh")
  |> should.equal(Ok(Nil))
}

pub fn portable_handoff_text_keeps_default_manual_step_test() {
  portable_handoff_text("dist/plushie-package.toml")
  |> should.equal(
    "Build portable launcher with:\n  bin/plushie package portable --manifest dist/plushie-package.toml\n",
  )
}

pub fn portable_package_command_uses_structured_args_test() {
  let #(command, args) =
    portable_package_command("dist/plushie-package.toml", Error(Nil))

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
    portable_package_command("dist/plushie-package.toml", Ok("dist/app"))

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
fn platform_manifest_section(icon_path: String) -> String

@external(erlang, "plushie_package_ffi", "portable_handoff_text")
fn portable_handoff_text(manifest_path: String) -> String

@external(erlang, "plushie_package_ffi", "portable_package_command")
fn portable_package_command(
  manifest_path: String,
  portable_out: Result(String, Nil),
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
  launcher: String,
) -> Result(Nil, List(String))
