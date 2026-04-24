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

const accepted_custom_theme_keys = "base, name, core color seeds, and shade overrides"

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

/// Build a custom palette entry for the base theme to extend.
pub fn base(t: Theme) -> #(String, PropValue) {
  case t {
    Custom(_) -> panic as "custom themes cannot be used as a base theme"
    SystemTheme -> panic as "system theme cannot be used as a custom theme base"
    _ -> #("base", StringVal(to_string(t)))
  }
}

/// Build a custom palette entry for the page / window background.
pub fn background(hex: String) -> #(String, PropValue) {
  #("background", StringVal(hex))
}

/// Build a custom palette entry for the default text colour.
pub fn text(hex: String) -> #(String, PropValue) {
  #("text", StringVal(hex))
}

/// Build a custom palette entry for the primary accent colour.
pub fn primary(hex: String) -> #(String, PropValue) {
  #("primary", StringVal(hex))
}

/// Build a custom palette entry for success indicators.
pub fn success(hex: String) -> #(String, PropValue) {
  #("success", StringVal(hex))
}

/// Build a custom palette entry for destructive or error states.
pub fn danger(hex: String) -> #(String, PropValue) {
  #("danger", StringVal(hex))
}

/// Build a custom palette entry for warning states.
pub fn warning(hex: String) -> #(String, PropValue) {
  #("warning", StringVal(hex))
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
          <> "\". Accepted keys: "
          <> accepted_custom_theme_keys
          <> "."
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

/// Parse a built-in theme from its wire-format string.
///
/// Custom themes are dictionaries on the wire, so this function does not
/// parse "custom".
pub fn from_string(s: String) -> Result(Theme, Nil) {
  case s {
    "light" -> Ok(Light)
    "dark" -> Ok(Dark)
    "dracula" -> Ok(Dracula)
    "nord" -> Ok(Nord)
    "solarized_light" -> Ok(SolarizedLight)
    "solarized_dark" -> Ok(SolarizedDark)
    "gruvbox_light" -> Ok(GruvboxLight)
    "gruvbox_dark" -> Ok(GruvboxDark)
    "catppuccin_latte" -> Ok(CatppuccinLatte)
    "catppuccin_frappe" -> Ok(CatppuccinFrappe)
    "catppuccin_macchiato" -> Ok(CatppuccinMacchiato)
    "catppuccin_mocha" -> Ok(CatppuccinMocha)
    "tokyo_night" -> Ok(TokyoNight)
    "tokyo_night_storm" -> Ok(TokyoNightStorm)
    "tokyo_night_light" -> Ok(TokyoNightLight)
    "kanagawa_wave" -> Ok(KanagawaWave)
    "kanagawa_dragon" -> Ok(KanagawaDragon)
    "kanagawa_lotus" -> Ok(KanagawaLotus)
    "moonfly" -> Ok(Moonfly)
    "nightfly" -> Ok(Nightfly)
    "oxocarbon" -> Ok(Oxocarbon)
    "ferra" -> Ok(Ferra)
    "system" -> Ok(SystemTheme)
    _ -> Error(Nil)
  }
}

/// Parse an OS theme preference returned by GetSystemTheme or ThemeChanged.
///
/// The renderer reports raw strings here for wire compatibility. Only concrete
/// light and dark preferences map to a `Theme`; "none" and unknown values
/// return `Error(Nil)`.
pub fn system_theme_from_string(s: String) -> Result(Theme, Nil) {
  case s {
    "light" -> Ok(Light)
    "dark" -> Ok(Dark)
    _ -> Error(Nil)
  }
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
