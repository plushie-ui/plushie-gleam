import gleam/option.{Some}
import gleeunit/should
import toddy/event.{
  type Event, KeyPress, Modifiers, Standard, TimerTick, WidgetClick, WidgetInput,
  WindowClosed,
}

pub fn widget_click_test() {
  let evt = WidgetClick(id: "save_btn", scope: ["form"])

  assert evt.id == "save_btn"
  assert evt.scope == ["form"]

  // Pattern match round-trip
  case evt {
    WidgetClick(id: "save_btn", scope: ["form"]) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn key_press_with_modifiers_test() {
  let mods =
    Modifiers(shift: False, ctrl: True, alt: False, logo: False, command: True)

  let evt =
    KeyPress(
      key: "s",
      modifiers: mods,
      physical_key: Some("KeyS"),
      location: Standard,
      text: Some("s"),
      repeat: False,
    )

  assert evt.key == "s"
  assert evt.modifiers.ctrl == True
  assert evt.modifiers.command == True
  assert evt.modifiers.shift == False
  assert evt.repeat == False
}

pub fn timer_tick_test() {
  let evt = TimerTick(tag: "refresh", timestamp: 1_710_000_000)

  case evt {
    TimerTick(tag: "refresh", timestamp: ts) -> {
      assert ts == 1_710_000_000
    }
    _ -> should.fail()
  }
}

pub fn modifiers_none_test() {
  let mods = event.modifiers_none()

  assert mods.shift == False
  assert mods.ctrl == False
  assert mods.alt == False
  assert mods.logo == False
  assert mods.command == False
}

/// Demonstrates a realistic update function that handles several event
/// families with a single case expression and a catch-all wildcard.
pub fn realistic_update_pattern_test() {
  let events: List(Event) = [
    WidgetClick(id: "inc", scope: []),
    WidgetClick(id: "dec", scope: []),
    WidgetInput(id: "name", scope: ["form"], value: "Arthur"),
    WindowClosed(window_id: "main"),
    TimerTick(tag: "poll", timestamp: 42),
  ]

  // Simulate fold over events, accumulating a count
  let final_count = do_fold_events(events, 0)

  assert final_count == 0
}

fn do_fold_events(events: List(Event), count: Int) -> Int {
  case events {
    [] -> count
    [evt, ..rest] -> {
      let next = case evt {
        WidgetClick(id: "inc", ..) -> count + 1
        WidgetClick(id: "dec", ..) -> count - 1
        _ -> count
      }
      do_fold_events(rest, next)
    }
  }
}
