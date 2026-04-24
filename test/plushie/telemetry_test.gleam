import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process
import gleeunit/should
import plushie/platform
import plushie/telemetry

pub fn execute_does_not_crash_test() {
  // Verify that calling execute with no handlers attached doesn't crash.
  telemetry.execute(
    ["plushie", "test", "noop"],
    dict.from_list([#("count", dynamic.int(1))]),
    dict.new(),
  )
}

pub fn attach_and_receive_test() {
  let self = process.new_subject()

  let assert Ok(_) =
    telemetry.attach(
      "test_attach_receive",
      ["plushie", "test", "ping"],
      fn(_event, measurements, _metadata) {
        process.send(self, measurements)
        Nil
      },
      dynamic.nil(),
    )

  telemetry.execute(
    ["plushie", "test", "ping"],
    dict.from_list([#("byte_size", dynamic.int(42))]),
    dict.new(),
  )

  let assert Ok(received) = process.receive(self, 500)
  // The measurements dict should contain our whitelisted value.
  should.equal(dict.get(received, "byte_size"), Ok(dynamic.int(42)))

  telemetry.detach("test_attach_receive")
}

pub fn detach_stops_delivery_test() {
  let self = process.new_subject()

  let assert Ok(_) =
    telemetry.attach(
      "test_detach",
      ["plushie", "test", "detach_check"],
      fn(_event, _measurements, _metadata) {
        process.send(self, "fired")
        Nil
      },
      dynamic.nil(),
    )

  telemetry.detach("test_detach")

  telemetry.execute(["plushie", "test", "detach_check"], dict.new(), dict.new())

  // Should NOT receive anything after detach
  should.equal(process.receive(self, 100), Error(Nil))
}

pub fn metadata_is_forwarded_test() {
  let self = process.new_subject()

  let assert Ok(_) =
    telemetry.attach(
      "test_metadata",
      ["plushie", "test", "meta"],
      fn(_event, _measurements, metadata) {
        process.send(self, metadata)
        Nil
      },
      dynamic.nil(),
    )

  telemetry.execute(
    ["plushie", "test", "meta"],
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
      ["plushie", "test", "dup"],
      handler,
      dynamic.nil(),
    )

  // Second attach with same ID should fail
  let result =
    telemetry.attach(
      "test_dup",
      ["plushie", "test", "dup"],
      handler,
      dynamic.nil(),
    )
  should.be_error(result)

  telemetry.detach("test_dup")
}

@target(erlang)
pub fn unknown_event_segments_are_dropped_without_creating_atoms_test() {
  let unknown = "unknown_event_" <> platform.unique_id()
  let unknown_key = "unknown_key_" <> platform.unique_id()

  let before = atom_count()

  telemetry.execute(
    ["plushie", unknown, "ping"],
    dict.from_list([#(unknown_key, dynamic.int(1))]),
    dict.from_list([#(unknown_key, dynamic.string("ignored"))]),
  )

  atom_count()
  |> should.equal(before)
}

@target(erlang)
pub fn unknown_measurement_and_metadata_keys_are_dropped_test() {
  let self = process.new_subject()
  let unknown_measurement = "unknown_measurement_" <> platform.unique_id()
  let unknown_metadata = "unknown_metadata_" <> platform.unique_id()

  let assert Ok(_) =
    telemetry.attach(
      "test_unknown_keys",
      ["plushie", "test", "ping"],
      fn(_event, measurements, metadata) {
        process.send(self, #(measurements, metadata))
        Nil
      },
      dynamic.nil(),
    )

  let before = atom_count()

  telemetry.execute(
    ["plushie", "test", "ping"],
    dict.from_list([
      #("byte_size", dynamic.int(42)),
      #(unknown_measurement, dynamic.int(99)),
    ]),
    dict.from_list([
      #("reason", dynamic.string("known")),
      #(unknown_metadata, dynamic.string("ignored")),
    ]),
  )

  atom_count()
  |> should.equal(before)

  let assert Ok(#(measurements, metadata)) = process.receive(self, 500)
  dict.get(measurements, "byte_size")
  |> should.equal(Ok(dynamic.int(42)))
  dict.get(measurements, unknown_measurement)
  |> should.be_error
  dict.get(metadata, "reason")
  |> should.equal(Ok(dynamic.string("known")))
  dict.get(metadata, unknown_metadata)
  |> should.be_error

  telemetry.detach("test_unknown_keys")
}

@target(erlang)
pub fn attach_rejects_unknown_event_segments_without_creating_atoms_test() {
  let unknown = "unknown_attach_" <> platform.unique_id()
  let before = atom_count()

  let result =
    telemetry.attach(
      "test_unknown_attach",
      ["plushie", unknown],
      fn(_event, _measurements, _metadata) { Nil },
      dynamic.nil(),
    )

  result
  |> should.equal(Error(unknown_telemetry_event()))
  atom_count()
  |> should.equal(before)
}

@target(erlang)
pub fn known_segments_in_unknown_event_are_rejected_without_creating_atoms_test() {
  let self = process.new_subject()

  let result =
    telemetry.attach(
      "test_unknown_known_segments",
      ["plushie", "bridge", "update"],
      fn(_event, _measurements, _metadata) { Nil },
      dynamic.nil(),
    )

  result
  |> should.equal(Error(unknown_telemetry_event()))

  let assert Ok(_) =
    attach_bridge_update_telemetry_probe("test_bridge_update_probe", fn() {
      process.send(self, "fired")
      Nil
    })

  let before = atom_count()

  telemetry.execute(
    ["plushie", "bridge", "update"],
    dict.from_list([#("byte_size", dynamic.int(1))]),
    dict.new(),
  )

  should.equal(process.receive(self, 100), Error(Nil))
  telemetry.detach("test_bridge_update_probe")

  atom_count()
  |> should.equal(before)
}

@external(erlang, "plushie_test_ffi", "atom_count")
fn atom_count() -> Int

@external(erlang, "plushie_test_ffi", "unknown_telemetry_event")
fn unknown_telemetry_event() -> Dynamic

@external(erlang, "plushie_test_ffi", "attach_bridge_update_telemetry_probe")
fn attach_bridge_update_telemetry_probe(
  handler_id: String,
  handler: fn() -> Nil,
) -> Result(Nil, Dynamic)
