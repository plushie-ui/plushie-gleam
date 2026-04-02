import plushie/command
import plushie/effect

// -- File open effect --------------------------------------------------------

pub fn effects_file_open_returns_effect_command_test() {
  let cmd =
    effect.file_open("test", [
      effect.DialogTitle("Choose a file"),
      effect.Filters([#("Text files", "*.txt"), #("All files", "*")]),
    ])
  case cmd {
    command.Effect(kind: "file_open", ..) -> Nil
    _ -> panic as "expected Effect with kind file_open"
  }
}
