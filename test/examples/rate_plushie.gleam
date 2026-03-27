//// App rating page for plushie.
////
//// Demonstrates custom canvas widgets (StarRating, ThemeToggle) composed
//// with styled containers using the UI DSL. The "Dark humor" toggle
//// animates the emoji and flips the entire page theme.
////
//// The review form showcases form validation with:
//// - Per-field error state tracked in the model
//// - Accessible error wiring via a11y (required, invalid, error_message)
//// - Validate-on-submit with clear-on-change for responsive UX

import examples/widgets/star_rating
import examples/widgets/theme_toggle
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import plushie
import plushie/app
import plushie/command
import plushie/event.{
  type Event, WidgetClick, WidgetEvent, WidgetInput, WidgetSubmit,
}
import plushie/node.{type Node, StringVal}
import plushie/prop/a11y
import plushie/prop/alignment
import plushie/prop/border
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/prop/theme
import plushie/subscription
import plushie/ui
import plushie/widget/column
import plushie/widget/container
import plushie/widget/row
import plushie/widget/space
import plushie/widget/text
import plushie/widget/text_editor
import plushie/widget/text_input
import plushie/widget/themer
import plushie/widget/window

// -- Review data --------------------------------------------------------------

pub type Review {
  Review(stars: Int, user: String, time: String, text: String)
}

const initial_reviews = [
  Review(
    stars: 5,
    user: "gleam_fan_42",
    time: "2d ago",
    text: "Finally, native GUIs that don't make me want to cry.",
  ),
  Review(
    stars: 5,
    user: "beam_me_up",
    time: "3d ago",
    text: "The Elm architecture feels right at home here.",
  ),
  Review(
    stars: 4,
    user: "rustacean",
    time: "5d ago",
    text: "Solid Iced wrapper. Docked a star because I had to write Gleam.",
  ),
  Review(
    stars: 3,
    user: "web_refugee",
    time: "1w ago",
    text: "Where is my CSS grid? Also it works perfectly. Three stars.",
  ),
  Review(
    stars: 5,
    user: "otp_enjoyer",
    time: "1w ago",
    text: "Let it crash, but make it beautiful.",
  ),
  Review(
    stars: 1,
    user: "electron_mass",
    time: "2w ago",
    text: "No browser engine. No JavaScript runtime. What am I even paying for?",
  ),
]

// -- Theme interpolation ------------------------------------------------------

type Theme {
  Theme(
    page_bg: String,
    card_bg: String,
    card_border: String,
    text: String,
    text_secondary: String,
    text_muted: String,
    error_text: String,
    error_border: String,
  )
}

fn build_theme(p: Float) -> Theme {
  Theme(
    page_bg: fade(#(248, 248, 250), #(19, 19, 31), p),
    card_bg: fade(#(255, 255, 255), #(28, 28, 50), p),
    card_border: fade(#(224, 224, 224), #(42, 42, 74), p),
    text: fade(#(26, 26, 26), #(240, 240, 245), p),
    text_secondary: fade(#(102, 102, 102), #(153, 153, 187), p),
    text_muted: fade(#(170, 170, 170), #(85, 85, 119), p),
    error_text: fade(#(185, 28, 28), #(255, 100, 100), p),
    error_border: fade(#(220, 38, 38), #(255, 80, 80), p),
  )
}

fn fade(c1: #(Int, Int, Int), c2: #(Int, Int, Int), t: Float) -> String {
  let r = float.round(int.to_float(c1.0) +. int.to_float(c2.0 - c1.0) *. t)
  let g = float.round(int.to_float(c1.1) +. int.to_float(c2.1 - c1.1) *. t)
  let b = float.round(int.to_float(c1.2) +. int.to_float(c2.2 - c1.2) *. t)
  "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b)
}

fn hex_byte(n: Int) -> String {
  let n = int.max(0, int.min(255, n))
  let high = n / 16
  let low = n % 16
  hex_digit(high) <> hex_digit(low)
}

fn hex_digit(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    _ -> "f"
  }
}

// -- Model --------------------------------------------------------------------

pub type Model {
  Model(
    rating: Int,
    dark_mode: Bool,
    reviews: List(Review),
    review_name: String,
    review_comment: String,
    errors: Dict(String, String),
  )
}

fn init() {
  #(
    Model(
      rating: 0,
      dark_mode: False,
      reviews: initial_reviews,
      review_name: "",
      review_comment: "",
      errors: dict.new(),
    ),
    command.none(),
  )
}

// -- Update -------------------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    // StarRating emits "select" with data = star count (1-5).
    WidgetEvent(kind: "select", id: "stars", data: data, ..) -> {
      let stars = coerce_int(data)
      #(
        Model(
          ..model,
          rating: stars,
          errors: dict.delete(model.errors, "rating"),
        ),
        command.none(),
      )
    }

    // ThemeToggle emits "toggle" with data = Bool.
    // Animation is managed internally by the canvas_widget.
    WidgetEvent(kind: "toggle", id: "theme-toggle", data: data, ..) -> {
      let dark = coerce_bool(data)
      #(Model(..model, dark_mode: dark), command.none())
    }

    // Review form inputs -- clear errors on change
    WidgetInput(window_id: "main", id: "review-name", value: v, ..) -> #(
      Model(..model, review_name: v, errors: dict.delete(model.errors, "name")),
      command.none(),
    )

    WidgetInput(window_id: "main", id: "review-comment", value: v, ..) -> #(
      Model(
        ..model,
        review_comment: v,
        errors: dict.delete(model.errors, "comment"),
      ),
      command.none(),
    )

    WidgetClick(window_id: "main", id: "submit-review", ..) -> #(
      submit_review(model),
      command.none(),
    )

    WidgetSubmit(window_id: "main", id: "review-name", ..) -> #(
      submit_review(model),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

fn submit_review(model: Model) -> Model {
  let errors = validate_review(model)

  case dict.size(errors) == 0 {
    True -> {
      let name = string.trim(model.review_name)
      let comment = string.trim(model.review_comment)
      let review =
        Review(stars: model.rating, user: name, time: "just now", text: comment)
      Model(
        ..model,
        reviews: [review, ..model.reviews],
        review_name: "",
        review_comment: "",
        rating: 0,
        errors: dict.new(),
      )
    }
    False -> Model(..model, errors: errors)
  }
}

fn validate_review(model: Model) -> Dict(String, String) {
  dict.new()
  |> validate_required("name", model.review_name, "Name is required")
  |> validate_required(
    "comment",
    model.review_comment,
    "Review text is required",
  )
  |> validate_rating(model.rating)
}

fn validate_required(
  errors: Dict(String, String),
  key: String,
  value: String,
  message: String,
) -> Dict(String, String) {
  case string.trim(value) == "" {
    True -> dict.insert(errors, key, message)
    False -> errors
  }
}

fn validate_rating(
  errors: Dict(String, String),
  rating: Int,
) -> Dict(String, String) {
  case rating > 0 {
    True -> errors
    False -> dict.insert(errors, "rating", "Please select a rating")
  }
}

// -- Subscriptions ------------------------------------------------------------

fn subscribe(_model: Model) -> List(subscription.Subscription) {
  []
}

// -- View ---------------------------------------------------------------------

fn view(model: Model) -> Node {
  let p = case model.dark_mode {
    True -> 1.0
    False -> 0.0
  }
  let t = build_theme(p)

  let page_theme =
    theme.custom(
      "rate-plushie",
      dict.from_list([
        #("background", StringVal(t.page_bg)),
        #("text", StringVal(t.text)),
        #("primary", StringVal(fade(#(59, 130, 246), #(139, 92, 246), p))),
      ]),
    )

  ui.window("main", [window.Title("Rate Plushie")], [
    themer.new("page-theme", page_theme)
    |> themer.extend([
      ui.container(
        "page",
        [
          container.Padding(padding.Padding(
            top: 32.0,
            bottom: 32.0,
            left: 24.0,
            right: 24.0,
          )),
          container.BgColor(hex(t.page_bg)),
          container.Width(length.Fill),
          container.Height(length.Fill),
        ],
        [
          ui.column(
            "main-col",
            [column.Spacing(24), column.Width(length.Fill)],
            [
              ui.text("heading", "Rate Plushie", [
                text.Size(28.0),
                text.Color(hex(t.text)),
                text.A11y(
                  a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(1),
                ),
              ]),
              rating_card(model, p, t),
              ui.text("reviews-heading", "Reviews", [
                text.Size(20.0),
                text.Color(hex(t.text)),
                text.A11y(
                  a11y.new() |> a11y.role(a11y.Heading) |> a11y.level(2),
                ),
              ]),
              reviews_list(model.reviews, p, t),
            ],
          ),
        ],
      ),
    ])
    |> themer.build(),
  ])
}

// -- View: rating card --------------------------------------------------------

fn rating_card(model: Model, p: Float, t: Theme) -> Node {
  ui.container(
    "rating-card",
    [
      container.Padding(padding.all(24.0)),
      container.Width(length.Fill),
      container.Border(
        border.new()
        |> border.width(1.0)
        |> border.color(hex(t.card_border))
        |> border.radius(12.0),
      ),
      container.BgColor(hex(t.card_bg)),
    ],
    [
      ui.column("card-col", [column.Spacing(20), column.Width(length.Fill)], [
        ui.text("prompt", "How would you rate Plushie?", [
          text.Size(14.0),
          text.Color(hex(t.text_secondary)),
        ]),
        ui.column("stars-group", [column.Spacing(4)], [
          star_rating.widget(
            "stars",
            star_rating.props(model.rating) |> star_rating.theme_progress(p),
          ),
          ..case dict.get(model.errors, "rating") {
            Ok(error) -> [
              ui.text("stars-error", error, [
                text.Size(12.0),
                text.Color(hex(t.error_text)),
                text.A11y(
                  a11y.new() |> a11y.role(a11y.Alert) |> a11y.live("polite"),
                ),
              ]),
            ]
            Error(_) -> []
          }
        ]),
        ui.rule("divider", []),
        review_form(model, t),
        theme_row(t),
      ]),
    ],
  )
}

// -- View: review form --------------------------------------------------------

fn review_form(model: Model, t: Theme) -> Node {
  let name_error = dict.get(model.errors, "name")
  let comment_error = dict.get(model.errors, "comment")

  ui.column("review-form", [column.Spacing(12), column.Width(length.Fill)], [
    ui.column("name-field", [column.Spacing(4), column.Width(length.Fill)], [
      ui.text_input("review-name", model.review_name, [
        text_input.Placeholder("Your name"),
        text_input.OnSubmit(True),
        text_input.A11y(
          a11y.new()
          |> a11y.label("Your name")
          |> a11y.required(True)
          |> a11y.invalid(name_error != Error(Nil))
          |> case name_error {
            Ok(_) -> a11y.error_message(_, "review-name-error")
            Error(_) -> fn(a) { a }
          },
        ),
      ]),
      ..case name_error {
        Ok(error) -> [
          ui.text("review-name-error", error, [
            text.Size(12.0),
            text.Color(hex(t.error_text)),
            text.A11y(
              a11y.new() |> a11y.role(a11y.Alert) |> a11y.live("polite"),
            ),
          ]),
        ]
        Error(_) -> []
      }
    ]),
    ui.column("comment-field", [column.Spacing(4), column.Width(length.Fill)], [
      text_editor.new("review-comment", model.review_comment)
        |> text_editor.placeholder("Write your review...")
        |> text_editor.height(length.Fixed(80.0))
        |> text_editor.a11y(
          a11y.new()
          |> a11y.label("Review text")
          |> a11y.required(True)
          |> a11y.invalid(comment_error != Error(Nil))
          |> case comment_error {
            Ok(_) -> a11y.error_message(_, "review-comment-error")
            Error(_) -> fn(a) { a }
          },
        )
        |> text_editor.build(),
      ..case comment_error {
        Ok(error) -> [
          ui.text("review-comment-error", error, [
            text.Size(12.0),
            text.Color(hex(t.error_text)),
            text.A11y(
              a11y.new() |> a11y.role(a11y.Alert) |> a11y.live("polite"),
            ),
          ]),
        ]
        Error(_) -> []
      }
    ]),
    ui.button_("submit-review", "Submit Review"),
  ])
}

// -- View: theme toggle row ---------------------------------------------------

fn theme_row(t: Theme) -> Node {
  ui.row("theme-row", [row.AlignY(alignment.Center)], [
    ui.space("theme-spacer", [space.Width(length.Fill)]),
    ui.text("toggle-label", "Dark humor", [
      text.Color(hex(t.text_secondary)),
    ]),
    theme_toggle.widget("theme-toggle"),
  ])
}

// -- View: reviews list -------------------------------------------------------

fn reviews_list(reviews: List(Review), p: Float, t: Theme) -> Node {
  ui.column(
    "reviews",
    [column.Spacing(0), column.Width(length.Fill)],
    reviews
      |> list.index_map(fn(review, i) {
        case i > 0 {
          True -> [
            ui.rule("sep-" <> int.to_string(i), []),
            review_card(review, i, p, t),
          ]
          False -> [review_card(review, i, p, t)]
        }
      })
      |> list.flatten,
  )
}

fn review_card(review: Review, i: Int, p: Float, t: Theme) -> Node {
  let idx = int.to_string(i)
  ui.column(
    "review-" <> idx,
    [
      column.Spacing(4),
      column.Padding(padding.all(12.0)),
      column.Width(length.Fill),
    ],
    [
      ui.row("rhdr-" <> idx, [row.Spacing(8), row.AlignY(alignment.Center)], [
        star_rating.widget(
          "rstars-" <> idx,
          star_rating.props(review.stars)
            |> star_rating.readonly(True)
            |> star_rating.scale(0.4)
            |> star_rating.theme_progress(p),
        ),
        ui.text("rname-" <> idx, review.user, [
          text.Size(12.0),
          text.Color(hex(t.text_secondary)),
        ]),
        ui.space("rsp-" <> idx, [space.Width(length.Fill)]),
        ui.text("rtime-" <> idx, review.time, [
          text.Size(12.0),
          text.Color(hex(t.text_muted)),
        ]),
      ]),
      ui.text("rtext-" <> idx, "\u{201C}" <> review.text <> "\u{201D}", [
        text.Size(14.0),
        text.Color(hex(t.text)),
      ]),
    ],
  )
}

fn hex(s: String) -> color.Color {
  let assert Ok(c) = color.from_hex(s)
  c
}

// -- Coercion helpers for Dynamic values from canvas_widget Emit --------------
// These are safe because we control the Emit data types in our own
// canvas_widget definitions and know the exact runtime type.

@external(erlang, "plushie_ffi", "identity")
fn coerce_int(a: Dynamic) -> Int

@external(erlang, "plushie_ffi", "identity")
fn coerce_bool(a: Dynamic) -> Bool

// -- Entry point --------------------------------------------------------------

pub fn app() {
  app.simple(init, update, view)
  |> app.with_subscriptions(subscribe)
}

pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      plushie.start_error_to_string(err)
      |> string.append("Failed to start: ", _)
      |> panic
  }
}
