import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Plugin registration for the web, where every capture works in Dart and
/// nothing needs registering. Called by Flutter; you don't need to use it.
abstract final class ScreenshotKitWeb {
  /// Registers the plugin. Does nothing.
  static void registerWith(Registrar registrar) {}
}
