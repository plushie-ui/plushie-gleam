import gleam/option
import gleeunit/should
import plushie
import plushie/app
import plushie/cli/gui
import plushie/protocol
import plushie/subscription

// -- Tests for running.md compilable patterns ---------------------------------

// The running.md doc shows gui.run, gui.default_opts, and GuiOpts
// construction. We can't call gui.run (it blocks and needs a renderer),
// but we can verify the opts types compile and have expected defaults.

pub fn running_gui_default_opts_test() {
  let opts = gui.default_opts()
  should.equal(opts.json, False)
  should.equal(opts.daemon, False)
  should.equal(opts.dev, False)
}

pub fn running_gui_opts_with_dev_mode_test() {
  let opts = gui.GuiOpts(..gui.default_opts(), dev: True)
  should.equal(opts.dev, True)
  should.equal(opts.json, False)
}

// The running.md doc shows Settings with default_event_rate.

pub fn running_settings_default_event_rate_test() {
  let settings =
    app.Settings(..app.default_settings(), default_event_rate: option.Some(60))
  should.equal(settings.default_event_rate, option.Some(60))
}

pub fn running_settings_low_event_rate_test() {
  let settings =
    app.Settings(..app.default_settings(), default_event_rate: option.Some(15))
  should.equal(settings.default_event_rate, option.Some(15))
}

// The running.md doc shows subscriptions with max_rate.

pub fn running_subscription_mouse_move_with_rate_test() {
  let sub =
    subscription.on_mouse_move("mouse")
    |> subscription.set_max_rate(30)
  should.equal(subscription.get_max_rate(sub), option.Some(30))
}

pub fn running_subscription_animation_frame_with_rate_test() {
  let sub =
    subscription.on_animation_frame("frame")
    |> subscription.set_max_rate(60)
  should.equal(subscription.get_max_rate(sub), option.Some(60))
}

pub fn running_subscription_zero_rate_capture_only_test() {
  let sub =
    subscription.on_mouse_move("capture")
    |> subscription.set_max_rate(0)
  should.equal(subscription.get_max_rate(sub), option.Some(0))
}

// The running.md doc shows StartOpts with transport and daemon.

pub fn running_start_opts_stdio_daemon_test() {
  let start_opts =
    plushie.StartOpts(
      ..plushie.default_start_opts(),
      transport: plushie.Stdio,
      daemon: True,
    )
  should.equal(start_opts.daemon, True)
  case start_opts.transport {
    plushie.Stdio -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn running_start_opts_default_format_test() {
  let opts = plushie.default_start_opts()
  should.equal(opts.format, protocol.Msgpack)
  should.equal(opts.daemon, False)
}
