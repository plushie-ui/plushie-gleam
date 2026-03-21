import gleam/dict
import gleeunit/should
import plushie/route

pub fn new_creates_single_entry_test() {
  let r = route.new("/home")
  should.equal(route.current(r), "/home")
  should.equal(route.can_go_back(r), False)
}

pub fn new_with_params_test() {
  let params = dict.from_list([#("id", "42")])
  let r = route.new_with_params("/users", params)
  should.equal(route.current(r), "/users")
  should.equal(route.params(r), params)
}

pub fn push_adds_to_stack_test() {
  let r =
    route.new("/home")
    |> route.push("/settings")
  should.equal(route.current(r), "/settings")
  should.equal(route.can_go_back(r), True)
}

pub fn push_with_params_test() {
  let params = dict.from_list([#("tab", "general")])
  let r =
    route.new("/home")
    |> route.push_with_params("/settings", params)
  should.equal(route.current(r), "/settings")
  should.equal(route.params(r), params)
}

pub fn pop_returns_to_previous_test() {
  let r =
    route.new("/home")
    |> route.push("/settings")
    |> route.pop()
  should.equal(route.current(r), "/home")
  should.equal(route.can_go_back(r), False)
}

pub fn pop_root_is_noop_test() {
  let r =
    route.new("/home")
    |> route.pop()
  should.equal(route.current(r), "/home")
}

pub fn history_returns_newest_first_test() {
  let r =
    route.new("/home")
    |> route.push("/a")
    |> route.push("/b")
  let hist = route.history(r)
  let paths = list.map(hist, fn(entry) { entry.0 })
  should.equal(paths, ["/b", "/a", "/home"])
}

pub fn params_default_empty_test() {
  let r = route.new("/home")
  should.equal(route.params(r), dict.new())
}

import gleam/list
