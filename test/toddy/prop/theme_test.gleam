import gleeunit/should
import toddy/node.{StringVal}
import toddy/prop/theme

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
