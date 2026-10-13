import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../capture_result.dart';
import '../errors.dart';

/// Straight-alpha RGBA pixels held in memory, row by row from the top.
class RgbaPixels {
  /// Wraps [bytes], which must hold `width * height * 4` bytes.
  RgbaPixels(this.bytes, this.width, this.height)
    : assert(bytes.length == width * height * 4);

  /// The pixel data.
  final Uint8List bytes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;
}

/// Reads [image] as straight-alpha RGBA.
Future<RgbaPixels> readPixels(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (data == null) {
    throw const ScreenshotException(
      ScreenshotFailure.encodingFailed,
      'Could not read the captured pixels',
    );
  }
  return RgbaPixels(data.buffer.asUint8List(), image.width, image.height);
}

/// Encodes [image]. PNG without a background uses the engine's encoder;
/// everything else is encoded off the UI thread.
Future<CaptureResult> encodeUiImage(
  ui.Image image, {
  required ImageFormat format,
  int quality = 90,
  ui.Color? background,
}) async {
  if (format == ImageFormat.png && background == null) {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const ScreenshotException(
        ScreenshotFailure.encodingFailed,
        'The engine could not encode the image as PNG',
      );
    }
    return CaptureResult(
      bytes: data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
      format: format,
    );
  }
  return encodePixels(
    await readPixels(image),
    format: format,
    quality: quality,
    background: background,
  );
}

/// Encodes [pixels] off the UI thread (on the web, in the same thread).
Future<CaptureResult> encodePixels(
  RgbaPixels pixels, {
  required ImageFormat format,
  int quality = 90,
  ui.Color? background,
}) async {
  RangeError.checkValueInInterval(quality, 1, 100, 'quality');
  final fill =
      background ??
      (format == ImageFormat.jpeg ? const ui.Color(0xFFFFFFFF) : null);
  try {
    final bytes = await compute(
      encodeRgba,
      EncodeRequest(
        pixels.bytes,
        pixels.width,
        pixels.height,
        format,
        quality,
        fill?.toARGB32(),
      ),
    );
    return CaptureResult(
      bytes: bytes,
      width: pixels.width,
      height: pixels.height,
      format: format,
    );
  } catch (e) {
    throw ScreenshotException(
      ScreenshotFailure.encodingFailed,
      'Could not encode the image as ${format.name}',
      cause: e,
    );
  }
}

/// Input for [encodeRgba]; sendable to another isolate.
@visibleForTesting
class EncodeRequest {
  /// Creates a request.
  const EncodeRequest(
    this.rgba,
    this.width,
    this.height,
    this.format,
    this.quality,
    this.backgroundArgb,
  );

  /// Straight-alpha RGBA pixels.
  final Uint8List rgba;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Target format.
  final ImageFormat format;

  /// JPEG quality, 1 to 100.
  final int quality;

  /// Colour drawn under the pixels as 0xAARRGGBB, or null for none.
  final int? backgroundArgb;
}

/// Applies the background and encodes. Runs in a background isolate.
@visibleForTesting
Uint8List encodeRgba(EncodeRequest request) {
  final background = request.backgroundArgb;
  final rgba = background == null
      ? request.rgba
      : composite(request.rgba, background);
  switch (request.format) {
    case ImageFormat.rawRgba:
      return rgba;
    case ImageFormat.png:
    case ImageFormat.jpeg:
      final image = img.Image.fromBytes(
        width: request.width,
        height: request.height,
        bytes: _exactBuffer(rgba),
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return request.format == ImageFormat.png
          ? img.encodePng(image)
          : img.encodeJpg(image, quality: request.quality);
  }
}

/// Draws straight-alpha [rgba] over a solid [backgroundArgb] colour
/// ("source over") and returns new straight-alpha pixels.
@visibleForTesting
Uint8List composite(Uint8List rgba, int backgroundArgb) {
  final bgA = (backgroundArgb >> 24) & 0xFF;
  final bgR = (backgroundArgb >> 16) & 0xFF;
  final bgG = (backgroundArgb >> 8) & 0xFF;
  final bgB = backgroundArgb & 0xFF;
  final out = Uint8List(rgba.length);
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a == 255) {
      out[i] = rgba[i];
      out[i + 1] = rgba[i + 1];
      out[i + 2] = rgba[i + 2];
      out[i + 3] = 255;
      continue;
    }
    // Background weight, in 0..255 * 255 units.
    final under = bgA * (255 - a);
    final outA255 = a * 255 + under;
    if (outA255 == 0) continue;
    out[i] = ((rgba[i] * a * 255 + bgR * under) / outA255).round();
    out[i + 1] = ((rgba[i + 1] * a * 255 + bgG * under) / outA255).round();
    out[i + 2] = ((rgba[i + 2] * a * 255 + bgB * under) / outA255).round();
    out[i + 3] = (outA255 / 255).round();
  }
  return out;
}

ByteBuffer _exactBuffer(Uint8List bytes) =>
    bytes.offsetInBytes == 0 &&
        bytes.lengthInBytes == bytes.buffer.lengthInBytes
    ? bytes.buffer
    : Uint8List.fromList(bytes).buffer;
