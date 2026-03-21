import gleam/dict
import gleam/int
import gleeunit/should
import toddy/data.{
  Asc, Desc, Filter, Group, Page, PageSize, Search, Sort, SortBy,
}

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

pub fn query_no_group_returns_empty_dict_test() {
  let result = data.query(sample_people(), [])
  should.equal(result.groups, dict.new())
}

pub fn query_group_by_city_test() {
  let result =
    data.query(sample_people(), [
      Group(fn(p: Person) { p.city }),
    ])
  // All 5 people, grouped by city
  should.equal(result.total, 5)

  let london = dict.get(result.groups, "London")
  should.be_ok(london)
  let assert Ok(london_people) = london
  let london_names = list.map(london_people, fn(p: Person) { p.name })
  should.equal(london_names, ["Alice", "Charlie"])

  let paris = dict.get(result.groups, "Paris")
  should.be_ok(paris)
  let assert Ok(paris_people) = paris
  let paris_names = list.map(paris_people, fn(p: Person) { p.name })
  should.equal(paris_names, ["Bob", "Eve"])

  let berlin = dict.get(result.groups, "Berlin")
  should.be_ok(berlin)
  let assert Ok(berlin_people) = berlin
  should.equal(list.length(berlin_people), 1)
}

pub fn query_group_with_pagination_test() {
  let result =
    data.query(sample_people(), [
      Group(fn(p: Person) { p.city }),
      Page(1),
      PageSize(3),
    ])
  // Only the first 3 entries are grouped (pagination happens before grouping)
  should.equal(list.length(result.entries), 3)
  // Groups are built from paginated entries only
  let group_count = dict.size(result.groups)
  should.be_true(group_count > 0)
}

import gleam/list

// ---------------------------------------------------------------------------
// Multi-column sort (tiebreaking)
// ---------------------------------------------------------------------------

pub fn query_multi_column_sort_test() {
  let people = [
    Person("Alice", 30, "London"),
    Person("Bob", 25, "London"),
    Person("Charlie", 25, "Berlin"),
    Person("Diana", 30, "Paris"),
  ]
  // Primary sort by age ascending, secondary by name ascending
  let result =
    data.query(people, [
      SortBy(direction: Asc, compare: fn(a: Person, b: Person) {
        int.compare(a.age, b.age)
      }),
      Sort(direction: Asc, key: fn(p: Person) { p.name }),
    ])
  let names = list.map(result.entries, fn(p: Person) { p.name })
  // Age 25: Bob, Charlie; Age 30: Alice, Diana
  should.equal(names, ["Bob", "Charlie", "Alice", "Diana"])
}

pub fn query_multi_column_sort_desc_tiebreak_test() {
  let people = [
    Person("Alice", 30, "London"),
    Person("Bob", 30, "London"),
    Person("Charlie", 25, "Berlin"),
  ]
  // Primary sort by age descending, secondary by name descending
  let result =
    data.query(people, [
      SortBy(direction: Desc, compare: fn(a: Person, b: Person) {
        int.compare(a.age, b.age)
      }),
      Sort(direction: Desc, key: fn(p: Person) { p.name }),
    ])
  let names = list.map(result.entries, fn(p: Person) { p.name })
  // Age 30 desc: Bob, Alice (name desc); Age 25: Charlie
  should.equal(names, ["Bob", "Alice", "Charlie"])
}
