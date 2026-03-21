//// Parser for `.toddy` test scripts.
////
//// The `.toddy` format is a superset of iced's `.ice` test script format,
//// adding toddy-specific instructions like `expect` and `assert_model`.
////
//// ## Format
////
////     app: my_app
////     viewport: 800x600
////     theme: dark
////     backend: mock
////     -----
////     click "#increment"
////     expect "Count: 1"
////     tree_hash "counter-at-1"

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Script header metadata.
pub type Header {
  Header(app: String, viewport: #(Int, Int), theme: String, backend: Backend)
}

/// Backend selector.
pub type Backend {
  MockBackend
  HeadlessBackend
  WindowedBackend
}

/// A single instruction in a script.
pub type Instruction {
  Click(selector: String)
  TypeText(selector: String, text: String)
  TypeKey(key: String)
  Press(key: String)
  Release(key: String)
  Move(target: String)
  MoveTo(x: Int, y: Int)
  Toggle(selector: String)
  Select(selector: String, value: String)
  Slide(selector: String, value: Float)
  Expect(text: String)
  AssertTreeHash(name: String)
  AssertScreenshot(name: String)
  AssertText(selector: String, expected: String)
  AssertModel(expression: String)
  Wait(ms: Int)
}

/// A parsed script with header and instructions.
pub type Script {
  Script(header: Header, instructions: List(Instruction))
}

/// Parse a .toddy script from a file path.
pub fn parse_file(path: String) -> Result(Script, String) {
  case read_file(path) {
    Ok(content) -> parse(content)
    Error(_) -> Error("failed to read " <> path)
  }
}

/// Parse a .toddy script from a string.
pub fn parse(content: String) -> Result(Script, String) {
  case string.split_once(content, "-----") {
    Ok(#(header_section, body_section)) -> {
      use header <- result.try(parse_header(header_section))
      use instructions <- result.try(parse_instructions(body_section))
      Ok(Script(header:, instructions:))
    }
    Error(_) -> Error("missing ----- separator between header and instructions")
  }
}

// -- Header parsing ----------------------------------------------------------

fn parse_header(text: String) -> Result(Header, String) {
  let fields =
    text
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter(fn(line) { line != "" && !string.starts_with(line, "#") })
    |> list.fold([], fn(acc, line) {
      case string.split_once(line, ":") {
        Ok(#(key, value)) -> [#(string.trim(key), string.trim(value)), ..acc]
        Error(_) -> acc
      }
    })

  case find_field(fields, "app") {
    Some(app_str) -> {
      let viewport = case find_field(fields, "viewport") {
        Some(v) -> parse_viewport(v)
        None -> #(800, 600)
      }
      let theme = case find_field(fields, "theme") {
        Some(t) -> t
        None -> "dark"
      }
      let backend = case find_field(fields, "backend") {
        Some(b) -> parse_backend(b)
        None -> MockBackend
      }
      Ok(Header(app: app_str, viewport:, theme:, backend:))
    }
    None -> Error("header must include 'app:' field")
  }
}

fn find_field(fields: List(#(String, String)), key: String) -> Option(String) {
  case fields {
    [] -> None
    [#(k, v), ..rest] ->
      case k == key {
        True -> Some(v)
        False -> find_field(rest, key)
      }
  }
}

fn parse_viewport(str: String) -> #(Int, Int) {
  case string.split(str, "x") {
    [w, h] ->
      case int.parse(w), int.parse(h) {
        Ok(wi), Ok(hi) -> #(wi, hi)
        _, _ -> #(800, 600)
      }
    _ -> #(800, 600)
  }
}

fn parse_backend(str: String) -> Backend {
  case str {
    "mock" -> MockBackend
    "pooled_mock" -> MockBackend
    "headless" -> HeadlessBackend
    "windowed" -> WindowedBackend
    _ -> MockBackend
  }
}

// -- Instruction parsing -----------------------------------------------------

fn parse_instructions(text: String) -> Result(List(Instruction), String) {
  let lines =
    text
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter(fn(line) { line != "" && !string.starts_with(line, "#") })

  let results = list.map(lines, parse_instruction)
  let errors =
    list.filter_map(results, fn(r) {
      case r {
        Error(msg) -> Ok(msg)
        Ok(_) -> Error(Nil)
      }
    })

  case errors {
    [] ->
      Ok(
        list.filter_map(results, fn(r) {
          case r {
            Ok(instr) -> Ok(instr)
            Error(_) -> Error(Nil)
          }
        }),
      )
    _ -> Error(string.join(errors, "\n"))
  }
}

fn parse_instruction(line: String) -> Result(Instruction, String) {
  let tokens = tokenize(line)
  case parse_action(tokens) {
    Some(instr) -> Ok(instr)
    None ->
      case parse_assertion(tokens) {
        Some(instr) -> Ok(instr)
        None -> Error("unknown instruction: " <> line)
      }
  }
}

fn parse_action(tokens: List(String)) -> Option(Instruction) {
  case tokens {
    ["click", selector] -> Some(Click(selector))
    ["toggle", selector] -> Some(Toggle(selector))
    ["select", selector, value] -> Some(Select(selector, value))
    ["slide", selector, value_str] ->
      Some(Slide(selector, parse_number(value_str)))
    ["type", selector, text] -> Some(TypeText(selector, text))
    ["type", key] -> Some(TypeKey(key))
    ["press", key] -> Some(Press(key))
    ["release", key] -> Some(Release(key))
    ["move", target] -> Some(parse_move_target(target))
    ["wait", ms_str] ->
      case int.parse(ms_str) {
        Ok(ms) -> Some(Wait(ms))
        Error(_) -> None
      }
    _ -> None
  }
}

fn parse_assertion(tokens: List(String)) -> Option(Instruction) {
  case tokens {
    ["expect", text] -> Some(Expect(text))
    ["tree_hash", name] -> Some(AssertTreeHash(name))
    ["screenshot", name] -> Some(AssertScreenshot(name))
    ["assert_text", selector, text] -> Some(AssertText(selector, text))
    ["assert_model", expr] -> Some(AssertModel(expr))
    _ -> None
  }
}

fn parse_move_target(target: String) -> Instruction {
  case string.split(target, ",") {
    [x_str, y_str] ->
      case int.parse(string.trim(x_str)), int.parse(string.trim(y_str)) {
        Ok(x), Ok(y) -> MoveTo(x, y)
        _, _ -> Move(target)
      }
    _ -> Move(target)
  }
}

fn parse_number(str: String) -> Float {
  case float.parse(str) {
    Ok(f) -> f
    Error(_) ->
      case int.parse(str) {
        Ok(i) -> int.to_float(i)
        Error(_) -> 0.0
      }
  }
}

/// Tokenize a line, respecting quoted strings.
/// "click \"#foo\"" -> ["click", "#foo"]
fn tokenize(line: String) -> List(String) {
  do_tokenize(string.to_graphemes(line), False, "", [])
  |> list.reverse()
}

fn do_tokenize(
  chars: List(String),
  in_quote: Bool,
  current: String,
  tokens: List(String),
) -> List(String) {
  case chars {
    [] ->
      case current {
        "" -> tokens
        _ -> [current, ..tokens]
      }
    ["\"", ..rest] ->
      case in_quote {
        True -> {
          // End of quoted string -- push token
          do_tokenize(rest, False, "", [current, ..tokens])
        }
        False -> {
          // Start of quoted string
          do_tokenize(rest, True, current, tokens)
        }
      }
    [" ", ..rest] | ["\t", ..rest] ->
      case in_quote {
        True -> do_tokenize(rest, True, current <> " ", tokens)
        False ->
          case current {
            "" -> do_tokenize(rest, False, "", tokens)
            _ -> do_tokenize(rest, False, "", [current, ..tokens])
          }
      }
    [c, ..rest] -> do_tokenize(rest, in_quote, current <> c, tokens)
  }
}

// -- File system helper (reuse snapshot FFI) ----------------------------------

@external(erlang, "toddy_snapshot_ffi", "read_file")
fn read_file(path: String) -> Result(String, Nil)
