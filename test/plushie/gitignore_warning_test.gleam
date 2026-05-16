import gleeunit/should
import plushie/gitignore_warning.{Ignored, NotIgnored, NotInGitRepo}

pub fn status_not_in_git_repo_when_outside_work_tree_test() {
  let dir = setup_non_git_dir()
  run_in_dir(dir, fn() {
    gitignore_warning.status("bin")
    |> should.equal(NotInGitRepo)
  })
}

pub fn status_ignored_when_path_in_gitignore_test() {
  let dir = setup_git_repo_with_gitignore("/bin/\n")
  run_in_dir(dir, fn() {
    gitignore_warning.status("bin")
    |> should.equal(Ignored)
  })
}

pub fn status_not_ignored_when_path_missing_from_gitignore_test() {
  let dir = setup_git_repo_with_gitignore("# nothing relevant\n")
  run_in_dir(dir, fn() {
    gitignore_warning.status("bin")
    |> should.equal(NotIgnored)
  })
}

@external(erlang, "plushie_gitignore_test_helper", "setup_non_git_dir")
fn setup_non_git_dir() -> String

@external(erlang, "plushie_gitignore_test_helper", "setup_git_repo_with_gitignore")
fn setup_git_repo_with_gitignore(contents: String) -> String

@external(erlang, "plushie_gitignore_test_helper", "run_in_dir")
fn run_in_dir(dir: String, work: fn() -> Nil) -> Nil
