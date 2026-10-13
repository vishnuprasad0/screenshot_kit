/// Plugin registration for macOS, Windows and Linux, where every capture
/// works in Dart and nothing needs registering. Called by Flutter; you
/// don't need to use it.
abstract final class ScreenshotKitDesktop {
  /// Registers the plugin. Does nothing.
  static void registerWith() {}
}
