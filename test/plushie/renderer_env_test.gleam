import gleeunit/should
import plushie/renderer_env

pub fn allows_exact_canonical_vars_test() {
  should.equal(renderer_env.is_allowed("DISPLAY"), True)
  should.equal(renderer_env.is_allowed("PATH"), True)
  should.equal(renderer_env.is_allowed("HOME"), True)
  should.equal(renderer_env.is_allowed("RUST_LOG"), True)
  should.equal(renderer_env.is_allowed("WGPU_BACKEND"), True)
  should.equal(renderer_env.is_allowed("XDG_RUNTIME_DIR"), True)
  should.equal(renderer_env.is_allowed("DBUS_SESSION_BUS_ADDRESS"), True)
}

pub fn allows_prefix_canonical_vars_test() {
  should.equal(renderer_env.is_allowed("LC_ALL"), True)
  should.equal(renderer_env.is_allowed("MESA_GL_VERSION_OVERRIDE"), True)
  should.equal(renderer_env.is_allowed("VK_ICD_FILENAMES"), True)
  should.equal(renderer_env.is_allowed("FONTCONFIG_PATH"), True)
  should.equal(renderer_env.is_allowed("AT_SPI_BUS_ADDRESS"), True)
}

pub fn allows_plushie_prefix_test() {
  should.equal(renderer_env.is_allowed("PLUSHIE_NO_CATCH_UNWIND"), True)
  should.equal(renderer_env.is_allowed("PLUSHIE_DEBUG_FOO"), True)
}

pub fn rejects_secrets_and_unrelated_vars_test() {
  should.equal(renderer_env.is_allowed("AWS_ACCESS_KEY_ID"), False)
  should.equal(renderer_env.is_allowed("GITHUB_TOKEN"), False)
  should.equal(renderer_env.is_allowed("DATABASE_URL"), False)
  should.equal(renderer_env.is_allowed("SSH_AUTH_SOCK"), False)
  should.equal(renderer_env.is_allowed("SECRET_KEY_BASE"), False)
  // Dropped-from-old-broader-list entries: these are no longer allowed.
  should.equal(renderer_env.is_allowed("DRI_PRIME"), False)
  should.equal(renderer_env.is_allowed("SHELL"), False)
}
