import gleam/dict
import gleam/option
import toddy/command
import toddy/effects
import toddy/node.{BoolVal, IntVal, StringVal}

pub fn file_open_creates_effect_command_test() {
  let cmd = effects.file_open([])
  case cmd {
    command.Effect(id:, kind:, ..) -> {
      assert kind == "file_open"
      assert id != ""
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn file_open_multiple_test() {
  let cmd = effects.file_open_multiple([])
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "file_open_multiple"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn file_save_creates_effect_command_test() {
  let cmd = effects.file_save([effects.DialogTitle("Save As")])
  case cmd {
    command.Effect(kind:, payload:, ..) -> {
      assert kind == "file_save"
      assert dict.get(payload, "title") == Ok(StringVal("Save As"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn file_dialog_default_path_test() {
  let cmd = effects.file_open([effects.DefaultPath("/home")])
  case cmd {
    command.Effect(payload:, ..) -> {
      assert dict.get(payload, "default_path") == Ok(StringVal("/home"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn file_dialog_filters_test() {
  let cmd = effects.file_open([effects.Filters([#("Images", "*.png;*.jpg")])])
  case cmd {
    command.Effect(payload:, ..) -> {
      assert dict.has_key(payload, "filters") == True
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn directory_select_test() {
  let cmd = effects.directory_select([])
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "directory_select"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn directory_select_multiple_test() {
  let cmd = effects.directory_select_multiple([])
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "directory_select_multiple"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_read_test() {
  let cmd = effects.clipboard_read()
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "clipboard_read"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_write_test() {
  let cmd = effects.clipboard_write("hello")
  case cmd {
    command.Effect(kind:, payload:, ..) -> {
      assert kind == "clipboard_write"
      assert dict.get(payload, "text") == Ok(StringVal("hello"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_read_html_test() {
  let cmd = effects.clipboard_read_html()
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "clipboard_read_html"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_write_html_with_alt_test() {
  let cmd = effects.clipboard_write_html("<b>hi</b>", option.Some("hi"))
  case cmd {
    command.Effect(kind:, payload:, ..) -> {
      assert kind == "clipboard_write_html"
      assert dict.get(payload, "html") == Ok(StringVal("<b>hi</b>"))
      assert dict.get(payload, "alt_text") == Ok(StringVal("hi"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_write_html_without_alt_test() {
  let cmd = effects.clipboard_write_html("<b>hi</b>", option.None)
  case cmd {
    command.Effect(payload:, ..) -> {
      assert dict.has_key(payload, "alt_text") == False
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_clear_test() {
  let cmd = effects.clipboard_clear()
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "clipboard_clear"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_read_primary_test() {
  let cmd = effects.clipboard_read_primary()
  case cmd {
    command.Effect(kind:, ..) -> {
      assert kind == "clipboard_read_primary"
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn clipboard_write_primary_test() {
  let cmd = effects.clipboard_write_primary("text")
  case cmd {
    command.Effect(kind:, payload:, ..) -> {
      assert kind == "clipboard_write_primary"
      assert dict.get(payload, "text") == Ok(StringVal("text"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn notification_creates_effect_command_test() {
  let cmd =
    effects.notification("Alert", "Something happened", [
      effects.Urgency(effects.Critical),
    ])
  case cmd {
    command.Effect(kind:, payload:, ..) -> {
      assert kind == "notification"
      assert dict.get(payload, "title") == Ok(StringVal("Alert"))
      assert dict.get(payload, "body") == Ok(StringVal("Something happened"))
      assert dict.get(payload, "urgency") == Ok(StringVal("critical"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn notification_with_all_opts_test() {
  let cmd =
    effects.notification("Title", "Body", [
      effects.NotifIcon("/icon.png"),
      effects.NotifTimeout(3000),
      effects.Urgency(effects.Low),
      effects.Sound(True),
    ])
  case cmd {
    command.Effect(payload:, ..) -> {
      assert dict.get(payload, "icon") == Ok(StringVal("/icon.png"))
      assert dict.get(payload, "timeout") == Ok(IntVal(3000))
      assert dict.get(payload, "urgency") == Ok(StringVal("low"))
      assert dict.get(payload, "sound") == Ok(BoolVal(True))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn notification_normal_urgency_test() {
  let cmd = effects.notification("T", "B", [effects.Urgency(effects.Normal)])
  case cmd {
    command.Effect(payload:, ..) -> {
      assert dict.get(payload, "urgency") == Ok(StringVal("normal"))
    }
    _ -> panic as "expected Effect command"
  }
}

pub fn unique_ids_per_effect_test() {
  let cmd1 = effects.file_open([])
  let cmd2 = effects.file_open([])
  let id1 = case cmd1 {
    command.Effect(id:, ..) -> id
    _ -> ""
  }
  let id2 = case cmd2 {
    command.Effect(id:, ..) -> id
    _ -> ""
  }
  assert id1 != id2
}
