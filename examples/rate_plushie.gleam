//// App rating page for plushie.
////
//// Demonstrates custom canvas widgets (StarRating, ThemeToggle) composed
//// with styled containers using the UI DSL. The "Dark humor" toggle
//// animates the emoji and flips the entire page theme.

import examples/widgets/star_rating
import examples/widgets/theme_toggle
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import plushie
import plushie/app
import plushie/command
import plushie/event.{
  type Event, CanvasShapeClick, CanvasShapeEnter, CanvasShapeLeave, KeyPress,
  TimerTick,
}
import plushie/node.{type Node}
import plushie/prop/alignment
import plushie/prop/border
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/subscription
import plushie/ui

// -- Review data --------------------------------------------------------------

type Review {
  Review(stars: Int, user: String, time: String, text: String)
}

const reviews = [
  Review(
    stars: 5,
    user: "gleam_fan_42",
    time: "2d ago",
    text: "Finally, native GUIs that don't make me want to cry.",
  ),
  Review(
    stars: 5,
    user: "jose_v",
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
    text: "Only uses 12MB of RAM. How am I supposed to justify my hardware?",
  ),
]

// -- Theme --------------------------------------------------------------------

type Theme {
  Theme(
    page_bg: String,
    card_bg: String,
    card_border: String,
    separator: String,
    text: String,
    text_secondary: String,
    text_muted: String,
  )
}

fn theme(dark: Bool) -> Theme {
  case dark {
    True ->
      Theme(
        page_bg: "#13131f",
        card_bg: "#1c1c32",
        card_border: "#2a2a4a",
        separator: "#2a2a4a",
        text: "#f0f0f5",
        text_secondary: "#9999bb",
        text_muted: "#555577",
      )
    False ->
      Theme(
        page_bg: "#f8f8fa",
        card_bg: "#ffffff",
        card_border: "#e0e0e0",
        separator: "#eeeeee",
        text: "#1a1a1a",
        text_secondary: "#666666",
        text_muted: "#aaaaaa",
      )
  }
}

// -- Model --------------------------------------------------------------------

type Model {
  Model(
    rating: Int,
    hover_star: Option(Int),
    toggle_progress: Float,
    toggle_target: Float,
  )
}

fn init() {
  #(
    Model(
      rating: 0,
      hover_star: option.None,
      toggle_progress: 0.0,
      toggle_target: 0.0,
    ),
    command.none(),
  )
}

// -- Update -------------------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    CanvasShapeClick(id: "stars", shape_id: shape_id, ..) ->
      case string.starts_with(shape_id, "star-") {
        True -> {
          let n = parse_star_index(shape_id)
          #(Model(..model, rating: n + 1), command.none())
        }
        False -> #(model, command.none())
      }

    CanvasShapeEnter(id: "stars", shape_id: shape_id, ..) ->
      case string.starts_with(shape_id, "star-") {
        True -> {
          let n = parse_star_index(shape_id)
          #(Model(..model, hover_star: option.Some(n + 1)), command.none())
        }
        False -> #(model, command.none())
      }

    CanvasShapeLeave(id: "stars", ..) -> #(
      Model(..model, hover_star: option.None),
      command.none(),
    )

    CanvasShapeClick(id: "theme-toggle", ..) -> {
      let target = case model.toggle_target == 0.0 {
        True -> 1.0
        False -> 0.0
      }
      #(Model(..model, toggle_target: target), command.none())
    }

    TimerTick(tag: "animate", ..) -> {
      let progress = approach(model.toggle_progress, model.toggle_target, 0.06)
      #(Model(..model, toggle_progress: progress), command.none())
    }

    KeyPress(key: "ArrowRight", ..) -> #(
      Model(..model, rating: int.min(model.rating + 1, 5)),
      command.none(),
    )

    KeyPress(key: "ArrowLeft", ..) -> #(
      Model(..model, rating: int.max(model.rating - 1, 0)),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

fn parse_star_index(shape_id: String) -> Int {
  let suffix = string.drop_start(shape_id, 5)
  case int.parse(suffix) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

fn approach(current: Float, target: Float, step: Float) -> Float {
  case current <. target {
    True -> float.min(current +. step, target)
    False ->
      case current >. target {
        True -> float.max(current -. step, target)
        False -> current
      }
  }
}

// -- Subscriptions ------------------------------------------------------------

fn subscribe(model: Model) -> List(subscription.Subscription) {
  let base = [subscription.on_key_press("key")]
  case model.toggle_progress != model.toggle_target {
    True -> [subscription.every(16, "animate"), ..base]
    False -> base
  }
}

// -- View ---------------------------------------------------------------------

fn view(model: Model) -> Node {
  let dark = model.toggle_progress >=. 0.5
  let t = theme(dark)

  ui.window("main", [ui.title("Rate Plushie")], [
    ui.container(
      "page",
      [
        ui.padding(padding.Padding(
          top: 32.0,
          bottom: 32.0,
          left: 24.0,
          right: 24.0,
        )),
        ui.background(hex(t.page_bg)),
        ui.width(length.Fill),
        ui.height(length.Fill),
      ],
      [
        ui.scrollable("scroll", [], [
          ui.column(
            "main-col",
            [
              ui.spacing(24),
              ui.width(length.Fill),
              ui.align_x(alignment.Center),
            ],
            [
              ui.text("heading", "Rate Plushie", [
                ui.font_size(28.0),
                ui.text_color(hex(t.text)),
              ]),
              rating_card(model, dark, t),
              ui.text("reviews-heading", "Reviews", [
                ui.font_size(20.0),
                ui.text_color(hex(t.text)),
              ]),
              reviews_card(t),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn rating_card(model: Model, dark: Bool, t: Theme) -> Node {
  ui.container(
    "rating-card",
    [
      ui.padding(padding.all(24.0)),
      ui.width(length.Fill),
      ui.border(
        border.new()
        |> border.width(1.0)
        |> border.color(hex(t.card_border))
        |> border.radius(12.0),
      ),
      ui.background(hex(t.card_bg)),
    ],
    [
      ui.column("card-col", [ui.spacing(20)], [
        ui.text("prompt", "How would you rate Plushie?", [
          ui.font_size(14.0),
          ui.text_color(hex(t.text_secondary)),
        ]),
        star_rating.render("stars", model.rating, model.hover_star, [
          star_rating.Dark(dark),
        ]),
        ui.rule("divider", []),
        ui.row("toggle-row", [ui.align_y(alignment.Center)], [
          ui.text("toggle-label", "Dark humor", [
            ui.text_color(hex(t.text_secondary)),
          ]),
          ui.space("toggle-spacer", [ui.width(length.Fill)]),
          theme_toggle.render("theme-toggle", model.toggle_progress, []),
        ]),
      ]),
    ],
  )
}

fn reviews_card(t: Theme) -> Node {
  ui.container(
    "reviews",
    [
      ui.border(
        border.new()
        |> border.width(1.0)
        |> border.color(hex(t.card_border))
        |> border.radius(12.0),
      ),
      ui.background(hex(t.card_bg)),
      ui.width(length.Fill),
      ui.clip(True),
    ],
    [
      ui.column(
        "reviews-col",
        [],
        reviews
          |> list.index_map(fn(review, i) {
            case i > 0 {
              True -> [
                ui.container(
                  "sep-" <> int.to_string(i),
                  [
                    ui.height(length.Fixed(1.0)),
                    ui.width(length.Fill),
                    ui.background(hex(t.separator)),
                  ],
                  [],
                ),
                review_row(review, t),
              ]
              False -> [review_row(review, t)]
            }
          })
          |> list.flatten,
      ),
    ],
  )
}

fn review_row(review: Review, t: Theme) -> Node {
  ui.container(
    "review-" <> review.user,
    [
      ui.padding(padding.Padding(
        top: 14.0,
        bottom: 14.0,
        left: 20.0,
        right: 20.0,
      )),
      ui.width(length.Fill),
    ],
    [
      ui.column(review.user <> "-body", [ui.spacing(6)], [
        ui.row(review.user <> "-header", [ui.spacing(8)], [
          ui.text(review.user <> "-stars", star_text(review.stars), [
            ui.font_size(12.0),
            ui.text_color(hex("#f59e0b")),
          ]),
          ui.text(review.user <> "-name", review.user, [
            ui.font_size(12.0),
            ui.text_color(hex(t.text_secondary)),
          ]),
          ui.space(review.user <> "-spacer", [ui.width(length.Fill)]),
          ui.text(review.user <> "-time", review.time, [
            ui.font_size(12.0),
            ui.text_color(hex(t.text_muted)),
          ]),
        ]),
        ui.text(
          review.user <> "-text",
          "\u{201C}" <> review.text <> "\u{201D}",
          [ui.font_size(14.0), ui.text_color(hex(t.text))],
        ),
      ]),
    ],
  )
}

fn star_text(n: Int) -> String {
  string.repeat("\u{2605}", n) <> string.repeat("\u{2606}", 5 - n)
}

fn hex(s: String) -> color.Color {
  let assert Ok(c) = color.from_hex(s)
  c
}

// -- Entry point --------------------------------------------------------------

pub fn main() {
  let my_app =
    app.simple(init, update, view)
    |> app.with_subscriptions(subscribe)
  let _ = plushie.start(my_app, plushie.default_start_opts())
  process.sleep_forever()
}
