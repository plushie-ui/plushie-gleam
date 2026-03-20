//// Theme type for application appearance.
////
//// Maps to named themes supported by the Rust binary. Wire format
//// is a lowercase string with underscores separating words.

import toddy/node.{type PropValue, StringVal}

pub type Theme {
  Light
  Dark
  Dracula
  Nord
  SolarizedLight
  SolarizedDark
  GruvboxLight
  GruvboxDark
  CatppuccinLatte
  CatppuccinFrappe
  CatppuccinMacchiato
  CatppuccinMocha
  TokyoNight
  TokyoNightStorm
  TokyoNightLight
  KanagawaWave
  KanagawaDragon
  KanagawaLotus
  Moonfly
  Nightfly
  Oxocarbon
  Ferra
  SystemTheme
}

/// Encode a Theme to its wire-format PropValue.
pub fn to_prop_value(t: Theme) -> PropValue {
  StringVal(to_string(t))
}

pub fn to_string(t: Theme) -> String {
  case t {
    Light -> "light"
    Dark -> "dark"
    Dracula -> "dracula"
    Nord -> "nord"
    SolarizedLight -> "solarized_light"
    SolarizedDark -> "solarized_dark"
    GruvboxLight -> "gruvbox_light"
    GruvboxDark -> "gruvbox_dark"
    CatppuccinLatte -> "catppuccin_latte"
    CatppuccinFrappe -> "catppuccin_frappe"
    CatppuccinMacchiato -> "catppuccin_macchiato"
    CatppuccinMocha -> "catppuccin_mocha"
    TokyoNight -> "tokyo_night"
    TokyoNightStorm -> "tokyo_night_storm"
    TokyoNightLight -> "tokyo_night_light"
    KanagawaWave -> "kanagawa_wave"
    KanagawaDragon -> "kanagawa_dragon"
    KanagawaLotus -> "kanagawa_lotus"
    Moonfly -> "moonfly"
    Nightfly -> "nightfly"
    Oxocarbon -> "oxocarbon"
    Ferra -> "ferra"
    SystemTheme -> "system"
  }
}
