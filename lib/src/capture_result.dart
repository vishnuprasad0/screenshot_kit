import 'dart:typed_data';

/// Output format of a capture.
enum ImageFormat {
  /// Lossless PNG with transparency.
  png,

  /// JPEG. Transparent areas are filled with the background colour, or
  /// white when none is given.
  jpeg,

  /// Unencoded pixels: 4 bytes per pixel in RGBA order, straight (not
  /// premultiplied) alpha, row by row from the top.
  rawRgba,
}

/// The encoded image produced by a capture.
class CaptureResult {
  /// Creates a result.
  const CaptureResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });

  /// The image in [format].
  final Uint8List bytes;

  /// Width in physical pixels.
  final int width;

  /// Height in physical pixels.
  final int height;

  /// The format of [bytes].
  final ImageFormat format;

  @override
  String toString() =>
      'CaptureResult(${format.name}, ${width}x$height, ${bytes.length} bytes)';
}
