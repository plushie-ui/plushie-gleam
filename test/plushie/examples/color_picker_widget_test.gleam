import examples/widgets/color_picker_widget
import gleam/dynamic
import gleeunit/should
import plushie/event.{type Event, CustomWidget, EventTarget, Widget}
import plushie/widget.{Emit, WidgetDef}

fn element_key_press_event(
  element_id: String,
  key: String,
  shift: Bool,
) -> Event {
  Widget(CustomWidget(
    kind: "element_key_press",
    target: EventTarget(
      window_id: "",
      id: element_id,
      scope: [],
      full: element_id,
    ),
    value: dynamic.nil(),
    data: dynamic.properties([
      #(dynamic.string("key"), dynamic.string(key)),
      #(
        dynamic.string("modifiers"),
        dynamic.properties([
          #(dynamic.string("shift"), dynamic.bool(shift)),
          #(dynamic.string("ctrl"), dynamic.bool(False)),
          #(dynamic.string("alt"), dynamic.bool(False)),
          #(dynamic.string("logo"), dynamic.bool(False)),
          #(dynamic.string("command"), dynamic.bool(False)),
        ]),
      ),
    ]),
  ))
}

pub fn hue_cursor_arrow_right_updates_hue_test() {
  let WidgetDef(init:, handle_event:, ..) = color_picker_widget.def()
  let state = init()

  let #(action, new_state) =
    handle_event(
      element_key_press_event("hue-cursor", "ArrowRight", False),
      state,
    )

  case action, new_state {
    Emit(kind: "change", ..),
      color_picker_widget.PickerState(
        hue: hue,
        saturation: saturation,
        value: value,
        drag: color_picker_widget.DragNone,
      )
    -> {
      should.equal(hue, 1.0)
      should.equal(saturation, 1.0)
      should.equal(value, 1.0)
    }
    _, _ -> should.fail()
  }
}

pub fn sv_cursor_shift_page_up_updates_saturation_test() {
  let WidgetDef(handle_event:, ..) = color_picker_widget.def()
  let state =
    color_picker_widget.PickerState(
      hue: 120.0,
      saturation: 0.5,
      value: 0.5,
      drag: color_picker_widget.DragNone,
    )

  let #(action, new_state) =
    handle_event(element_key_press_event("sv-cursor", "PageUp", True), state)

  case action, new_state {
    Emit(kind: "change", ..),
      color_picker_widget.PickerState(
        hue: hue,
        saturation: saturation,
        value: value,
        drag: color_picker_widget.DragNone,
      )
    -> {
      should.equal(hue, 120.0)
      should.equal(saturation, 0.6)
      should.equal(value, 0.5)
    }
    _, _ -> should.fail()
  }
}
