//// Key name constants matching wire protocol values.
////
//// These constants provide typo safety and IDE completion for key
//// names used in keyboard event matching. Each value is the exact
//// string sent over the wire by the Rust binary (iced's Debug
//// format for keyboard::key::Named variants).
////
//// ## Usage
////
//// ```gleam
//// import plushie/event.{KeyPress}
//// import plushie/key
////
//// case event {
////   KeyPress(key: k, ..) if k == key.escape -> handle_escape(model)
////   KeyPress(key: k, ..) if k == key.enter -> handle_enter(model)
////   _ -> #(model, command.none())
//// }
//// ```

import gleam/list
import gleam/string

// --- Navigation ---

pub const escape = "Escape"

pub const enter = "Enter"

pub const tab = "Tab"

pub const backspace = "Backspace"

pub const delete = "Delete"

pub const arrow_up = "ArrowUp"

pub const arrow_down = "ArrowDown"

pub const arrow_left = "ArrowLeft"

pub const arrow_right = "ArrowRight"

pub const home = "Home"

pub const end = "End"

pub const page_up = "PageUp"

pub const page_down = "PageDown"

pub const space = "Space"

pub const insert = "Insert"

pub const clear = "Clear"

// --- Modifier keys ---

pub const alt = "Alt"

pub const alt_graph = "AltGraph"

pub const caps_lock = "CapsLock"

pub const control = "Control"

pub const fn_key = "Fn"

pub const fn_lock = "FnLock"

pub const num_lock = "NumLock"

pub const scroll_lock = "ScrollLock"

pub const shift = "Shift"

pub const symbol = "Symbol"

pub const symbol_lock = "SymbolLock"

pub const meta = "Meta"

pub const hyper = "Hyper"

pub const super_key = "Super"

// --- Editing keys ---

pub const copy = "Copy"

pub const cut = "Cut"

pub const paste = "Paste"

pub const redo = "Redo"

pub const undo = "Undo"

pub const cr_sel = "CrSel"

pub const erase_eof = "EraseEof"

pub const ex_sel = "ExSel"

// --- UI keys ---

pub const accept = "Accept"

pub const again = "Again"

pub const attn = "Attn"

pub const cancel = "Cancel"

pub const context_menu = "ContextMenu"

pub const execute = "Execute"

pub const find = "Find"

pub const help = "Help"

pub const pause = "Pause"

pub const play = "Play"

pub const props = "Props"

pub const select = "Select"

pub const zoom_in = "ZoomIn"

pub const zoom_out = "ZoomOut"

// --- System keys ---

pub const brightness_down = "BrightnessDown"

pub const brightness_up = "BrightnessUp"

pub const eject = "Eject"

pub const log_off = "LogOff"

pub const power = "Power"

pub const power_off = "PowerOff"

pub const print_screen = "PrintScreen"

pub const hibernate = "Hibernate"

pub const standby = "Standby"

pub const wake_up = "WakeUp"

// --- Function keys ---

pub const f1 = "F1"

pub const f2 = "F2"

pub const f3 = "F3"

pub const f4 = "F4"

pub const f5 = "F5"

pub const f6 = "F6"

pub const f7 = "F7"

pub const f8 = "F8"

pub const f9 = "F9"

pub const f10 = "F10"

pub const f11 = "F11"

pub const f12 = "F12"

pub const f13 = "F13"

pub const f14 = "F14"

pub const f15 = "F15"

pub const f16 = "F16"

pub const f17 = "F17"

pub const f18 = "F18"

pub const f19 = "F19"

pub const f20 = "F20"

pub const f21 = "F21"

pub const f22 = "F22"

pub const f23 = "F23"

pub const f24 = "F24"

pub const f25 = "F25"

pub const f26 = "F26"

pub const f27 = "F27"

pub const f28 = "F28"

pub const f29 = "F29"

pub const f30 = "F30"

pub const f31 = "F31"

pub const f32 = "F32"

pub const f33 = "F33"

pub const f34 = "F34"

pub const f35 = "F35"

// --- Media keys ---

pub const channel_down = "ChannelDown"

pub const channel_up = "ChannelUp"

pub const close = "Close"

pub const mail_forward = "MailForward"

pub const mail_reply = "MailReply"

pub const mail_send = "MailSend"

pub const media_close = "MediaClose"

pub const media_fast_forward = "MediaFastForward"

pub const media_pause = "MediaPause"

pub const media_play = "MediaPlay"

pub const media_play_pause = "MediaPlayPause"

pub const media_record = "MediaRecord"

pub const media_rewind = "MediaRewind"

pub const media_stop = "MediaStop"

pub const media_track_next = "MediaTrackNext"

pub const media_track_previous = "MediaTrackPrevious"

pub const new = "New"

pub const open = "Open"

pub const print = "Print"

pub const save = "Save"

pub const spell_check = "SpellCheck"

// --- Audio keys ---

pub const audio_balance_left = "AudioBalanceLeft"

pub const audio_balance_right = "AudioBalanceRight"

pub const audio_bass_boost_down = "AudioBassBoostDown"

pub const audio_bass_boost_toggle = "AudioBassBoostToggle"

pub const audio_bass_boost_up = "AudioBassBoostUp"

pub const audio_fader_front = "AudioFaderFront"

pub const audio_fader_rear = "AudioFaderRear"

pub const audio_surround_mode_next = "AudioSurroundModeNext"

pub const audio_treble_down = "AudioTrebleDown"

pub const audio_treble_up = "AudioTrebleUp"

pub const audio_volume_down = "AudioVolumeDown"

pub const audio_volume_up = "AudioVolumeUp"

pub const audio_volume_mute = "AudioVolumeMute"

// --- Microphone keys ---

pub const microphone_toggle = "MicrophoneToggle"

pub const microphone_volume_down = "MicrophoneVolumeDown"

pub const microphone_volume_up = "MicrophoneVolumeUp"

pub const microphone_volume_mute = "MicrophoneVolumeMute"

// --- Speech keys ---

pub const speech_correction_list = "SpeechCorrectionList"

pub const speech_input_toggle = "SpeechInputToggle"

// --- Launch keys ---

pub const launch_application1 = "LaunchApplication1"

pub const launch_application2 = "LaunchApplication2"

pub const launch_calendar = "LaunchCalendar"

pub const launch_contacts = "LaunchContacts"

pub const launch_mail = "LaunchMail"

pub const launch_media_player = "LaunchMediaPlayer"

pub const launch_music_player = "LaunchMusicPlayer"

pub const launch_phone = "LaunchPhone"

pub const launch_screen_saver = "LaunchScreenSaver"

pub const launch_spreadsheet = "LaunchSpreadsheet"

pub const launch_web_browser = "LaunchWebBrowser"

pub const launch_web_cam = "LaunchWebCam"

pub const launch_word_processor = "LaunchWordProcessor"

// --- Browser keys ---

pub const browser_back = "BrowserBack"

pub const browser_favorites = "BrowserFavorites"

pub const browser_forward = "BrowserForward"

pub const browser_home = "BrowserHome"

pub const browser_refresh = "BrowserRefresh"

pub const browser_search = "BrowserSearch"

pub const browser_stop = "BrowserStop"

// --- IME keys ---

pub const all_candidates = "AllCandidates"

pub const alphanumeric = "Alphanumeric"

pub const code_input = "CodeInput"

pub const compose = "Compose"

pub const convert = "Convert"

pub const final_mode = "FinalMode"

pub const group_first = "GroupFirst"

pub const group_last = "GroupLast"

pub const group_next = "GroupNext"

pub const group_previous = "GroupPrevious"

pub const mode_change = "ModeChange"

pub const next_candidate = "NextCandidate"

pub const non_convert = "NonConvert"

pub const previous_candidate = "PreviousCandidate"

pub const process = "Process"

pub const single_candidate = "SingleCandidate"

// --- Korean IME ---

pub const hangul_mode = "HangulMode"

pub const hanja_mode = "HanjaMode"

pub const junja_mode = "JunjaMode"

// --- Japanese IME ---

pub const eisu = "Eisu"

pub const hankaku = "Hankaku"

pub const hiragana = "Hiragana"

pub const hiragana_katakana = "HiraganaKatakana"

pub const kana_mode = "KanaMode"

pub const kanji_mode = "KanjiMode"

pub const katakana = "Katakana"

pub const romaji = "Romaji"

pub const zenkaku = "Zenkaku"

pub const zenkaku_hankaku = "ZenkakuHankaku"

// --- Soft keys ---

pub const soft1 = "Soft1"

pub const soft2 = "Soft2"

pub const soft3 = "Soft3"

pub const soft4 = "Soft4"

// --- Mobile / phone keys ---

pub const app_switch = "AppSwitch"

pub const call = "Call"

pub const camera = "Camera"

pub const camera_focus = "CameraFocus"

pub const end_call = "EndCall"

pub const go_back = "GoBack"

pub const go_home = "GoHome"

pub const headset_hook = "HeadsetHook"

pub const last_number_redial = "LastNumberRedial"

pub const notification = "Notification"

pub const manner_mode = "MannerMode"

pub const voice_dial = "VoiceDial"

// --- Numpad keys ---

pub const key11 = "Key11"

pub const key12 = "Key12"

pub const numpad_backspace = "NumpadBackspace"

pub const numpad_clear = "NumpadClear"

pub const numpad_clear_entry = "NumpadClearEntry"

pub const numpad_comma = "NumpadComma"

pub const numpad_decimal = "NumpadDecimal"

pub const numpad_divide = "NumpadDivide"

pub const numpad_enter = "NumpadEnter"

pub const numpad_equal = "NumpadEqual"

pub const numpad_hash = "NumpadHash"

pub const numpad_memory_add = "NumpadMemoryAdd"

pub const numpad_memory_clear = "NumpadMemoryClear"

pub const numpad_memory_recall = "NumpadMemoryRecall"

pub const numpad_memory_store = "NumpadMemoryStore"

pub const numpad_memory_subtract = "NumpadMemorySubtract"

pub const numpad_multiply = "NumpadMultiply"

pub const numpad_paren_left = "NumpadParenLeft"

pub const numpad_paren_right = "NumpadParenRight"

pub const numpad_star = "NumpadStar"

pub const numpad_subtract = "NumpadSubtract"

// --- TV keys ---

pub const tv = "TV"

pub const tv_3d_mode = "TV3DMode"

pub const tv_antenna_cable = "TVAntennaCable"

pub const tv_audio_description = "TVAudioDescription"

pub const tv_audio_description_mix_down = "TVAudioDescriptionMixDown"

pub const tv_audio_description_mix_up = "TVAudioDescriptionMixUp"

pub const tv_contents_menu = "TVContentsMenu"

pub const tv_data_service = "TVDataService"

pub const tv_input = "TVInput"

pub const tv_input_component1 = "TVInputComponent1"

pub const tv_input_component2 = "TVInputComponent2"

pub const tv_input_composite1 = "TVInputComposite1"

pub const tv_input_composite2 = "TVInputComposite2"

pub const tv_input_hdmi1 = "TVInputHDMI1"

pub const tv_input_hdmi2 = "TVInputHDMI2"

pub const tv_input_hdmi3 = "TVInputHDMI3"

pub const tv_input_hdmi4 = "TVInputHDMI4"

pub const tv_input_vga1 = "TVInputVGA1"

pub const tv_media_context = "TVMediaContext"

pub const tv_network = "TVNetwork"

pub const tv_number_entry = "TVNumberEntry"

pub const tv_power = "TVPower"

pub const tv_radio_service = "TVRadioService"

pub const tv_satellite = "TVSatellite"

pub const tv_satellite_bs = "TVSatelliteBS"

pub const tv_satellite_cs = "TVSatelliteCS"

pub const tv_satellite_toggle = "TVSatelliteToggle"

pub const tv_terrestrial_analog = "TVTerrestrialAnalog"

pub const tv_terrestrial_digital = "TVTerrestrialDigital"

pub const tv_timer = "TVTimer"

// --- Special ---

pub const unidentified = "Unidentified"

// --- Physical key codes ---
// These match the Rust KeyCode Debug format (e.g. "KeyA", "Digit0").

pub const key_a = "KeyA"

pub const key_b = "KeyB"

pub const key_c = "KeyC"

pub const key_d = "KeyD"

pub const key_e = "KeyE"

pub const key_f = "KeyF"

pub const key_g = "KeyG"

pub const key_h = "KeyH"

pub const key_i = "KeyI"

pub const key_j = "KeyJ"

pub const key_k = "KeyK"

pub const key_l = "KeyL"

pub const key_m = "KeyM"

pub const key_n = "KeyN"

pub const key_o = "KeyO"

pub const key_p = "KeyP"

pub const key_q = "KeyQ"

pub const key_r = "KeyR"

pub const key_s = "KeyS"

pub const key_t = "KeyT"

pub const key_u = "KeyU"

pub const key_v = "KeyV"

pub const key_w = "KeyW"

pub const key_x = "KeyX"

pub const key_y = "KeyY"

pub const key_z = "KeyZ"

pub const digit_0 = "Digit0"

pub const digit_1 = "Digit1"

pub const digit_2 = "Digit2"

pub const digit_3 = "Digit3"

pub const digit_4 = "Digit4"

pub const digit_5 = "Digit5"

pub const digit_6 = "Digit6"

pub const digit_7 = "Digit7"

pub const digit_8 = "Digit8"

pub const digit_9 = "Digit9"

pub const shift_left = "ShiftLeft"

pub const shift_right = "ShiftRight"

pub const control_left = "ControlLeft"

pub const control_right = "ControlRight"

pub const alt_left = "AltLeft"

pub const alt_right = "AltRight"

pub const meta_left = "MetaLeft"

pub const meta_right = "MetaRight"

pub const minus = "Minus"

pub const equal = "Equal"

pub const bracket_left = "BracketLeft"

pub const bracket_right = "BracketRight"

pub const backslash = "Backslash"

pub const semicolon = "Semicolon"

pub const quote = "Quote"

pub const backquote = "Backquote"

pub const comma = "Comma"

pub const period = "Period"

pub const slash = "Slash"

pub const numpad_0 = "Numpad0"

pub const numpad_1 = "Numpad1"

pub const numpad_2 = "Numpad2"

pub const numpad_3 = "Numpad3"

pub const numpad_4 = "Numpad4"

pub const numpad_5 = "Numpad5"

pub const numpad_6 = "Numpad6"

pub const numpad_7 = "Numpad7"

pub const numpad_8 = "Numpad8"

pub const numpad_9 = "Numpad9"

pub const numpad_add = "NumpadAdd"

/// Check if a key name is valid for use in test helpers.
///
/// Case-insensitive: "Tab", "tab", and "TAB" are all valid.
/// Single characters are always valid. Named keys resolve to
/// PascalCase matching the renderer's wire format.
pub fn is_valid(name: String) -> Bool {
  case resolve(name) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Resolve a key name to PascalCase wire format (case-insensitive).
///
/// The full set of named keys from the renderer is supported.
/// Single characters are lowercased. Returns the PascalCase name
/// that matches what the renderer sends in key events, so
/// handle_event patterns match naturally.
///
///     resolve("tab") -> Ok("Tab")
///     resolve("ArrowRight") -> Ok("ArrowRight")
///     resolve("a") -> Ok("a")
///     resolve("tabb") -> Error(Nil)
pub fn resolve(name: String) -> Result(String, Nil) {
  case string.length(name) {
    1 -> Ok(string.lowercase(name))
    _ ->
      case string.lowercase(name) {
        "escape" -> Ok("Escape")
        "enter" -> Ok("Enter")
        "tab" -> Ok("Tab")
        "backspace" -> Ok("Backspace")
        "delete" -> Ok("Delete")
        "arrowup" -> Ok("ArrowUp")
        "arrowdown" -> Ok("ArrowDown")
        "arrowleft" -> Ok("ArrowLeft")
        "arrowright" -> Ok("ArrowRight")
        "home" -> Ok("Home")
        "end" -> Ok("End")
        "pageup" -> Ok("PageUp")
        "pagedown" -> Ok("PageDown")
        "space" -> Ok("Space")
        "insert" -> Ok("Insert")
        "clear" -> Ok("Clear")
        "alt" -> Ok("Alt")
        "altgraph" -> Ok("AltGraph")
        "capslock" -> Ok("CapsLock")
        "control" -> Ok("Control")
        "fn" -> Ok("Fn")
        "fnlock" -> Ok("FnLock")
        "numlock" -> Ok("NumLock")
        "scrolllock" -> Ok("ScrollLock")
        "shift" -> Ok("Shift")
        "symbol" -> Ok("Symbol")
        "symbollock" -> Ok("SymbolLock")
        "meta" -> Ok("Meta")
        "hyper" -> Ok("Hyper")
        "super" -> Ok("Super")
        "copy" -> Ok("Copy")
        "cut" -> Ok("Cut")
        "paste" -> Ok("Paste")
        "redo" -> Ok("Redo")
        "undo" -> Ok("Undo")
        "crsel" -> Ok("CrSel")
        "eraseeof" -> Ok("EraseEof")
        "exsel" -> Ok("ExSel")
        "accept" -> Ok("Accept")
        "again" -> Ok("Again")
        "attn" -> Ok("Attn")
        "cancel" -> Ok("Cancel")
        "contextmenu" -> Ok("ContextMenu")
        "execute" -> Ok("Execute")
        "find" -> Ok("Find")
        "help" -> Ok("Help")
        "pause" -> Ok("Pause")
        "play" -> Ok("Play")
        "props" -> Ok("Props")
        "select" -> Ok("Select")
        "zoomin" -> Ok("ZoomIn")
        "zoomout" -> Ok("ZoomOut")
        "brightnessdown" -> Ok("BrightnessDown")
        "brightnessup" -> Ok("BrightnessUp")
        "eject" -> Ok("Eject")
        "logoff" -> Ok("LogOff")
        "power" -> Ok("Power")
        "poweroff" -> Ok("PowerOff")
        "printscreen" -> Ok("PrintScreen")
        "hibernate" -> Ok("Hibernate")
        "standby" -> Ok("Standby")
        "wakeup" -> Ok("WakeUp")
        "f1" -> Ok("F1")
        "f2" -> Ok("F2")
        "f3" -> Ok("F3")
        "f4" -> Ok("F4")
        "f5" -> Ok("F5")
        "f6" -> Ok("F6")
        "f7" -> Ok("F7")
        "f8" -> Ok("F8")
        "f9" -> Ok("F9")
        "f10" -> Ok("F10")
        "f11" -> Ok("F11")
        "f12" -> Ok("F12")
        "f13" -> Ok("F13")
        "f14" -> Ok("F14")
        "f15" -> Ok("F15")
        "f16" -> Ok("F16")
        "f17" -> Ok("F17")
        "f18" -> Ok("F18")
        "f19" -> Ok("F19")
        "f20" -> Ok("F20")
        "f21" -> Ok("F21")
        "f22" -> Ok("F22")
        "f23" -> Ok("F23")
        "f24" -> Ok("F24")
        "f25" -> Ok("F25")
        "f26" -> Ok("F26")
        "f27" -> Ok("F27")
        "f28" -> Ok("F28")
        "f29" -> Ok("F29")
        "f30" -> Ok("F30")
        "f31" -> Ok("F31")
        "f32" -> Ok("F32")
        "f33" -> Ok("F33")
        "f34" -> Ok("F34")
        "f35" -> Ok("F35")
        "channeldown" -> Ok("ChannelDown")
        "channelup" -> Ok("ChannelUp")
        "close" -> Ok("Close")
        "mailforward" -> Ok("MailForward")
        "mailreply" -> Ok("MailReply")
        "mailsend" -> Ok("MailSend")
        "mediaclose" -> Ok("MediaClose")
        "mediafastforward" -> Ok("MediaFastForward")
        "mediapause" -> Ok("MediaPause")
        "mediaplay" -> Ok("MediaPlay")
        "mediaplaypause" -> Ok("MediaPlayPause")
        "mediarecord" -> Ok("MediaRecord")
        "mediarewind" -> Ok("MediaRewind")
        "mediastop" -> Ok("MediaStop")
        "mediatracknext" -> Ok("MediaTrackNext")
        "mediatrackprevious" -> Ok("MediaTrackPrevious")
        "new" -> Ok("New")
        "open" -> Ok("Open")
        "print" -> Ok("Print")
        "save" -> Ok("Save")
        "spellcheck" -> Ok("SpellCheck")
        "audiobalanceleft" -> Ok("AudioBalanceLeft")
        "audiobalanceright" -> Ok("AudioBalanceRight")
        "audiobassboostdown" -> Ok("AudioBassBoostDown")
        "audiobassboosttoggle" -> Ok("AudioBassBoostToggle")
        "audiobassboostup" -> Ok("AudioBassBoostUp")
        "audiofaderfront" -> Ok("AudioFaderFront")
        "audiofaderrear" -> Ok("AudioFaderRear")
        "audiosurroundmodenext" -> Ok("AudioSurroundModeNext")
        "audiotrebledown" -> Ok("AudioTrebleDown")
        "audiotrebleup" -> Ok("AudioTrebleUp")
        "audiovolumedown" -> Ok("AudioVolumeDown")
        "audiovolumeup" -> Ok("AudioVolumeUp")
        "audiovolumemute" -> Ok("AudioVolumeMute")
        "microphonetoggle" -> Ok("MicrophoneToggle")
        "microphonevolumedown" -> Ok("MicrophoneVolumeDown")
        "microphonevolumeup" -> Ok("MicrophoneVolumeUp")
        "microphonevolumemute" -> Ok("MicrophoneVolumeMute")
        "speechcorrectionlist" -> Ok("SpeechCorrectionList")
        "speechinputtoggle" -> Ok("SpeechInputToggle")
        "launchapplication1" -> Ok("LaunchApplication1")
        "launchapplication2" -> Ok("LaunchApplication2")
        "launchcalendar" -> Ok("LaunchCalendar")
        "launchcontacts" -> Ok("LaunchContacts")
        "launchmail" -> Ok("LaunchMail")
        "launchmediaplayer" -> Ok("LaunchMediaPlayer")
        "launchmusicplayer" -> Ok("LaunchMusicPlayer")
        "launchphone" -> Ok("LaunchPhone")
        "launchscreensaver" -> Ok("LaunchScreenSaver")
        "launchspreadsheet" -> Ok("LaunchSpreadsheet")
        "launchwebbrowser" -> Ok("LaunchWebBrowser")
        "launchwebcam" -> Ok("LaunchWebCam")
        "launchwordprocessor" -> Ok("LaunchWordProcessor")
        "browserback" -> Ok("BrowserBack")
        "browserfavorites" -> Ok("BrowserFavorites")
        "browserforward" -> Ok("BrowserForward")
        "browserhome" -> Ok("BrowserHome")
        "browserrefresh" -> Ok("BrowserRefresh")
        "browsersearch" -> Ok("BrowserSearch")
        "browserstop" -> Ok("BrowserStop")
        "allcandidates" -> Ok("AllCandidates")
        "alphanumeric" -> Ok("Alphanumeric")
        "codeinput" -> Ok("CodeInput")
        "compose" -> Ok("Compose")
        "convert" -> Ok("Convert")
        "finalmode" -> Ok("FinalMode")
        "groupfirst" -> Ok("GroupFirst")
        "grouplast" -> Ok("GroupLast")
        "groupnext" -> Ok("GroupNext")
        "groupprevious" -> Ok("GroupPrevious")
        "modechange" -> Ok("ModeChange")
        "nextcandidate" -> Ok("NextCandidate")
        "nonconvert" -> Ok("NonConvert")
        "previouscandidate" -> Ok("PreviousCandidate")
        "process" -> Ok("Process")
        "singlecandidate" -> Ok("SingleCandidate")
        "hangulmode" -> Ok("HangulMode")
        "hanjamode" -> Ok("HanjaMode")
        "junjamode" -> Ok("JunjaMode")
        "eisu" -> Ok("Eisu")
        "hankaku" -> Ok("Hankaku")
        "hiragana" -> Ok("Hiragana")
        "hiraganakatakana" -> Ok("HiraganaKatakana")
        "kanamode" -> Ok("KanaMode")
        "kanjimode" -> Ok("KanjiMode")
        "katakana" -> Ok("Katakana")
        "romaji" -> Ok("Romaji")
        "zenkaku" -> Ok("Zenkaku")
        "zenkakuhankaku" -> Ok("ZenkakuHankaku")
        "soft1" -> Ok("Soft1")
        "soft2" -> Ok("Soft2")
        "soft3" -> Ok("Soft3")
        "soft4" -> Ok("Soft4")
        "appswitch" -> Ok("AppSwitch")
        "call" -> Ok("Call")
        "camera" -> Ok("Camera")
        "camerafocus" -> Ok("CameraFocus")
        "endcall" -> Ok("EndCall")
        "goback" -> Ok("GoBack")
        "gohome" -> Ok("GoHome")
        "headsethook" -> Ok("HeadsetHook")
        "lastnumberredial" -> Ok("LastNumberRedial")
        "notification" -> Ok("Notification")
        "mannermode" -> Ok("MannerMode")
        "voicedial" -> Ok("VoiceDial")
        "key11" -> Ok("Key11")
        "key12" -> Ok("Key12")
        "numpadbackspace" -> Ok("NumpadBackspace")
        "numpadclear" -> Ok("NumpadClear")
        "numpadclearentry" -> Ok("NumpadClearEntry")
        "numpadcomma" -> Ok("NumpadComma")
        "numpaddecimal" -> Ok("NumpadDecimal")
        "numpaddivide" -> Ok("NumpadDivide")
        "numpadenter" -> Ok("NumpadEnter")
        "numpadequal" -> Ok("NumpadEqual")
        "numpadhash" -> Ok("NumpadHash")
        "numpadmemoryadd" -> Ok("NumpadMemoryAdd")
        "numpadmemoryclear" -> Ok("NumpadMemoryClear")
        "numpadmemoryrecall" -> Ok("NumpadMemoryRecall")
        "numpadmemorystore" -> Ok("NumpadMemoryStore")
        "numpadmemorysubtract" -> Ok("NumpadMemorySubtract")
        "numpadmultiply" -> Ok("NumpadMultiply")
        "numpadparenleft" -> Ok("NumpadParenLeft")
        "numpadparenright" -> Ok("NumpadParenRight")
        "numpadstar" -> Ok("NumpadStar")
        "numpadsubtract" -> Ok("NumpadSubtract")
        "tv" -> Ok("TV")
        "tv3dmode" -> Ok("TV3DMode")
        "tvantennacable" -> Ok("TVAntennaCable")
        "tvaudiodescription" -> Ok("TVAudioDescription")
        "tvaudiodescriptionmixdown" -> Ok("TVAudioDescriptionMixDown")
        "tvaudiodescriptionmixup" -> Ok("TVAudioDescriptionMixUp")
        "tvcontentsmenu" -> Ok("TVContentsMenu")
        "tvdataservice" -> Ok("TVDataService")
        "tvinput" -> Ok("TVInput")
        "tvinputcomponent1" -> Ok("TVInputComponent1")
        "tvinputcomponent2" -> Ok("TVInputComponent2")
        "tvinputcomposite1" -> Ok("TVInputComposite1")
        "tvinputcomposite2" -> Ok("TVInputComposite2")
        "tvinputhdmi1" -> Ok("TVInputHDMI1")
        "tvinputhdmi2" -> Ok("TVInputHDMI2")
        "tvinputhdmi3" -> Ok("TVInputHDMI3")
        "tvinputhdmi4" -> Ok("TVInputHDMI4")
        "tvinputvga1" -> Ok("TVInputVGA1")
        "tvmediacontext" -> Ok("TVMediaContext")
        "tvnetwork" -> Ok("TVNetwork")
        "tvnumberentry" -> Ok("TVNumberEntry")
        "tvpower" -> Ok("TVPower")
        "tvradioservice" -> Ok("TVRadioService")
        "tvsatellite" -> Ok("TVSatellite")
        "tvsatellitebs" -> Ok("TVSatelliteBS")
        "tvsatellitecs" -> Ok("TVSatelliteCS")
        "tvsatellitetoggle" -> Ok("TVSatelliteToggle")
        "tvterrestrialanalog" -> Ok("TVTerrestrialAnalog")
        "tvterrestrialdigital" -> Ok("TVTerrestrialDigital")
        "tvtimer" -> Ok("TVTimer")
        "unidentified" -> Ok("Unidentified")
        "keya" -> Ok("KeyA")
        "keyb" -> Ok("KeyB")
        "keyc" -> Ok("KeyC")
        "keyd" -> Ok("KeyD")
        "keye" -> Ok("KeyE")
        "keyf" -> Ok("KeyF")
        "keyg" -> Ok("KeyG")
        "keyh" -> Ok("KeyH")
        "keyi" -> Ok("KeyI")
        "keyj" -> Ok("KeyJ")
        "keyk" -> Ok("KeyK")
        "keyl" -> Ok("KeyL")
        "keym" -> Ok("KeyM")
        "keyn" -> Ok("KeyN")
        "keyo" -> Ok("KeyO")
        "keyp" -> Ok("KeyP")
        "keyq" -> Ok("KeyQ")
        "keyr" -> Ok("KeyR")
        "keys" -> Ok("KeyS")
        "keyt" -> Ok("KeyT")
        "keyu" -> Ok("KeyU")
        "keyv" -> Ok("KeyV")
        "keyw" -> Ok("KeyW")
        "keyx" -> Ok("KeyX")
        "keyy" -> Ok("KeyY")
        "keyz" -> Ok("KeyZ")
        "digit0" -> Ok("Digit0")
        "digit1" -> Ok("Digit1")
        "digit2" -> Ok("Digit2")
        "digit3" -> Ok("Digit3")
        "digit4" -> Ok("Digit4")
        "digit5" -> Ok("Digit5")
        "digit6" -> Ok("Digit6")
        "digit7" -> Ok("Digit7")
        "digit8" -> Ok("Digit8")
        "digit9" -> Ok("Digit9")
        "shiftleft" -> Ok("ShiftLeft")
        "shiftright" -> Ok("ShiftRight")
        "controlleft" -> Ok("ControlLeft")
        "controlright" -> Ok("ControlRight")
        "altleft" -> Ok("AltLeft")
        "altright" -> Ok("AltRight")
        "metaleft" -> Ok("MetaLeft")
        "metaright" -> Ok("MetaRight")
        "minus" -> Ok("Minus")
        "equal" -> Ok("Equal")
        "bracketleft" -> Ok("BracketLeft")
        "bracketright" -> Ok("BracketRight")
        "backslash" -> Ok("Backslash")
        "semicolon" -> Ok("Semicolon")
        "quote" -> Ok("Quote")
        "backquote" -> Ok("Backquote")
        "comma" -> Ok("Comma")
        "period" -> Ok("Period")
        "slash" -> Ok("Slash")
        "numpad0" -> Ok("Numpad0")
        "numpad1" -> Ok("Numpad1")
        "numpad2" -> Ok("Numpad2")
        "numpad3" -> Ok("Numpad3")
        "numpad4" -> Ok("Numpad4")
        "numpad5" -> Ok("Numpad5")
        "numpad6" -> Ok("Numpad6")
        "numpad7" -> Ok("Numpad7")
        "numpad8" -> Ok("Numpad8")
        "numpad9" -> Ok("Numpad9")
        "numpadadd" -> Ok("NumpadAdd")
        _ -> Error(Nil)
      }
  }
}

/// Result of parsing a key combo string like "Shift+ArrowRight".
pub type ParsedKey {
  ParsedKey(
    /// The resolved key name in PascalCase wire format.
    key: String,
    shift: Bool,
    ctrl: Bool,
    alt: Bool,
    logo: Bool,
    command: Bool,
  )
}

/// Parse a key combo string into a resolved key name and modifiers.
///
/// Case-insensitive for both key names and modifiers. Validates the
/// key name against the full renderer key set. Panics on unknown keys
/// or modifiers -- this is test-only code where fail-fast is correct.
///
///     parse("Tab") -> ParsedKey(key: "Tab", ...)
///     parse("ctrl+s") -> ParsedKey(key: "s", ctrl: True, ...)
///     parse("Shift+ArrowRight") -> ParsedKey(key: "ArrowRight", shift: True, ...)
pub fn parse(key_str: String) -> ParsedKey {
  let parts = string.split(key_str, "+")
  let #(mods, key_parts) = list.split(parts, list.length(parts) - 1)
  let raw_key = case key_parts {
    [k] -> k
    _ -> key_str
  }

  let key_name = case resolve(raw_key) {
    Ok(resolved) -> resolved
    Error(_) ->
      panic as {
        "unknown key \""
        <> raw_key
        <> "\". Examples: Tab, ArrowRight, PageUp, Escape, Enter. "
        <> "See plushie/key.gleam for the full list."
      }
  }

  let has = fn(name) { list.any(mods, fn(m) { string.lowercase(m) == name }) }
  let ctrl = has("ctrl")
  ParsedKey(
    key: key_name,
    shift: has("shift"),
    ctrl:,
    alt: has("alt"),
    logo: has("logo"),
    command: has("command") || ctrl,
  )
}
