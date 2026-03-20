//// Stack-based navigation for multi-page apps.
////
//// Each entry is a path with associated params. The stack is LIFO;
//// the bottom entry (root) can never be popped.

import gleam/dict.{type Dict}
import gleam/list

/// A navigation route stack.
pub opaque type Route {
  Route(stack: List(#(String, Dict(String, String))))
}

/// Create a new route with an initial path.
pub fn new(path: String) -> Route {
  Route(stack: [#(path, dict.new())])
}

/// Create a new route with initial path and params.
pub fn new_with_params(path: String, params: Dict(String, String)) -> Route {
  Route(stack: [#(path, params)])
}

/// Push a new path onto the navigation stack.
pub fn push(route: Route, path: String) -> Route {
  Route(stack: [#(path, dict.new()), ..route.stack])
}

/// Push a new path with params.
pub fn push_with_params(
  route: Route,
  path: String,
  params: Dict(String, String),
) -> Route {
  Route(stack: [#(path, params), ..route.stack])
}

/// Pop the current path. Never pops the root entry.
pub fn pop(route: Route) -> Route {
  case route.stack {
    [_, ..rest] if rest != [] -> Route(stack: rest)
    _ -> route
  }
}

/// Get the current path.
pub fn current(route: Route) -> String {
  case route.stack {
    [#(path, _), ..] -> path
    [] -> ""
  }
}

/// Get the current path's params.
pub fn params(route: Route) -> Dict(String, String) {
  case route.stack {
    [#(_, p), ..] -> p
    [] -> dict.new()
  }
}

/// Check if navigation can go back (more than root entry).
pub fn can_go_back(route: Route) -> Bool {
  list.length(route.stack) > 1
}

/// Get the full navigation history (newest first).
pub fn history(route: Route) -> List(#(String, Dict(String, String))) {
  route.stack
}
