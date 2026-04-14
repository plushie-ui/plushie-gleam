import gleam/option.{Some}
import gleeunit/should
import plushie/event.{
  type Event, Click, Closed, EventTarget, Input, Key, KeyEvent, KeyPressed,
  Modifiers, Standard, Timer, TimerEvent, Widget, Window, WindowEvent,
}

pub fn widget_click_test() {
  let evt =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save_btn",
        scope: ["form"],
        full: "save_btn",
      )),
    )

  let assert Widget(Click(target:)) = evt
  assert target.id == "save_btn"
  assert target.scope == ["form"]

  // Pattern match round-trip
  case evt {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save_btn",
      scope: ["form"],
      ..,
    ))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn key_press_with_modifiers_test() {
  let mods =
    Modifiers(shift: False, ctrl: True, alt: False, logo: False, command: True)

  let evt =
    Key(KeyEvent(
      event_type: KeyPressed,
      window_id: "",
      key: "s",
      modified_key: "s",
      modifiers: mods,
      physical_key: Some("KeyS"),
      location: Standard,
      text: Some("s"),
      repeat: False,
      captured: False,
    ))

  let Key(KeyEvent(key:, modifiers:, repeat:, ..)) = evt
  assert key == "s"
  assert modifiers.ctrl == True
  assert modifiers.command == True
  assert modifiers.shift == False
  assert repeat == False
}

pub fn timer_tick_test() {
  let evt = Timer(TimerEvent(tag: "refresh", timestamp: 1_710_000_000))

  case evt {
    Timer(TimerEvent(tag: "refresh", timestamp: ts)) -> {
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
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "inc",
        scope: [],
        full: "inc",
      )),
    ),
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "dec",
        scope: [],
        full: "dec",
      )),
    ),
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "name",
        scope: ["form"],
        full: "name",
      ),
      value: "Arthur",
    )),
    Window(WindowEvent(
      event_type: Closed,
      window_id: "main",
      width: option.None,
      height: option.None,
      x: option.None,
      y: option.None,
      scale_factor: option.None,
      path: option.None,
    )),
    Timer(TimerEvent(tag: "poll", timestamp: 42)),
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
        Widget(Click(target: EventTarget(id: "inc", ..))) -> count + 1
        Widget(Click(target: EventTarget(id: "dec", ..))) -> count - 1
        _ -> count
      }
      do_fold_events(rest, next)
    }
  }
}
