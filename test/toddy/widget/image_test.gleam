import gleam/dict
import toddy/node.{FloatVal, StringVal}
import toddy/prop/content_fit
import toddy/prop/length
import toddy/widget/image

pub fn new_builds_minimal_image_test() {
  let node = image.new("logo", "/images/logo.png") |> image.build()

  assert node.id == "logo"
  assert node.kind == "image"
  assert node.children == []
  assert dict.get(node.props, "source") == Ok(StringVal("/images/logo.png"))
  assert dict.size(node.props) == 1
}

pub fn width_and_height_set_length_props_test() {
  let node =
    image.new("img", "photo.jpg")
    |> image.width(length.Fixed(200.0))
    |> image.height(length.Fixed(150.0))
    |> image.build()

  assert dict.get(node.props, "width")
    == Ok(length.to_prop_value(length.Fixed(200.0)))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(150.0)))
}

pub fn content_fit_contain_test() {
  let node =
    image.new("img", "photo.jpg")
    |> image.content_fit(content_fit.Contain)
    |> image.build()

  assert dict.get(node.props, "content_fit")
    == Ok(content_fit.to_prop_value(content_fit.Contain))
}

pub fn content_fit_cover_test() {
  let node =
    image.new("img", "photo.jpg")
    |> image.content_fit(content_fit.Cover)
    |> image.build()

  assert dict.get(node.props, "content_fit")
    == Ok(content_fit.to_prop_value(content_fit.Cover))
}

pub fn rotation_sets_float_prop_test() {
  let node =
    image.new("img", "photo.jpg")
    |> image.rotation(90.0)
    |> image.build()

  assert dict.get(node.props, "rotation") == Ok(FloatVal(90.0))
}

pub fn opacity_sets_float_prop_test() {
  let node =
    image.new("img", "photo.jpg")
    |> image.opacity(0.5)
    |> image.build()

  assert dict.get(node.props, "opacity") == Ok(FloatVal(0.5))
}

pub fn border_radius_sets_float_prop_test() {
  let node =
    image.new("img", "photo.jpg")
    |> image.border_radius(8.0)
    |> image.build()

  assert dict.get(node.props, "border_radius") == Ok(FloatVal(8.0))
}

pub fn chaining_multiple_setters_test() {
  let node =
    image.new("avatar", "avatar.png")
    |> image.width(length.Fixed(64.0))
    |> image.height(length.Fixed(64.0))
    |> image.content_fit(content_fit.Cover)
    |> image.border_radius(32.0)
    |> image.opacity(1.0)
    |> image.build()

  assert dict.get(node.props, "source") == Ok(StringVal("avatar.png"))
  assert dict.get(node.props, "border_radius") == Ok(FloatVal(32.0))
  assert dict.get(node.props, "opacity") == Ok(FloatVal(1.0))
}

pub fn omitted_optionals_are_absent_test() {
  let node = image.new("img", "x.png") |> image.build()

  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "content_fit") == Error(Nil)
  assert dict.get(node.props, "rotation") == Error(Nil)
  assert dict.get(node.props, "opacity") == Error(Nil)
  assert dict.get(node.props, "border_radius") == Error(Nil)
}
