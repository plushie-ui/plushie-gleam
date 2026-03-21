import gleam/dict
import gleam/dynamic
import gleam/erlang/process
import gleeunit/should
import toddy/telemetry

pub fn execute_does_not_crash_test() {
  // Verify that calling execute with no handlers attached doesn't crash.
  telemetry.execute(
    ["toddy", "test", "noop"],
    dict.from_list([#("count", dynamic.int(1))]),
    dict.new(),
  )
}

pub fn attach_and_receive_test() {
  let self = process.new_subject()

  let assert Ok(_) =
    telemetry.attach(
      "test_attach_receive",
      ["toddy", "test", "ping"],
      fn(_event, measurements, _metadata) {
        process.send(self, measurements)
        Nil
      },
      dynamic.nil(),
    )

  telemetry.execute(
    ["toddy", "test", "ping"],
    dict.from_list([#("value", dynamic.int(42))]),
    dict.new(),
  )

  let assert Ok(received) = process.receive(self, 500)
  // The measurements dict should contain our value
  should.equal(dict.get(received, "value"), Ok(dynamic.int(42)))

  telemetry.detach("test_attach_receive")
}

pub fn detach_stops_delivery_test() {
  let self = process.new_subject()

  let assert Ok(_) =
    telemetry.attach(
      "test_detach",
      ["toddy", "test", "detach_check"],
      fn(_event, _measurements, _metadata) {
        process.send(self, "fired")
        Nil
      },
      dynamic.nil(),
    )

  telemetry.detach("test_detach")

  telemetry.execute(["toddy", "test", "detach_check"], dict.new(), dict.new())

  // Should NOT receive anything after detach
  should.equal(process.receive(self, 100), Error(Nil))
}

pub fn metadata_is_forwarded_test() {
  let self = process.new_subject()

  let assert Ok(_) =
    telemetry.attach(
      "test_metadata",
      ["toddy", "test", "meta"],
      fn(_event, _measurements, metadata) {
        process.send(self, metadata)
        Nil
      },
      dynamic.nil(),
    )

  telemetry.execute(
    ["toddy", "test", "meta"],
    dict.new(),
    dict.from_list([#("reason", dynamic.string("test_reason"))]),
  )

  let assert Ok(received) = process.receive(self, 500)
  should.equal(dict.get(received, "reason"), Ok(dynamic.string("test_reason")))

  telemetry.detach("test_metadata")
}

pub fn duplicate_handler_id_returns_error_test() {
  let handler = fn(_e, _m, _d) { Nil }

  let assert Ok(_) =
    telemetry.attach(
      "test_dup",
      ["toddy", "test", "dup"],
      handler,
      dynamic.nil(),
    )

  // Second attach with same ID should fail
  let result =
    telemetry.attach(
      "test_dup",
      ["toddy", "test", "dup"],
      handler,
      dynamic.nil(),
    )
  should.be_error(result)

  telemetry.detach("test_dup")
}
