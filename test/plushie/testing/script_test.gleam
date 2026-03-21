import gleeunit/should
import plushie/testing/script

pub fn parse_basic_script_test() {
  let content =
    "app: counter
viewport: 800x600
theme: dark
backend: mock
-----
click \"#increment\"
expect \"Count: 1\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.header.app, "counter")
  should.equal(result.header.viewport, #(800, 600))
  should.equal(result.header.theme, "dark")
  should.equal(result.header.backend, script.MockBackend)
  should.equal(result.instructions, [
    script.Click("#increment"),
    script.Expect("Count: 1"),
  ])
}

pub fn parse_missing_separator_test() {
  let content = "app: counter\nclick \"#btn\""
  let assert Error(msg) = script.parse(content)
  should.be_true(
    msg == "missing ----- separator between header and instructions",
  )
}

pub fn parse_missing_app_test() {
  let content = "theme: dark\n-----\nclick \"#btn\""
  let assert Error(msg) = script.parse(content)
  should.be_true(msg == "header must include 'app:' field")
}

pub fn parse_all_actions_test() {
  let content =
    "app: test
-----
click \"#btn\"
type \"#input\" \"hello world\"
type \"enter\"
press \"a\"
release \"a\"
toggle \"#check\"
select \"#dropdown\" \"option1\"
slide \"#slider\" \"42\"
wait \"100\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.instructions, [
    script.Click("#btn"),
    script.TypeText("#input", "hello world"),
    script.TypeKey("enter"),
    script.Press("a"),
    script.Release("a"),
    script.Toggle("#check"),
    script.Select("#dropdown", "option1"),
    script.Slide("#slider", 42.0),
    script.Wait(100),
  ])
}

pub fn parse_assertions_test() {
  let content =
    "app: test
-----
expect \"Hello\"
tree_hash \"initial\"
screenshot \"main\"
assert_text \"#label\" \"world\"
assert_model \"count: 5\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.instructions, [
    script.Expect("Hello"),
    script.AssertTreeHash("initial"),
    script.AssertScreenshot("main"),
    script.AssertText("#label", "world"),
    script.AssertModel("count: 5"),
  ])
}

pub fn parse_comments_and_blanks_test() {
  let content =
    "app: test
# this is a comment
-----
# another comment
click \"#btn\"

expect \"done\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.instructions, [
    script.Click("#btn"),
    script.Expect("done"),
  ])
}

pub fn parse_move_to_coordinates_test() {
  let content = "app: test\n-----\nmove \"100,200\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.instructions, [script.MoveTo(100, 200)])
}

pub fn parse_move_selector_test() {
  let content = "app: test\n-----\nmove \"#widget\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.instructions, [script.Move("#widget")])
}

pub fn parse_headless_backend_test() {
  let content = "app: test\nbackend: headless\n-----\nclick \"#btn\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.header.backend, script.HeadlessBackend)
}

pub fn parse_default_viewport_test() {
  let content = "app: test\n-----\nclick \"#btn\""
  let assert Ok(result) = script.parse(content)
  should.equal(result.header.viewport, #(800, 600))
}
