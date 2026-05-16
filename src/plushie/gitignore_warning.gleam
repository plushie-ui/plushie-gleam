//// Friendly warning when a generated output directory is not gitignored.
////
//// Used by `plushie/download` and `plushie/package` to nudge users
//// to add the right entry to `.gitignore` so generated artifacts
//// don't end up committed. Silent when:
////
//// - not running inside a git work tree
//// - the path is already covered by `.gitignore`

@target(erlang)
import gleam/io

@target(erlang)
/// Emit a warning on stderr if `path` is inside a git work tree and is
/// not already gitignored. The path is interpreted relative to the
/// current working directory.
///
/// Silent when git is unavailable, when the cwd is not in a git work
/// tree, or when the path is already gitignored.
pub fn warn_if_not_gitignored(path: String) -> Nil {
  case status(path) {
    NotIgnored -> {
      io.println_error(
        "warning: "
        <> path
        <> "/ is not in .gitignore.\n"
        <> "  Recommended: add the following line so generated artifacts don't end\n"
        <> "  up committed:\n\n"
        <> "      /"
        <> path
        <> "/",
      )
    }
    NotInGitRepo -> Nil
    Ignored -> Nil
  }
}

@target(erlang)
pub type GitignoreStatus {
  NotInGitRepo
  Ignored
  NotIgnored
}

@target(erlang)
/// Pure status check exposed for testing. Same rules as
/// `warn_if_not_gitignored/1` but without the side effect.
@external(erlang, "plushie_gitignore_ffi", "status")
pub fn status(path: String) -> GitignoreStatus
