import gleam/dict
import gleeunit/should
import plushie/node.{DictVal, StringVal}
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
