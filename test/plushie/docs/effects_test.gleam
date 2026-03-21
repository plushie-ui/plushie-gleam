import plushie/command
import plushie/effects

// -- File open effect --------------------------------------------------------

pub fn effects_file_open_returns_effect_command_test() {
  let cmd =
    effects.file_open([
      effects.DialogTitle("Choose a file"),
      effects.Filters([#("Text files", "*.txt"), #("All files", "*")]),
    ])
  case cmd {
    command.Effect(kind: "file_open", ..) -> Nil
    _ -> panic as "expected Effect with kind file_open"
  }
}
