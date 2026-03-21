import gleam/dict
import gleeunit/should
import toddy/node.{DictVal, StringVal}
import toddy/prop/font.{
  Black, Bold, Condensed, CustomFont, DefaultFont, Expanded, ExtraBold,
  ExtraCondensed, ExtraExpanded, ExtraLight, Family, Italic, Light, Medium,
  Monospace, Normal, NormalStretch, NormalStyle, Oblique, SemiBold,
  SemiCondensed, SemiExpanded, Thin, UltraCondensed, UltraExpanded,
}

pub fn default_font_encodes_to_string_test() {
  should.equal(font.to_prop_value(DefaultFont), StringVal("default"))
}

pub fn monospace_encodes_to_string_test() {
  should.equal(font.to_prop_value(Monospace), StringVal("monospace"))
}

pub fn family_encodes_to_dict_test() {
  let result = font.to_prop_value(Family("Fira Code"))
  let expected = DictVal(dict.from_list([#("family", StringVal("Fira Code"))]))
  should.equal(result, expected)
}

pub fn custom_font_encodes_non_default_fields_test() {
  let f = CustomFont("Inter", Bold, Italic, Expanded)
  let result = font.to_prop_value(f)
  let expected =
    DictVal(
      dict.from_list([
        #("family", StringVal("Inter")),
        #("weight", StringVal("Bold")),
        #("style", StringVal("Italic")),
        #("stretch", StringVal("Expanded")),
      ]),
    )
  should.equal(result, expected)
}

pub fn custom_font_omits_normal_style_test() {
  let f = CustomFont("Inter", Bold, NormalStyle, Expanded)
  let result = font.to_prop_value(f)
  let expected =
    DictVal(
      dict.from_list([
        #("family", StringVal("Inter")),
        #("weight", StringVal("Bold")),
        #("stretch", StringVal("Expanded")),
      ]),
    )
  should.equal(result, expected)
}

pub fn custom_font_omits_normal_stretch_test() {
  let f = CustomFont("Inter", Bold, Italic, NormalStretch)
  let result = font.to_prop_value(f)
  let expected =
    DictVal(
      dict.from_list([
        #("family", StringVal("Inter")),
        #("weight", StringVal("Bold")),
        #("style", StringVal("Italic")),
      ]),
    )
  should.equal(result, expected)
}

pub fn custom_font_omits_both_defaults_test() {
  let f = CustomFont("Inter", Bold, NormalStyle, NormalStretch)
  let result = font.to_prop_value(f)
  let expected =
    DictVal(
      dict.from_list([
        #("family", StringVal("Inter")),
        #("weight", StringVal("Bold")),
      ]),
    )
  should.equal(result, expected)
}

pub fn weight_to_string_covers_all_test() {
  should.equal(font.weight_to_string(Thin), "Thin")
  should.equal(font.weight_to_string(ExtraLight), "ExtraLight")
  should.equal(font.weight_to_string(Light), "Light")
  should.equal(font.weight_to_string(Normal), "Normal")
  should.equal(font.weight_to_string(Medium), "Medium")
  should.equal(font.weight_to_string(SemiBold), "SemiBold")
  should.equal(font.weight_to_string(Bold), "Bold")
  should.equal(font.weight_to_string(ExtraBold), "ExtraBold")
  should.equal(font.weight_to_string(Black), "Black")
}

pub fn style_to_string_covers_all_test() {
  should.equal(font.style_to_string(NormalStyle), "Normal")
  should.equal(font.style_to_string(Italic), "Italic")
  should.equal(font.style_to_string(Oblique), "Oblique")
}

pub fn stretch_to_string_covers_all_test() {
  should.equal(font.stretch_to_string(UltraCondensed), "UltraCondensed")
  should.equal(font.stretch_to_string(ExtraCondensed), "ExtraCondensed")
  should.equal(font.stretch_to_string(Condensed), "Condensed")
  should.equal(font.stretch_to_string(SemiCondensed), "SemiCondensed")
  should.equal(font.stretch_to_string(NormalStretch), "Normal")
  should.equal(font.stretch_to_string(SemiExpanded), "SemiExpanded")
  should.equal(font.stretch_to_string(Expanded), "Expanded")
  should.equal(font.stretch_to_string(ExtraExpanded), "ExtraExpanded")
  should.equal(font.stretch_to_string(UltraExpanded), "UltraExpanded")
}
