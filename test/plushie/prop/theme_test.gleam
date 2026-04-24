import gleam/dict
import gleeunit/should
import plushie/node.{DictVal, StringVal}
import plushie/platform
import plushie/prop/theme

pub fn light_encodes_test() {
  should.equal(theme.to_prop_value(theme.Light), StringVal("light"))
}

pub fn dark_encodes_test() {
  should.equal(theme.to_prop_value(theme.Dark), StringVal("dark"))
}

pub fn solarized_light_encodes_test() {
  should.equal(
    theme.to_prop_value(theme.SolarizedLight),
    StringVal("solarized_light"),
  )
}

pub fn catppuccin_macchiato_encodes_test() {
  should.equal(
    theme.to_prop_value(theme.CatppuccinMacchiato),
    StringVal("catppuccin_macchiato"),
  )
}

pub fn tokyo_night_storm_encodes_test() {
  should.equal(
    theme.to_prop_value(theme.TokyoNightStorm),
    StringVal("tokyo_night_storm"),
  )
}

pub fn kanagawa_wave_encodes_test() {
  should.equal(
    theme.to_prop_value(theme.KanagawaWave),
    StringVal("kanagawa_wave"),
  )
}

pub fn system_theme_encodes_test() {
  should.equal(theme.to_prop_value(theme.SystemTheme), StringVal("system"))
}

pub fn custom_encodes_as_dict_test() {
  let t =
    theme.custom(
      "My Theme",
      dict.from_list([#("primary", StringVal("#7aa2f7"))]),
    )
  let result = theme.to_prop_value(t)
  let expected =
    DictVal(
      dict.from_list([
        #("name", StringVal("My Theme")),
        #("primary", StringVal("#7aa2f7")),
      ]),
    )
  should.equal(result, expected)
}

pub fn custom_with_base_encodes_test() {
  let t =
    theme.custom(
      "Nord+",
      dict.from_list([
        #("base", StringVal("nord")),
        #("primary", StringVal("#88c0d0")),
      ]),
    )
  let result = theme.to_prop_value(t)
  let expected =
    DictVal(
      dict.from_list([
        #("name", StringVal("Nord+")),
        #("base", StringVal("nord")),
        #("primary", StringVal("#88c0d0")),
      ]),
    )
  should.equal(result, expected)
}

pub fn custom_palette_helpers_build_entries_test() {
  let t =
    theme.custom(
      "My Brand",
      dict.from_list([
        theme.base(theme.Nord),
        theme.primary("#3b82f6"),
        theme.danger("#ef4444"),
        theme.background("#1a1a2e"),
        theme.text("#e0e0e8"),
      ]),
    )

  case theme.to_prop_value(t) {
    DictVal(d) -> {
      dict.get(d, "base") |> should.equal(Ok(StringVal("nord")))
      dict.get(d, "primary") |> should.equal(Ok(StringVal("#3b82f6")))
      dict.get(d, "danger") |> should.equal(Ok(StringVal("#ef4444")))
      dict.get(d, "background") |> should.equal(Ok(StringVal("#1a1a2e")))
      dict.get(d, "text") |> should.equal(Ok(StringVal("#e0e0e8")))
    }
    _ -> should.fail()
  }
}

pub fn base_rejects_non_concrete_themes_test() {
  platform.try_call(fn() { theme.base(theme.SystemTheme) })
  |> should.be_error

  platform.try_call(fn() { theme.base(theme.custom("Nested", dict.new())) })
  |> should.be_error
}

pub fn from_string_parses_built_in_themes_test() {
  theme.from_string("dark") |> should.equal(Ok(theme.Dark))
  theme.from_string("catppuccin_mocha")
  |> should.equal(Ok(theme.CatppuccinMocha))
  theme.from_string("system") |> should.equal(Ok(theme.SystemTheme))
}

pub fn from_string_rejects_custom_and_unknown_test() {
  theme.from_string("custom") |> should.equal(Error(Nil))
  theme.from_string("neon_pink") |> should.equal(Error(Nil))
}

pub fn system_theme_from_string_parses_concrete_preferences_test() {
  theme.system_theme_from_string("light") |> should.equal(Ok(theme.Light))
  theme.system_theme_from_string("dark") |> should.equal(Ok(theme.Dark))
}

pub fn system_theme_from_string_rejects_none_and_named_themes_test() {
  theme.system_theme_from_string("none") |> should.equal(Error(Nil))
  theme.system_theme_from_string("nord") |> should.equal(Error(Nil))
}
