import gleeunit/should
import plushie/key

// Verify key constants match expected wire protocol strings.
// These are the values the Rust binary sends via Debug formatting.

pub fn navigation_keys_test() {
  should.equal(key.escape, "Escape")
  should.equal(key.enter, "Enter")
  should.equal(key.tab, "Tab")
  should.equal(key.backspace, "Backspace")
  should.equal(key.delete, "Delete")
  should.equal(key.arrow_up, "ArrowUp")
  should.equal(key.arrow_down, "ArrowDown")
  should.equal(key.arrow_left, "ArrowLeft")
  should.equal(key.arrow_right, "ArrowRight")
  should.equal(key.home, "Home")
  should.equal(key.end, "End")
  should.equal(key.page_up, "PageUp")
  should.equal(key.page_down, "PageDown")
  should.equal(key.space, "Space")
  should.equal(key.insert, "Insert")
  should.equal(key.clear, "Clear")
}

pub fn modifier_keys_test() {
  should.equal(key.shift, "Shift")
  should.equal(key.control, "Control")
  should.equal(key.alt, "Alt")
  should.equal(key.meta, "Meta")
  should.equal(key.caps_lock, "CapsLock")
  should.equal(key.alt_graph, "AltGraph")
  should.equal(key.num_lock, "NumLock")
  should.equal(key.scroll_lock, "ScrollLock")
  should.equal(key.fn_key, "Fn")
  should.equal(key.fn_lock, "FnLock")
  should.equal(key.hyper, "Hyper")
  should.equal(key.super_key, "Super")
}

pub fn function_keys_test() {
  should.equal(key.f1, "F1")
  should.equal(key.f2, "F2")
  should.equal(key.f3, "F3")
  should.equal(key.f4, "F4")
  should.equal(key.f5, "F5")
  should.equal(key.f6, "F6")
  should.equal(key.f7, "F7")
  should.equal(key.f8, "F8")
  should.equal(key.f9, "F9")
  should.equal(key.f10, "F10")
  should.equal(key.f11, "F11")
  should.equal(key.f12, "F12")
  should.equal(key.f24, "F24")
  should.equal(key.f35, "F35")
}

pub fn editing_keys_test() {
  should.equal(key.copy, "Copy")
  should.equal(key.cut, "Cut")
  should.equal(key.paste, "Paste")
  should.equal(key.undo, "Undo")
  should.equal(key.redo, "Redo")
}

pub fn media_keys_test() {
  should.equal(key.media_play_pause, "MediaPlayPause")
  should.equal(key.media_stop, "MediaStop")
  should.equal(key.audio_volume_up, "AudioVolumeUp")
  should.equal(key.audio_volume_down, "AudioVolumeDown")
  should.equal(key.audio_volume_mute, "AudioVolumeMute")
}

pub fn physical_keys_test() {
  should.equal(key.key_a, "KeyA")
  should.equal(key.key_z, "KeyZ")
  should.equal(key.digit_0, "Digit0")
  should.equal(key.digit_9, "Digit9")
  should.equal(key.shift_left, "ShiftLeft")
  should.equal(key.shift_right, "ShiftRight")
  should.equal(key.control_left, "ControlLeft")
  should.equal(key.alt_left, "AltLeft")
  should.equal(key.meta_left, "MetaLeft")
  should.equal(key.minus, "Minus")
  should.equal(key.equal, "Equal")
  should.equal(key.bracket_left, "BracketLeft")
  should.equal(key.semicolon, "Semicolon")
  should.equal(key.slash, "Slash")
  should.equal(key.numpad_0, "Numpad0")
  should.equal(key.numpad_add, "NumpadAdd")
}

pub fn ui_keys_test() {
  should.equal(key.context_menu, "ContextMenu")
  should.equal(key.zoom_in, "ZoomIn")
  should.equal(key.zoom_out, "ZoomOut")
  should.equal(key.find, "Find")
  should.equal(key.help, "Help")
}

pub fn system_keys_test() {
  should.equal(key.print_screen, "PrintScreen")
  should.equal(key.brightness_up, "BrightnessUp")
  should.equal(key.brightness_down, "BrightnessDown")
  should.equal(key.wake_up, "WakeUp")
}

pub fn browser_keys_test() {
  should.equal(key.browser_back, "BrowserBack")
  should.equal(key.browser_forward, "BrowserForward")
  should.equal(key.browser_home, "BrowserHome")
  should.equal(key.browser_refresh, "BrowserRefresh")
}

pub fn ime_keys_test() {
  should.equal(key.compose, "Compose")
  should.equal(key.convert, "Convert")
  should.equal(key.hiragana, "Hiragana")
  should.equal(key.katakana, "Katakana")
}
