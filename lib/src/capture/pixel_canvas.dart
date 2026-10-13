import 'dart:math';
import 'dart:typed_data';

import '../encoding/encoder.dart';
import '../errors.dart';

/// Largest image, in bytes of RGBA, that is assembled in memory (512 MB).
const maxCanvasBytes = 512 * 1024 * 1024;

/// A CPU-side RGBA image that captured tiles are copied into. Used for
/// captures larger than one GPU texture.
class PixelCanvas {
  /// Allocates a transparent canvas, or throws [ScreenshotException] when it
  /// would exceed [maxCanvasBytes].
  factory PixelCanvas(int width, int height) {
    final bytes = width * height * 4;
    if (width <= 0 || height <= 0) {
      throw const ScreenshotException(
        ScreenshotFailure.notReady,
        'Nothing to capture: the area is empty',
      );
    }
    if (bytes > maxCanvasBytes) {
      throw ScreenshotException(
        ScreenshotFailure.tooLarge,
        'A ${width}x$height capture needs ${bytes ~/ (1024 * 1024)} MB; the '
        'limit is ${maxCanvasBytes ~/ (1024 * 1024)} MB. Lower pixelRatio or '
        'set maxWidth/maxHeight.',
      );
    }
    return PixelCanvas._(Uint8List(bytes), width, height);
  }

  PixelCanvas._(this._bytes, this.width, this.height);

  final Uint8List _bytes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Copies [source] so that its top-left pixel lands at ([dx], [dy]).
  /// Parts that fall outside the canvas are dropped.
  void draw(RgbaPixels source, int dx, int dy) {
    final x0 = max(0, dx);
    final y0 = max(0, dy);
    final x1 = min(width, dx + source.width);
    final y1 = min(height, dy + source.height);
    if (x0 >= x1 || y0 >= y1) return;
    final rowBytes = (x1 - x0) * 4;
    for (var y = y0; y < y1; y++) {
      final from = ((y - dy) * source.width + (x0 - dx)) * 4;
      final to = (y * width + x0) * 4;
      _bytes.setRange(to, to + rowBytes, source.bytes, from);
    }
  }

  /// The assembled pixels.
  RgbaPixels toPixels() => RgbaPixels(_bytes, width, height);
}
