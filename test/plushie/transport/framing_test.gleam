import plushie/transport/framing.{type FramingError, BufferOverflow}

// --- encode_packet -----------------------------------------------------------

pub fn encode_packet_prepends_length_prefix_test() {
  let data = <<"hello":utf8>>
  let assert Ok(result) = framing.encode_packet(data)
  assert result == <<0, 0, 0, 5, "hello":utf8>>
}

pub fn encode_packet_empty_data_test() {
  let assert Ok(result) = framing.encode_packet(<<>>)
  assert result == <<0, 0, 0, 0>>
}

// Overflow on encode_packet and encode_line would require building
// a 64+ MiB payload in the test process; the decode-side tests below
// exercise the guard without that allocation.

// --- decode_packets ----------------------------------------------------------

pub fn decode_packets_single_complete_frame_test() {
  let buffer = <<0, 0, 0, 3, "abc":utf8>>
  let assert Ok(#(messages, remainder)) = framing.decode_packets(buffer)
  assert messages == [<<"abc":utf8>>]
  assert remainder == <<>>
}

pub fn decode_packets_multiple_complete_frames_test() {
  let buffer = <<0, 0, 0, 3, "abc":utf8, 0, 0, 0, 2, "de":utf8>>
  let assert Ok(#(messages, remainder)) = framing.decode_packets(buffer)
  assert messages == [<<"abc":utf8>>, <<"de":utf8>>]
  assert remainder == <<>>
}

pub fn decode_packets_partial_header_test() {
  let buffer = <<0, 0>>
  let assert Ok(#(messages, remainder)) = framing.decode_packets(buffer)
  assert messages == []
  assert remainder == <<0, 0>>
}

pub fn decode_packets_partial_payload_test() {
  let buffer = <<0, 0, 0, 5, "he":utf8>>
  let assert Ok(#(messages, remainder)) = framing.decode_packets(buffer)
  assert messages == []
  assert remainder == <<0, 0, 0, 5, "he":utf8>>
}

pub fn decode_packets_complete_then_partial_test() {
  let buffer = <<0, 0, 0, 2, "ok":utf8, 0, 0, 0, 5, "he":utf8>>
  let assert Ok(#(messages, remainder)) = framing.decode_packets(buffer)
  assert messages == [<<"ok":utf8>>]
  assert remainder == <<0, 0, 0, 5, "he":utf8>>
}

pub fn decode_packets_empty_buffer_test() {
  let assert Ok(#(messages, remainder)) = framing.decode_packets(<<>>)
  assert messages == []
  assert remainder == <<>>
}

pub fn decode_packets_zero_length_frame_test() {
  let buffer = <<0, 0, 0, 0, 0, 0, 0, 3, "abc":utf8>>
  let assert Ok(#(messages, remainder)) = framing.decode_packets(buffer)
  assert messages == [<<>>, <<"abc":utf8>>]
  assert remainder == <<>>
}

pub fn decode_packets_oversized_length_returns_error_test() {
  let oversize = framing.max_message_size + 1
  let header = <<oversize:size(32)-big>>
  let result = framing.decode_packets(header)
  assert_buffer_overflow(result, oversize)
}

// --- encode_line -------------------------------------------------------------

pub fn encode_line_appends_newline_test() {
  let assert Ok(result) = framing.encode_line(<<"hello":utf8>>)
  assert result == <<"hello\n":utf8>>
}

pub fn encode_line_empty_data_test() {
  let assert Ok(result) = framing.encode_line(<<>>)
  assert result == <<"\n":utf8>>
}

// --- decode_lines ------------------------------------------------------------

pub fn decode_lines_single_complete_line_test() {
  let buffer = <<"hello\n":utf8>>
  let assert Ok(#(lines, remainder)) = framing.decode_lines(buffer)
  assert lines == [<<"hello":utf8>>]
  assert remainder == <<>>
}

pub fn decode_lines_multiple_complete_lines_test() {
  let buffer = <<"abc\ndef\n":utf8>>
  let assert Ok(#(lines, remainder)) = framing.decode_lines(buffer)
  assert lines == [<<"abc":utf8>>, <<"def":utf8>>]
  assert remainder == <<>>
}

pub fn decode_lines_partial_line_test() {
  let buffer = <<"hello":utf8>>
  let assert Ok(#(lines, remainder)) = framing.decode_lines(buffer)
  assert lines == []
  assert remainder == <<"hello":utf8>>
}

pub fn decode_lines_complete_then_partial_test() {
  let buffer = <<"abc\nde":utf8>>
  let assert Ok(#(lines, remainder)) = framing.decode_lines(buffer)
  assert lines == [<<"abc":utf8>>]
  assert remainder == <<"de":utf8>>
}

pub fn decode_lines_empty_buffer_test() {
  let assert Ok(#(lines, remainder)) = framing.decode_lines(<<>>)
  assert lines == []
  assert remainder == <<>>
}

pub fn decode_lines_empty_line_test() {
  let buffer = <<"\nabc\n":utf8>>
  let assert Ok(#(lines, remainder)) = framing.decode_lines(buffer)
  assert lines == [<<>>, <<"abc":utf8>>]
  assert remainder == <<>>
}

// --- round-trip --------------------------------------------------------------

pub fn packet_round_trip_test() {
  let data = <<"round trip":utf8>>
  let assert Ok(encoded) = framing.encode_packet(data)
  let assert Ok(#(messages, remainder)) = framing.decode_packets(encoded)
  assert messages == [data]
  assert remainder == <<>>
}

pub fn line_round_trip_test() {
  let data = <<"round trip":utf8>>
  let assert Ok(encoded) = framing.encode_line(data)
  let assert Ok(#(lines, remainder)) = framing.decode_lines(encoded)
  assert lines == [data]
  assert remainder == <<>>
}

// --- helpers -----------------------------------------------------------------

fn assert_buffer_overflow(
  result: Result(a, FramingError),
  expected_size: Int,
) -> Nil {
  let assert Error(BufferOverflow(size:, limit:)) = result
  assert size == expected_size
  assert limit == framing.max_message_size
  Nil
}
