import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../capture/capture_options.dart';
import '../capture_result.dart';
import '../encoding/encoder.dart';
import '../errors.dart';

/// Captures of the whole screen through the platform, which, unlike widget
/// captures, include platform views such as maps, web views and ads.
abstract final class ScreenshotKit {
  /// Channel to the Android and iOS implementations.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('screenshot_kit');

  /// Whether [captureScreen] works on this platform: Android and iOS.
  static bool get isScreenCaptureSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Captures the app's window as it is shown, including platform views
  /// (Google Maps, web views, video and ad views), the status bar area and
  /// any dialogs.
  ///
  /// Android and iOS only; elsewhere throws a [ScreenshotException] with
  /// [ScreenshotFailure.unsupportedPlatform]. On other platforms, wrap your
  /// app in a `Screenshot` widget and use `ScreenshotController.captureImage`.
  ///
  /// [maxWidth] and [maxHeight] scale the image down, keeping its aspect
  /// ratio. The native capture is always at the screen's full resolution.
  static Future<CaptureResult> captureScreen({
    ImageFormat format = ImageFormat.png,
    int quality = 90,
    int? maxWidth,
    int? maxHeight,
    ui.Color? background,
  }) async {
    if (!isScreenCaptureSupported) {
      throw const ScreenshotException(
        ScreenshotFailure.unsupportedPlatform,
        'Native screen capture is available on Android and iOS only',
      );
    }
    final options = CaptureOptions(
      format: format,
      quality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      background: background,
    );
    final Uint8List png;
    try {
      final result = await channel.invokeMethod<Uint8List>('captureScreen');
      if (result == null) throw PlatformException(code: 'empty');
      png = result;
    } on MissingPluginException catch (e) {
      throw ScreenshotException(
        ScreenshotFailure.unsupportedPlatform,
        'The screenshot_kit plugin is not registered; rebuild the app',
        cause: e,
      );
    } on PlatformException catch (e) {
      throw ScreenshotException(
        ScreenshotFailure.platformError,
        'The platform could not capture the screen: ${e.message ?? e.code}',
        cause: e,
      );
    }
    return transcodePng(png, options);
  }
}

/// Converts a PNG to the format and size in [options], returning it as is
/// when nothing changes.
@visibleForTesting
Future<CaptureResult> transcodePng(
  Uint8List png,
  CaptureOptions options,
) async {
  final (width, height) = pngSize(png);
  final scale = options.resolvePixelRatio(
    ui.Size(width.toDouble(), height.toDouble()),
    1,
  );
  if (options.format == ImageFormat.png &&
      options.background == null &&
      scale >= 1) {
    return CaptureResult(
      bytes: png,
      width: width,
      height: height,
      format: ImageFormat.png,
    );
  }
  final codec = await ui.instantiateImageCodec(
    png,
    targetWidth: scale < 1 ? (width * scale).round() : null,
    targetHeight: scale < 1 ? (height * scale).round() : null,
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  try {
    return await encodeUiImage(
      frame.image,
      format: options.format,
      quality: options.quality,
      background: options.background,
    );
  } finally {
    frame.image.dispose();
  }
}

/// Width and height from a PNG's header.
@visibleForTesting
(int, int) pngSize(Uint8List png) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (png.length < 24 ||
      !List.generate(8, (i) => png[i] == signature[i]).every((ok) => ok)) {
    throw const ScreenshotException(
      ScreenshotFailure.platformError,
      'The platform returned data that is not a PNG',
    );
  }
  final header = ByteData.sublistView(png, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}
