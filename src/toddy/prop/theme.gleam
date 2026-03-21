//// Theme type for application appearance.
////
//// Maps to named themes supported by the Rust binary. Wire format
//// is a lowercase string with underscores separating words.
//// Custom themes are dictionaries that the renderer parses into
//// an iced::Theme::custom() palette.

import gleam/dict.{type Dict}
import toddy/node.{type PropValue, DictVal, StringVal}

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
  Custom(Dict(String, PropValue))
}

/// Build a custom theme palette map.
///
/// The returned dict is passed through to the Rust renderer, which uses it
/// to construct an iced::Theme::custom() with a modified Palette.
///
/// Common keys: "name" (string, required), "base" (built-in theme string),
/// "background", "text", "primary", "success", "danger", "warning" (hex
/// strings). Shade override keys like "primary_strong",
/// "background_weakest", "primary_strong_text" are also accepted.
pub fn custom(name: String, palette: Dict(String, PropValue)) -> Theme {
  Custom(dict.insert(palette, "name", StringVal(name)))
}

/// Encode a Theme to its wire-format PropValue.
pub fn to_prop_value(t: Theme) -> PropValue {
  case t {
    Custom(d) -> DictVal(d)
    _ -> StringVal(to_string(t))
  }
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
    // Custom themes don't have a string representation; use to_prop_value.
    Custom(_) -> "custom"
  }
}
