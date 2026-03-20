//// Data query pipeline for filtering, searching, sorting, and
//// paginating in-memory record collections.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string

/// Query result.
pub type QueryResult(a) {
  QueryResult(entries: List(a), total: Int, page: Int, page_size: Int)
}

/// Sort direction.
pub type SortDirection {
  Asc
  Desc
}

/// Query options.
pub type QueryOpt(a) {
  Filter(fn(a) -> Bool)
  Search(fields: List(fn(a) -> String), query: String)
  Sort(direction: SortDirection, key: fn(a) -> String)
  Page(Int)
  PageSize(Int)
}

/// Run a query pipeline on a list of records.
pub fn query(records: List(a), opts: List(QueryOpt(a))) -> QueryResult(a) {
  let filter_fn = find_filter(opts)
  let search = find_search(opts)
  let sort = find_sort(opts)
  let page = find_page(opts)
  let page_size = find_page_size(opts)

  // Apply pipeline: filter -> search -> sort -> paginate
  let result = records
  let result = case filter_fn {
    Some(f) -> list.filter(result, f)
    None -> result
  }
  let result = case search {
    Some(#(fields, q)) -> {
      let q_lower = string.lowercase(q)
      list.filter(result, fn(record) {
        list.any(fields, fn(field) {
          string.contains(string.lowercase(field(record)), q_lower)
        })
      })
    }
    None -> result
  }
  let result = case sort {
    Some(#(dir, key_fn)) -> {
      list.sort(result, fn(a, b) {
        let ka = key_fn(a)
        let kb = key_fn(b)
        let cmp = string.compare(ka, kb)
        case dir {
          Asc -> cmp
          Desc -> order.negate(cmp)
        }
      })
    }
    None -> result
  }
  let total = list.length(result)
  let result = paginate(result, page, page_size)
  QueryResult(entries: result, total:, page:, page_size:)
}

fn paginate(items: List(a), page: Int, page_size: Int) -> List(a) {
  let skip = { page - 1 } * page_size
  items
  |> list.drop(skip)
  |> list.take(page_size)
}

fn find_filter(opts: List(QueryOpt(a))) -> Option(fn(a) -> Bool) {
  list.find_map(opts, fn(opt) {
    case opt {
      Filter(f) -> Ok(f)
      _ -> Error(Nil)
    }
  })
  |> option.from_result()
}

fn find_search(
  opts: List(QueryOpt(a)),
) -> Option(#(List(fn(a) -> String), String)) {
  list.find_map(opts, fn(opt) {
    case opt {
      Search(fields:, query:) -> Ok(#(fields, query))
      _ -> Error(Nil)
    }
  })
  |> option.from_result()
}

fn find_sort(
  opts: List(QueryOpt(a)),
) -> Option(#(SortDirection, fn(a) -> String)) {
  list.find_map(opts, fn(opt) {
    case opt {
      Sort(direction:, key:) -> Ok(#(direction, key))
      _ -> Error(Nil)
    }
  })
  |> option.from_result()
}

fn find_page(opts: List(QueryOpt(a))) -> Int {
  list.find_map(opts, fn(opt) {
    case opt {
      Page(p) -> Ok(p)
      _ -> Error(Nil)
    }
  })
  |> result.unwrap(or: 1)
}

fn find_page_size(opts: List(QueryOpt(a))) -> Int {
  list.find_map(opts, fn(opt) {
    case opt {
      PageSize(ps) -> Ok(ps)
      _ -> Error(Nil)
    }
  })
  |> result.unwrap(or: 25)
}
