import gleam/string
import gleeunit/should
import plushie/cargo_plushie.{
  CargoPlushie, Environment, NotAvailable, UnparseableVersion, VersionMismatch,
}

// -- resolve_with: source-path path -------------------------------------------

pub fn resolve_prefers_source_path_when_set_test() {
  let env =
    Environment(
      source_path: Ok("/home/dev/plushie-rust"),
      on_path: True,
      path_version_output: Ok("cargo-plushie 9.9.9"),
    )
  let result = cargo_plushie.resolve_with("0.6.1", env)
  case result {
    Ok(CargoPlushie(command:, args_prefix:)) -> {
      should.equal(command, "cargo")
      should.equal(args_prefix, [
        "run",
        "--manifest-path",
        "/home/dev/plushie-rust/Cargo.toml",
        "-p",
        "cargo-plushie",
        "--release",
        "--quiet",
        "--",
      ])
    }
    Error(_) -> should.fail()
  }
}

pub fn resolve_source_path_ignores_on_path_version_test() {
  // Even when cargo-plushie is on PATH at a wildly different version,
  // PLUSHIE_RUST_SOURCE_PATH wins unconditionally: the source path is
  // an explicit opt-in to the local checkout, so the SDK shouldn't
  // second-guess it via a version compare.
  let env =
    Environment(
      source_path: Ok("/src/plushie"),
      on_path: True,
      path_version_output: Ok("cargo-plushie 0.0.1"),
    )
  let result = cargo_plushie.resolve_with("2.0.0", env)
  should.be_ok(result)
}

// -- resolve_with: on-PATH path ------------------------------------------------

pub fn resolve_on_path_matching_version_returns_bare_command_test() {
  let env =
    Environment(
      source_path: Error(Nil),
      on_path: True,
      path_version_output: Ok("cargo-plushie 0.6.1"),
    )
  let result = cargo_plushie.resolve_with("0.6.1", env)
  should.equal(
    result,
    Ok(CargoPlushie(command: "cargo-plushie", args_prefix: [])),
  )
}

pub fn resolve_on_path_version_mismatch_errors_test() {
  let env =
    Environment(
      source_path: Error(Nil),
      on_path: True,
      path_version_output: Ok("cargo-plushie 0.5.0"),
    )
  let result = cargo_plushie.resolve_with("0.6.1", env)
  should.equal(
    result,
    Error(VersionMismatch(expected_version: "0.6.1", found_version: "0.5.0")),
  )
}

pub fn resolve_on_path_version_unparseable_errors_test() {
  let env =
    Environment(
      source_path: Error(Nil),
      on_path: True,
      path_version_output: Ok(""),
    )
  let result = cargo_plushie.resolve_with("0.6.1", env)
  case result {
    Error(UnparseableVersion(_)) -> Nil
    _ -> should.fail()
  }
}

// -- resolve_with: missing-everything path ------------------------------------

pub fn resolve_nothing_available_errors_test() {
  let env =
    Environment(
      source_path: Error(Nil),
      on_path: False,
      path_version_output: Error("cargo-plushie not on PATH"),
    )
  let result = cargo_plushie.resolve_with("0.6.1", env)
  should.equal(result, Error(NotAvailable(expected_version: "0.6.1")))
}

// -- parse_version -------------------------------------------------------------

pub fn parse_version_extracts_last_token_test() {
  should.equal(cargo_plushie.parse_version("cargo-plushie 0.6.1"), Ok("0.6.1"))
  should.equal(
    cargo_plushie.parse_version("cargo-plushie 0.6.1\n"),
    Ok("0.6.1"),
  )
  should.equal(cargo_plushie.parse_version("  0.7.0  "), Ok("0.7.0"))
}

pub fn parse_version_rejects_empty_test() {
  should.equal(cargo_plushie.parse_version(""), Error(Nil))
  should.equal(cargo_plushie.parse_version("   "), Error(Nil))
}

// -- argv / args helpers -------------------------------------------------------

pub fn argv_composes_command_and_prefix_test() {
  let tool =
    CargoPlushie(command: "cargo", args_prefix: [
      "run",
      "--manifest-path",
      "/src/Cargo.toml",
      "-p",
      "cargo-plushie",
      "--release",
      "--quiet",
      "--",
    ])
  let full = cargo_plushie.argv(tool, ["build", "--release"])
  should.equal(full, [
    "cargo",
    "run",
    "--manifest-path",
    "/src/Cargo.toml",
    "-p",
    "cargo-plushie",
    "--release",
    "--quiet",
    "--",
    "build",
    "--release",
  ])
}

pub fn args_is_prefix_plus_subcommand_args_test() {
  let tool = CargoPlushie(command: "cargo-plushie", args_prefix: [])
  should.equal(cargo_plushie.args(tool, ["build"]), ["build"])
}

// -- error message formatting --------------------------------------------------

pub fn resolve_error_message_not_available_mentions_install_cmd_test() {
  let msg =
    cargo_plushie.resolve_error_message(NotAvailable(expected_version: "0.6.1"))
  should.be_true(string.contains(msg, "cargo install cargo-plushie"))
  should.be_true(string.contains(msg, "0.6.1"))
  should.be_true(string.contains(msg, "PLUSHIE_RUST_SOURCE_PATH"))
}

pub fn resolve_error_message_version_mismatch_mentions_both_versions_test() {
  let msg =
    cargo_plushie.resolve_error_message(VersionMismatch(
      expected_version: "0.6.1",
      found_version: "0.5.0",
    ))
  should.be_true(string.contains(msg, "0.6.1"))
  should.be_true(string.contains(msg, "0.5.0"))
}
