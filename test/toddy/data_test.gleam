import gleeunit/should
import toddy/data.{Asc, Desc, Filter, Page, PageSize, Search, Sort}

type Person {
  Person(name: String, age: Int, city: String)
}

fn sample_people() -> List(Person) {
  [
    Person("Alice", 30, "London"),
    Person("Bob", 25, "Paris"),
    Person("Charlie", 35, "London"),
    Person("Diana", 28, "Berlin"),
    Person("Eve", 22, "Paris"),
  ]
}

pub fn query_no_opts_returns_all_test() {
  let result = data.query(sample_people(), [])
  should.equal(result.total, 5)
  should.equal(list.length(result.entries), 5)
  should.equal(result.page, 1)
  should.equal(result.page_size, 25)
}

pub fn query_filter_test() {
  let result =
    data.query(sample_people(), [
      Filter(fn(p: Person) { p.city == "London" }),
    ])
  should.equal(result.total, 2)
  let names = list.map(result.entries, fn(p: Person) { p.name })
  should.equal(names, ["Alice", "Charlie"])
}

pub fn query_search_test() {
  let result =
    data.query(sample_people(), [
      Search(fields: [fn(p: Person) { p.name }], query: "ali"),
    ])
  should.equal(result.total, 1)
  let assert [person] = result.entries
  should.equal(person.name, "Alice")
}

pub fn query_search_case_insensitive_test() {
  let result =
    data.query(sample_people(), [
      Search(fields: [fn(p: Person) { p.name }], query: "BOB"),
    ])
  should.equal(result.total, 1)
}

pub fn query_sort_asc_test() {
  let result =
    data.query(sample_people(), [
      Sort(direction: Asc, key: fn(p: Person) { p.name }),
    ])
  let names = list.map(result.entries, fn(p: Person) { p.name })
  should.equal(names, ["Alice", "Bob", "Charlie", "Diana", "Eve"])
}

pub fn query_sort_desc_test() {
  let result =
    data.query(sample_people(), [
      Sort(direction: Desc, key: fn(p: Person) { p.name }),
    ])
  let names = list.map(result.entries, fn(p: Person) { p.name })
  should.equal(names, ["Eve", "Diana", "Charlie", "Bob", "Alice"])
}

pub fn query_pagination_test() {
  let result = data.query(sample_people(), [Page(2), PageSize(2)])
  should.equal(result.total, 5)
  should.equal(result.page, 2)
  should.equal(result.page_size, 2)
  should.equal(list.length(result.entries), 2)
  let names = list.map(result.entries, fn(p: Person) { p.name })
  should.equal(names, ["Charlie", "Diana"])
}

pub fn query_pagination_last_page_test() {
  let result = data.query(sample_people(), [Page(3), PageSize(2)])
  should.equal(list.length(result.entries), 1)
}

pub fn query_combined_filter_sort_page_test() {
  let people = [
    Person("Zara", 20, "London"),
    Person("Alice", 30, "London"),
    Person("Mike", 25, "London"),
    Person("Bob", 25, "Paris"),
  ]
  let result =
    data.query(people, [
      Filter(fn(p: Person) { p.city == "London" }),
      Sort(direction: Asc, key: fn(p: Person) { p.name }),
      Page(1),
      PageSize(2),
    ])
  should.equal(result.total, 3)
  let names = list.map(result.entries, fn(p: Person) { p.name })
  should.equal(names, ["Alice", "Mike"])
}

pub fn query_empty_list_test() {
  let result = data.query([], [Filter(fn(_: Person) { True })])
  should.equal(result.total, 0)
  should.equal(result.entries, [])
}

import gleam/list
