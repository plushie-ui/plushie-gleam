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

@external(erlang, "plushie_package_ffi", "default_icons_command")
fn default_icons_command(
  source_path: Result(String, Nil),
  assets_dir: String,
) -> #(String, List(String))

@external(erlang, "plushie_package_ffi", "default_icon_path")
fn default_icon_path() -> String

@external(erlang, "plushie_package_ffi", "platform_manifest_section")
fn platform_manifest_section(icon_path: String) -> String

@external(erlang, "plushie_package_ffi", "app_name_manifest_line")
fn app_name_manifest_line(app_name: Result(String, Nil)) -> String
