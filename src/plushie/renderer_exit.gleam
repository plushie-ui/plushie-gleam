//// Structured renderer exit reason.
////
//// When the renderer process exits (crash, shutdown, heartbeat timeout,
//// or connection loss), the bridge constructs a `RendererExit` value
//// describing what happened. The runtime passes this to the app's
//// `on_renderer_exit` callback so it can adjust the model before the
//// renderer restarts.

import gleam/option.{type Option}

/// Category of renderer exit reason.
pub type RendererExitType {
  /// Renderer process exited with a non-zero status code.
  Crash
  /// Lost connection to the renderer process.
  ConnectionLost
  /// Renderer shut down normally (exit status 0).
  Shutdown
  /// Renderer became unresponsive (heartbeat timeout).
  HeartbeatTimeout
}

/// Structured information about why the renderer process exited.
///
/// The `details` field carries the exit status code when available
/// (for `Crash`) and `None` otherwise.
pub type RendererExit {
  RendererExit(
    /// Category of exit reason.
    reason: RendererExitType,
    /// Human-readable description.
    message: String,
    /// Exit status code when available.
    details: Option(Int),
  )
}
