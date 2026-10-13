/// Why a capture failed.
enum ScreenshotFailure {
  /// The `Screenshot` widget for this controller is not in the widget tree.
  notAttached,

  /// The widget has not been laid out or painted yet, or has zero size.
  notReady,

  /// The capture does not fit in memory or exceeds a platform limit.
  tooLarge,

  /// Encoding the image failed.
  encodingFailed,

  /// The scroll controller is not attached to exactly one scroll view.
  invalidScrollController,

  /// Native screen capture is not available on this platform.
  unsupportedPlatform,

  /// The platform reported an error while capturing.
  platformError,
}

/// Thrown by the `screenshot_kit` capture methods that return a result
/// instead of `null`.
class ScreenshotException implements Exception {
  /// Creates an exception for [reason] with a readable [message].
  const ScreenshotException(this.reason, this.message, {this.cause});

  /// What went wrong.
  final ScreenshotFailure reason;

  /// A readable explanation.
  final String message;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() {
    final suffix = cause == null ? '' : ' ($cause)';
    return 'ScreenshotException(${reason.name}): $message$suffix';
  }
}
