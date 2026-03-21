import gleam/dict
import gleam/option.{Some}
import gleeunit/should
import toddy/app
import toddy/node.{DictVal, StringVal}
import toddy/prop/border
import toddy/prop/shadow
import toddy/prop/style_map
import toddy/prop/theme.{CatppuccinMocha, SystemTheme}

// -- Setting a theme via settings --------------------------------------------

pub fn theming_settings_theme_test() {
  let settings =
    app.Settings(..app.default_settings(), theme: Some(CatppuccinMocha))
  settings.theme |> should.equal(Some(CatppuccinMocha))
}

// -- Custom theme via palette ------------------------------------------------

pub fn theming_custom_theme_test() {
  let my_theme =
    theme.custom(
      "my_app",
      dict.from_list([
        #("background", StringVal("#1e1e2e")),
        #("text", StringVal("#cdd6f4")),
        #("primary", StringVal("#89b4fa")),
        #("success", StringVal("#a6e3a1")),
        #("danger", StringVal("#f38ba8")),
        #("warning", StringVal("#f9e2af")),
      ]),
    )
  case my_theme {
    theme.Custom(d) -> {
      // Name should be injected
      dict.get(d, "name") |> should.equal(Ok(StringVal("my_app")))
      dict.get(d, "background") |> should.equal(Ok(StringVal("#1e1e2e")))
    }
    _ -> should.fail()
  }
}

// -- Extended palette shade overrides ----------------------------------------

pub fn theming_custom_theme_shade_overrides_test() {
  let branded_theme =
    theme.custom(
      "branded",
      dict.from_list([
        #("background", StringVal("#1a1a2e")),
        #("text", StringVal("#e0e0e0")),
        #("primary", StringVal("#0f3460")),
        #("primary_strong", StringVal("#1a5276")),
        #("primary_strong_text", StringVal("#ffffff")),
        #("background_weakest", StringVal("#0d0d1a")),
      ]),
    )
  case branded_theme {
    theme.Custom(d) -> {
      dict.get(d, "primary_strong")
      |> should.equal(Ok(StringVal("#1a5276")))
      dict.get(d, "primary_strong_text")
      |> should.equal(Ok(StringVal("#ffffff")))
      dict.get(d, "background_weakest")
      |> should.equal(Ok(StringVal("#0d0d1a")))
    }
    _ -> should.fail()
  }
}

// -- Theme to_prop_value encoding --------------------------------------------

pub fn theming_builtin_to_prop_value_test() {
  theme.to_prop_value(CatppuccinMocha)
  |> should.equal(StringVal("catppuccin_mocha"))
}

pub fn theming_custom_to_prop_value_test() {
  let t = theme.custom("test", dict.from_list([#("text", StringVal("#fff"))]))
  case theme.to_prop_value(t) {
    DictVal(d) -> {
      dict.get(d, "name") |> should.equal(Ok(StringVal("test")))
    }
    _ -> should.fail()
  }
}

// -- Style map construction --------------------------------------------------

pub fn theming_style_map_basic_test() {
  let sm =
    style_map.new()
    |> style_map.background("#ffffff")
    |> style_map.text_color("#1a1a1a")
  case style_map.to_prop_value(sm) {
    DictVal(d) -> {
      dict.get(d, "background") |> should.equal(Ok(StringVal("#ffffff")))
      dict.get(d, "text_color") |> should.equal(Ok(StringVal("#1a1a1a")))
    }
    _ -> should.fail()
  }
}

pub fn theming_style_map_with_border_test() {
  let b =
    border.new()
    |> border.radius(8.0)
    |> border.width(1.0)
  let sm =
    style_map.new()
    |> style_map.border(border.to_prop_value(b))
  case style_map.to_prop_value(sm) {
    DictVal(d) -> {
      // border key should exist
      should.be_true(dict.has_key(d, "border"))
    }
    _ -> should.fail()
  }
}

pub fn theming_style_map_with_shadow_test() {
  let s =
    shadow.new()
    |> shadow.offset(0.0, 2.0)
    |> shadow.blur_radius(8.0)
  let sm =
    style_map.new()
    |> style_map.shadow(shadow.to_prop_value(s))
  case style_map.to_prop_value(sm) {
    DictVal(d) -> {
      should.be_true(dict.has_key(d, "shadow"))
    }
    _ -> should.fail()
  }
}

// -- Status overrides --------------------------------------------------------

pub fn theming_style_map_status_overrides_test() {
  let sm =
    style_map.new()
    |> style_map.background("#00000000")
    |> style_map.text_color("#cccccc")
    |> style_map.hovered(
      style_map.new()
      |> style_map.background("#333333")
      |> style_map.text_color("#ffffff"),
    )
    |> style_map.pressed(
      style_map.new()
      |> style_map.background("#222222"),
    )
    |> style_map.disabled(
      style_map.new()
      |> style_map.text_color("#666666"),
    )
  case style_map.to_prop_value(sm) {
    DictVal(d) -> {
      should.be_true(dict.has_key(d, "hovered"))
      should.be_true(dict.has_key(d, "pressed"))
      should.be_true(dict.has_key(d, "disabled"))
    }
    _ -> should.fail()
  }
}

// -- System theme detection --------------------------------------------------

pub fn theming_system_theme_setting_test() {
  let settings =
    app.Settings(..app.default_settings(), theme: Some(SystemTheme))
  settings.theme |> should.equal(Some(SystemTheme))
}

// -- App settings with scale and vsync ---------------------------------------

pub fn theming_settings_scale_and_vsync_test() {
  let settings =
    app.Settings(
      ..app.default_settings(),
      antialiasing: True,
      vsync: False,
      scale_factor: 1.5,
      default_event_rate: Some(60),
    )
  settings.vsync |> should.be_false()
  settings.scale_factor |> should.equal(1.5)
  settings.default_event_rate |> should.equal(Some(60))
}
