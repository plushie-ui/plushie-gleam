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

pub fn package_config_text_documents_platform_fields_test() {
  let text = package_config_text()

  text
  |> string.contains("[platform]")
  |> should.equal(True)

  text
  |> string.contains("publisher")
  |> should.equal(True)

  text
  |> string.contains("[platform.macos]")
  |> should.equal(True)

  text
  |> string.contains("[platform.windows]")
  |> should.equal(True)

  text
  |> string.contains("install_scope")
  |> should.equal(True)
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

pub fn partial_manifest_contains_required_fields_test() {
  let text =
    partial_manifest(
      "dev.example.app",
      Error(Nil),
      "1.0.0",
      "linux-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("schema_version = 1")
  |> should.equal(True)
  text
  |> string.contains("app_id = \"dev.example.app\"")
  |> should.equal(True)
  text
  |> string.contains("app_version = \"1.0.0\"")
  |> should.equal(True)
  text
  |> string.contains("target = \"linux-x86_64\"")
  |> should.equal(True)
  text
  |> string.contains("host_sdk = \"gleam\"")
  |> should.equal(True)
  text
  |> string.contains("host_sdk_version = \"0.6.0\"")
  |> should.equal(True)
  text
  |> string.contains("plushie_rust_version = \"0.7.1\"")
  |> should.equal(True)
  text
  |> string.contains("protocol_version = 1")
  |> should.equal(True)
  text
  |> string.contains("[start]")
  |> should.equal(True)
  text
  |> string.contains("[renderer]")
  |> should.equal(True)
  text
  |> string.contains("kind = \"stock\"")
  |> should.equal(True)
}

pub fn partial_manifest_posix_uses_connect_command_test() {
  let text =
    partial_manifest(
      "dev.example.app",
      Error(Nil),
      "1.0.0",
      "linux-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("command = [\"bin/connect\"]")
  |> should.equal(True)
}

pub fn partial_manifest_windows_uses_cmd_command_test() {
  let text =
    partial_manifest(
      "dev.example.app",
      Error(Nil),
      "1.0.0",
      "windows-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("command = [\"bin/connect.cmd\"]")
  |> should.equal(True)
}

pub fn partial_manifest_omits_payload_section_test() {
  let text =
    partial_manifest(
      "dev.example.app",
      Error(Nil),
      "1.0.0",
      "linux-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("[payload]")
  |> should.equal(False)
}

pub fn partial_manifest_omits_app_name_when_absent_test() {
  let text =
    partial_manifest(
      "dev.example.app",
      Error(Nil),
      "1.0.0",
      "linux-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("app_name")
  |> should.equal(False)
}

pub fn partial_manifest_includes_app_name_when_present_test() {
  let text =
    partial_manifest(
      "dev.example.app",
      Ok("My App"),
      "1.0.0",
      "linux-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("app_name = \"My App\"")
  |> should.equal(True)
}

pub fn partial_manifest_escapes_toml_strings_test() {
  let text =
    partial_manifest(
      "dev.example.app \"quoted\"",
      Error(Nil),
      "1.0.0",
      "linux-x86_64",
      "0.6.0",
      "0.7.1",
      1,
      "stock",
    )

  text
  |> string.contains("app_id = \"dev.example.app \\\"quoted\\\"\"")
  |> should.equal(True)
}

@external(erlang, "plushie_package_ffi", "default_icons_command")
fn default_icons_command(
  source_path: Result(String, Nil),
  assets_dir: String,
) -> #(String, List(String))

@external(erlang, "plushie_package_ffi", "default_icon_path")
fn default_icon_path() -> String

@external(erlang, "plushie_package_ffi", "app_name_manifest_line")
fn app_name_manifest_line(app_name: Result(String, Nil)) -> String

@external(erlang, "plushie_package_ffi", "package_config_text")
fn package_config_text() -> String

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

@external(erlang, "plushie_package_ffi", "partial_manifest")
fn partial_manifest(
  app_id: String,
  app_name: Result(String, Nil),
  app_version: String,
  target: String,
  host_sdk_version: String,
  plushie_rust_version: String,
  protocol_version: Int,
  renderer_kind: String,
) -> String
