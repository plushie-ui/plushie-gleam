//// Color type for widget colors.
////
//// Colors are stored as normalized hex strings (#rrggbb or #rrggbbaa).
//// Opaque type prevents construction of invalid hex values.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import toddy/node.{type PropValue, StringVal}

pub opaque type Color {
  Color(hex: String)
}

/// Create a color from a hex string. Validates and normalizes format.
/// Accepts "#rgb", "#rgba", "#rrggbb", "#rrggbbaa" (with or without #).
pub fn from_hex(hex: String) -> Result(Color, Nil) {
  let raw = case string.starts_with(hex, "#") {
    True -> string.drop_start(hex, 1)
    False -> hex
  }
  let normalized = case string.length(raw) {
    3 -> {
      use _ <- result.try(validate_hex_chars(raw, 3))
      let chars = string.to_graphemes(raw)
      case chars {
        [r, g, b] -> Ok("#" <> r <> r <> g <> g <> b <> b)
        _ -> Error(Nil)
      }
    }
    4 -> {
      use _ <- result.try(validate_hex_chars(raw, 4))
      let chars = string.to_graphemes(raw)
      case chars {
        [r, g, b, a] -> Ok("#" <> r <> r <> g <> g <> b <> b <> a <> a)
        _ -> Error(Nil)
      }
    }
    6 -> validate_hex_chars(raw, 6) |> result.map(fn(_) { "#" <> raw })
    8 -> validate_hex_chars(raw, 8) |> result.map(fn(_) { "#" <> raw })
    _ -> Error(Nil)
  }
  result.map(normalized, fn(h) { Color(string.lowercase(h)) })
}

fn validate_hex_chars(s: String, expected_len: Int) -> Result(Nil, Nil) {
  let chars = string.to_graphemes(s)
  case list.length(chars) == expected_len {
    False -> Error(Nil)
    True -> {
      let all_hex =
        list.all(chars, fn(c) {
          case c {
            "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
            "a" | "b" | "c" | "d" | "e" | "f" -> True
            "A" | "B" | "C" | "D" | "E" | "F" -> True
            _ -> False
          }
        })
      case all_hex {
        True -> Ok(Nil)
        False -> Error(Nil)
      }
    }
  }
}

/// Create a color from RGB components (0-255).
pub fn from_rgb(r: Int, g: Int, b: Int) -> Color {
  let hex =
    "#"
    <> hex_byte(clamp(r, 0, 255))
    <> hex_byte(clamp(g, 0, 255))
    <> hex_byte(clamp(b, 0, 255))
  Color(hex)
}

/// Create a color from RGBA components (0-255 for RGB, 0.0-1.0 for alpha).
pub fn from_rgba(r: Int, g: Int, b: Int, a: Float) -> Color {
  let alpha = float_clamp(a, 0.0, 1.0)
  let alpha_byte = float_to_int(alpha *. 255.0)
  let hex =
    "#"
    <> hex_byte(clamp(r, 0, 255))
    <> hex_byte(clamp(g, 0, 255))
    <> hex_byte(clamp(b, 0, 255))
    <> hex_byte(alpha_byte)
  Color(hex)
}

fn hex_byte(n: Int) -> String {
  let high = n / 16
  let low = n % 16
  hex_digit(high) <> hex_digit(low)
}

fn hex_digit(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    _ -> "f"
  }
}

fn clamp(n: Int, low: Int, high: Int) -> Int {
  int.max(low, int.min(high, n))
}

fn float_clamp(n: Float, low: Float, high: Float) -> Float {
  case n <. low {
    True -> low
    False ->
      case n >. high {
        True -> high
        False -> n
      }
  }
}

fn float_to_int(f: Float) -> Int {
  // Truncate toward zero
  float.truncate(f)
}

/// Get the hex string representation.
pub fn to_hex(color: Color) -> String {
  color.hex
}

/// Encode to wire-format PropValue (hex string).
pub fn to_prop_value(color: Color) -> PropValue {
  StringVal(color.hex)
}

// --- Named colors ------------------------------------------------------------

pub const black = Color("#000000")

pub const white = Color("#ffffff")

pub const transparent = Color("#00000000")

pub const red = Color("#ff0000")

pub const green = Color("#008000")

pub const blue = Color("#0000ff")

pub const yellow = Color("#ffff00")

pub const cyan = Color("#00ffff")

pub const magenta = Color("#ff00ff")

pub const orange = Color("#ffa500")

pub const purple = Color("#800080")

pub const pink = Color("#ffc0cb")

pub const gray = Color("#808080")

pub const grey = Color("#808080")

pub const light_gray = Color("#d3d3d3")

pub const dark_gray = Color("#a9a9a9")

pub const brown = Color("#a52a2a")

pub const navy = Color("#000080")

pub const teal = Color("#008080")

pub const olive = Color("#808000")

pub const maroon = Color("#800000")

pub const aqua = Color("#00ffff")

pub const lime = Color("#00ff00")

pub const silver = Color("#c0c0c0")

pub const fuchsia = Color("#ff00ff")

pub const indigo = Color("#4b0082")

pub const gold = Color("#ffd700")

pub const coral = Color("#ff7f50")

pub const salmon = Color("#fa8072")

pub const tomato = Color("#ff6347")

pub const crimson = Color("#dc143c")

pub const steel_blue = Color("#4682b4")

pub const slate_gray = Color("#708090")

pub const cornflower_blue = Color("#6495ed")

pub const dodger_blue = Color("#1e90ff")

pub const deep_sky_blue = Color("#00bfff")

pub const royal_blue = Color("#4169e1")

pub const medium_blue = Color("#0000cd")

pub const dark_blue = Color("#00008b")

pub const midnight_blue = Color("#191970")

pub const alice_blue = Color("#f0f8ff")

pub const ghost_white = Color("#f8f8ff")

pub const snow = Color("#fffafa")

pub const ivory = Color("#fffff0")

pub const honeydew = Color("#f0fff0")

pub const mint_cream = Color("#f5fffa")

pub const azure = Color("#f0ffff")

pub const lavender = Color("#e6e6fa")

pub const linen = Color("#faf0e6")

pub const beige = Color("#f5f5dc")

pub const wheat = Color("#f5deb3")

pub const sandy_brown = Color("#f4a460")

pub const sienna = Color("#a0522d")

pub const chocolate = Color("#d2691e")

pub const peru = Color("#cd853f")

pub const tan = Color("#d2b48c")

pub const khaki = Color("#f0e68c")

pub const dark_khaki = Color("#bdb76b")

pub const plum = Color("#dda0dd")

pub const violet = Color("#ee82ee")

pub const orchid = Color("#da70d6")

pub const medium_orchid = Color("#ba55d3")

pub const dark_orchid = Color("#9932cc")

pub const dark_violet = Color("#9400d3")

pub const blue_violet = Color("#8a2be2")

pub const medium_purple = Color("#9370db")

pub const thistle = Color("#d8bfd8")

pub const dark_red = Color("#8b0000")

pub const fire_brick = Color("#b22222")

pub const indian_red = Color("#cd5c5c")

pub const light_coral = Color("#f08080")

pub const dark_salmon = Color("#e9967a")

pub const light_salmon = Color("#ffa07a")

pub const peach_puff = Color("#ffdab9")

pub const misty_rose = Color("#ffe4e1")

pub const lavender_blush = Color("#fff0f5")

pub const sea_shell = Color("#fff5ee")

pub const old_lace = Color("#fdf5e6")

pub const papaya_whip = Color("#ffefd5")

pub const blanched_almond = Color("#ffebcd")

pub const bisque = Color("#ffe4c4")

pub const moccasin = Color("#ffe4b5")

pub const navajo_white = Color("#ffdead")

pub const antique_white = Color("#faebd7")

pub const floral_white = Color("#fffaf0")

pub const cornsilk = Color("#fff8dc")

pub const lemon_chiffon = Color("#fffacd")

pub const light_goldenrod_yellow = Color("#fafad2")

pub const light_yellow = Color("#ffffe0")

pub const dark_green = Color("#006400")

pub const forest_green = Color("#228b22")

pub const sea_green = Color("#2e8b57")

pub const medium_sea_green = Color("#3cb371")

pub const light_sea_green = Color("#20b2aa")

pub const dark_cyan = Color("#008b8b")

pub const dark_turquoise = Color("#00ced1")

pub const medium_turquoise = Color("#48d1cc")

pub const turquoise = Color("#40e0d0")

pub const aquamarine = Color("#7fffd4")

pub const medium_aquamarine = Color("#66cdaa")

pub const pale_turquoise = Color("#afeeee")

pub const light_cyan = Color("#e0ffff")

pub const medium_spring_green = Color("#00fa9a")

pub const spring_green = Color("#00ff7f")

pub const light_green = Color("#90ee90")

pub const pale_green = Color("#98fb98")

pub const dark_sea_green = Color("#8fbc8f")

pub const lawn_green = Color("#7cfc00")

pub const chartreuse = Color("#7fff00")

pub const green_yellow = Color("#adff2f")

pub const yellow_green = Color("#9acd32")

pub const olive_drab = Color("#6b8e23")

pub const dark_olive_green = Color("#556b2f")

pub const medium_slate_blue = Color("#7b68ee")

pub const slate_blue = Color("#6a5acd")

pub const dark_slate_blue = Color("#483d8b")

pub const dark_slate_gray = Color("#2f4f4f")

pub const dim_gray = Color("#696969")

pub const light_slate_gray = Color("#778899")

pub const dark_gray_web = Color("#a9a9a9")

pub const gainsboro = Color("#dcdcdc")

pub const white_smoke = Color("#f5f5f5")

pub const cadet_blue = Color("#5f9ea0")

pub const powder_blue = Color("#b0e0e6")

pub const light_blue = Color("#add8e6")

pub const sky_blue = Color("#87ceeb")

pub const light_sky_blue = Color("#87cefa")

pub const medium_violet_red = Color("#c71585")

pub const pale_violet_red = Color("#db7093")

pub const deep_pink = Color("#ff1493")

pub const hot_pink = Color("#ff69b4")

pub const light_pink = Color("#ffb6c1")

pub const dark_orange = Color("#ff8c00")

pub const orange_red = Color("#ff4500")

pub const dark_goldenrod = Color("#b8860b")

pub const goldenrod = Color("#daa520")

pub const pale_goldenrod = Color("#eee8aa")

pub const rosy_brown = Color("#bc8f8f")
