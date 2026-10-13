import 'dart:math';
import 'dart:ui';

import '../capture_result.dart';

/// Output settings shared by every capture method.
class CaptureOptions {
  /// Creates options; see the capture methods for what each one does.
  const CaptureOptions({
    this.format = ImageFormat.png,
    this.quality = 90,
    this.pixelRatio,
    this.maxWidth,
    this.maxHeight,
    this.background,
  }) : assert(quality >= 1 && quality <= 100),
       assert(maxWidth == null || maxWidth > 0),
       assert(maxHeight == null || maxHeight > 0);

  /// Output format.
  final ImageFormat format;

  /// JPEG quality, 1 to 100.
  final int quality;

  /// Physical pixels per logical pixel; the device's ratio when null.
  final double? pixelRatio;

  /// Upper bound for the output width, in pixels.
  final int? maxWidth;

  /// Upper bound for the output height, in pixels.
  final int? maxHeight;

  /// Colour drawn under transparent areas.
  final Color? background;

  /// The pixel ratio to capture [logicalSize] with: [pixelRatio] or
  /// [devicePixelRatio], lowered so the output fits [maxWidth] and
  /// [maxHeight] without resampling.
  double resolvePixelRatio(Size logicalSize, double devicePixelRatio) {
    var ratio = pixelRatio ?? devicePixelRatio;
    final width = maxWidth;
    final height = maxHeight;
    if (width != null && logicalSize.width > 0) {
      ratio = min(ratio, width / logicalSize.width);
    }
    if (height != null && logicalSize.height > 0) {
      ratio = min(ratio, height / logicalSize.height);
    }
    return ratio;
  }
}
