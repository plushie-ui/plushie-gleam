import gleam/dict
import gleeunit/should
import plushie/node.{DictVal, StringVal}
import plushie/prop/font.{
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
        #("weight", StringVal("bold")),
        #("style", StringVal("italic")),
        #("stretch", StringVal("expanded")),
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
        #("weight", StringVal("bold")),
        #("stretch", StringVal("expanded")),
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
        #("weight", StringVal("bold")),
        #("style", StringVal("italic")),
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
        #("weight", StringVal("bold")),
      ]),
    )
  should.equal(result, expected)
}

pub fn weight_to_string_covers_all_test() {
  should.equal(font.weight_to_string(Thin), "thin")
  should.equal(font.weight_to_string(ExtraLight), "extra_light")
  should.equal(font.weight_to_string(Light), "light")
  should.equal(font.weight_to_string(Normal), "normal")
  should.equal(font.weight_to_string(Medium), "medium")
  should.equal(font.weight_to_string(SemiBold), "semi_bold")
  should.equal(font.weight_to_string(Bold), "bold")
  should.equal(font.weight_to_string(ExtraBold), "extra_bold")
  should.equal(font.weight_to_string(Black), "black")
}

pub fn style_to_string_covers_all_test() {
  should.equal(font.style_to_string(NormalStyle), "normal")
  should.equal(font.style_to_string(Italic), "italic")
  should.equal(font.style_to_string(Oblique), "oblique")
}

pub fn stretch_to_string_covers_all_test() {
  should.equal(font.stretch_to_string(UltraCondensed), "ultra_condensed")
  should.equal(font.stretch_to_string(ExtraCondensed), "extra_condensed")
  should.equal(font.stretch_to_string(Condensed), "condensed")
  should.equal(font.stretch_to_string(SemiCondensed), "semi_condensed")
  should.equal(font.stretch_to_string(NormalStretch), "normal")
  should.equal(font.stretch_to_string(SemiExpanded), "semi_expanded")
  should.equal(font.stretch_to_string(Expanded), "expanded")
  should.equal(font.stretch_to_string(ExtraExpanded), "extra_expanded")
  should.equal(font.stretch_to_string(UltraExpanded), "ultra_expanded")
}
