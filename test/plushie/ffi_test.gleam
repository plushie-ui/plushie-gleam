import gleam/bit_array
import gleam/list
import gleam/string
import gleeunit/should
import plushie/platform

pub fn unique_id_generates_different_ids_test() {
  let id1 = platform.unique_id()
  let id2 = platform.unique_id()
  should.not_equal(id1, id2)
}

pub fn try_call_succeeds_test() {
  let result = platform.try_call(fn() { 42 })
  should.equal(result, Ok(42))
}

pub fn try_call_catches_panic_test() {
  let result = platform.try_call(fn() { panic as "boom" })
  should.be_error(result)
}

pub fn file_exists_returns_false_for_missing_file_test() {
  platform.file_exists("/tmp/nonexistent_plushie_file_99999")
  |> should.equal(False)
}

pub fn platform_string_returns_known_value_test() {
  let platform = platform.platform_string()
  let is_known =
    platform == "linux"
    || platform == "darwin"
    || platform == "windows"
    || platform == "unknown"
  should.equal(is_known, True)
}

pub fn arch_string_returns_nonempty_test() {
  let arch = platform.arch_string()
  should.not_equal(arch, "")
}

pub fn get_env_returns_error_for_unset_var_test() {
  platform.unset_env("PLUSHIE_TEST_NONEXISTENT_VAR_12345")
  platform.get_env("PLUSHIE_TEST_NONEXISTENT_VAR_12345")
  |> should.be_error
}

pub fn set_and_get_env_round_trips_test() {
  platform.set_env("PLUSHIE_TEST_FFI_VAR", "hello")
  platform.get_env("PLUSHIE_TEST_FFI_VAR")
  |> should.equal(Ok("hello"))
  platform.unset_env("PLUSHIE_TEST_FFI_VAR")
}

pub fn sha256_hex_returns_lowercase_known_vector_test() {
  let hash = platform.sha256_hex(bit_array.from_string("abc"))

  should.equal(
    hash,
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  should.equal(string.length(hash), 64)
  should.equal(hash, string.lowercase(hash))
}

@target(erlang)
pub fn get_locale_normalizes_erlang_env_test() {
  let saved = save_locale_env()
  clear_locale_env()
  platform.set_env("LC_ALL", "de_DE.UTF-8")

  let locale = platform.get_locale()

  restore_locale_env(saved)
  should.equal(locale, "de-DE")
}

@target(erlang)
pub fn get_locale_falls_back_for_posix_env_test() {
  let saved = save_locale_env()
  clear_locale_env()
  platform.set_env("LC_ALL", "C")
  platform.set_env("LC_MESSAGES", "POSIX")

  let locale = platform.get_locale()

  restore_locale_env(saved)
  should.equal(locale, "en-US")
}

pub fn format_number_uses_english_separators_test() {
  platform.format_number(12_345.67, "en-US")
  |> should.equal("12,345.67")
}

pub fn format_number_uses_german_separators_test() {
  platform.format_number(12_345.67, "de-DE")
  |> should.equal("12.345,67")
}

pub fn format_date_uses_us_order_test() {
  platform.format_date(2026, 4, 23, "en-US")
  |> should.equal("4/23/2026")
}

pub fn format_date_uses_common_european_order_test() {
  platform.format_date(2026, 4, 23, "en-GB")
  |> should.equal("23/04/2026")
}

pub fn unknown_locale_falls_back_without_crashing_test() {
  platform.format_number(12_345.67, "zz-ZZ")
  |> should.equal("12,345.67")
  platform.format_date(2026, 4, 23, "zz-ZZ")
  |> should.equal("2026-04-23")
}

fn save_locale_env() {
  locale_env_names()
  |> list.map(fn(name) { #(name, platform.get_env(name)) })
}

fn clear_locale_env() {
  locale_env_names()
  |> list.each(fn(name) { platform.unset_env(name) })
}

fn restore_locale_env(saved) {
  saved
  |> list.each(fn(entry) {
    case entry {
      #(name, Ok(value)) -> platform.set_env(name, value)
      #(name, Error(_)) -> platform.unset_env(name)
    }
  })
}

fn locale_env_names() {
  ["LC_ALL", "LC_MESSAGES", "LANGUAGE", "LANG"]
}
