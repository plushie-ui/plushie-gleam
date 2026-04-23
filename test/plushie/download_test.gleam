import gleeunit/should
import plushie/download

pub fn release_url_uses_version_argument_test() {
  should.equal(
    download.release_url("9.8.7", "plushie-renderer-linux-x86_64"),
    "https://github.com/plushie-ui/plushie-renderer/releases/download/v9.8.7/plushie-renderer-linux-x86_64",
  )
}
