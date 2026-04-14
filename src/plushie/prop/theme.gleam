//// Theme type for application appearance.
////
//// Maps to named themes supported by the Rust binary. Wire format
//// is a lowercase string with underscores separating words.
//// Custom themes are dictionaries that the renderer parses into
//// an iced::Theme::custom() palette.

import gleam/dict.{type Dict}
import gleam/list
import gleam/set.{type Set}
import plushie/node.{type PropValue, DictVal, StringVal}

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
/// Core seed keys: "background", "text", "primary", "success", "danger",
/// "warning". Shade overrides use the pattern "family_shade" (e.g.
/// "primary_strong", "background_weakest") with optional "_text" suffix
/// for text colors. The "base" key selects a built-in theme to extend.
///
/// Unknown keys are rejected at construction time to catch typos early.
pub fn custom(name: String, palette: Dict(String, PropValue)) -> Theme {
  validate_custom_keys(palette)
  Custom(dict.insert(palette, "name", StringVal(name)))
}

fn validate_custom_keys(palette: Dict(String, PropValue)) -> Nil {
  let valid = valid_custom_key_set()
  dict.each(palette, fn(key, _) {
    case key == "base" || key == "name" || set.contains(valid, key) {
      True -> Nil
      False ->
        panic as {
          "unknown theme key \""
          <> key
          <> "\". Valid keys: background, text, primary, success, danger, warning, "
          <> "and shade overrides like primary_strong, background_weakest, etc."
        }
    }
  })
}

fn valid_custom_key_set() -> Set(String) {
  let core_seeds = [
    "background", "text", "primary", "success", "danger", "warning",
  ]
  let color_families = ["primary", "secondary", "success", "warning", "danger"]
  let shades = ["base", "weak", "strong"]
  let background_shades = [
    "background_base", "background_weakest", "background_weaker",
    "background_weak", "background_neutral", "background_strong",
    "background_stronger", "background_strongest",
  ]

  // Generate family_shade and family_shade_text keys
  let color_shade_keys =
    list.flat_map(color_families, fn(family) {
      list.flat_map(shades, fn(shade) {
        let base_key = family <> "_" <> shade
        [base_key, base_key <> "_text"]
      })
    })

  // Generate background shade keys with _text variants
  let background_keys =
    list.flat_map(background_shades, fn(shade) { [shade, shade <> "_text"] })

  set.from_list(list.flatten([core_seeds, color_shade_keys, background_keys]))
}

/// Encode a Theme to its wire-format PropValue.
pub fn to_prop_value(t: Theme) -> PropValue {
  case t {
    Custom(d) -> DictVal(d)
    _ -> StringVal(to_string(t))
  }
}

/// Convert a Theme to its wire-format string representation.
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
