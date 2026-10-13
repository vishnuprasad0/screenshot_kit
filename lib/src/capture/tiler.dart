import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../capture_result.dart';
import '../encoding/encoder.dart';
import '../errors.dart';
import 'capture_boundary.dart';
import 'capture_options.dart';
import 'pixel_canvas.dart';

/// Largest side, in physical pixels, captured in one GPU pass. Below the
/// texture limits of current renderers, including Impeller on mobile.
const maxTileExtent = 4096;

/// Size in physical pixels of [logical] at [pixelRatio].
(int, int) physicalSize(Size logical, double pixelRatio) => (
  (logical.width * pixelRatio).round(),
  (logical.height * pixelRatio).round(),
);

/// Captures [region] (the whole boundary when null) of [boundary] and
/// encodes it with [options].
///
/// Small captures are one GPU pass. Larger ones are captured in tiles of at
/// most [tileExtent] pixels and assembled on the CPU, so very long widgets
/// are not truncated by texture limits.
Future<CaptureResult> captureBoundary(
  RenderCaptureBoundary boundary,
  CaptureOptions options, {
  required double devicePixelRatio,
  Rect? region,
  int tileExtent = maxTileExtent,
}) async {
  if (!boundary.isReadyToCapture) {
    throw const ScreenshotException(
      ScreenshotFailure.notReady,
      'The widget has not been laid out and painted yet, or has zero size',
    );
  }
  final area = region ?? Offset.zero & boundary.size;
  final ratio = options.resolvePixelRatio(area.size, devicePixelRatio);
  final (width, height) = physicalSize(area.size, ratio);
  if (width <= tileExtent && height <= tileExtent) {
    final image = await boundary.toImageRegion(area, pixelRatio: ratio);
    try {
      return await encodeUiImage(
        image,
        format: options.format,
        quality: options.quality,
        background: options.background,
      );
    } finally {
      image.dispose();
    }
  }
  final pixels = await captureTiles(
    boundary,
    area,
    pixelRatio: ratio,
    tileExtent: tileExtent,
  );
  return encodePixels(
    pixels,
    format: options.format,
    quality: options.quality,
    background: options.background,
  );
}

/// Captures [area] of [boundary] tile by tile into CPU memory.
Future<RgbaPixels> captureTiles(
  RenderCaptureBoundary boundary,
  Rect area, {
  required double pixelRatio,
  int tileExtent = maxTileExtent,
}) async {
  final (width, height) = physicalSize(area.size, pixelRatio);
  final canvas = PixelCanvas(width, height);
  for (var y = 0; y < height; y += tileExtent) {
    for (var x = 0; x < width; x += tileExtent) {
      final tileWidth = min(tileExtent, width - x);
      final tileHeight = min(tileExtent, height - y);
      final tile = Rect.fromLTWH(
        area.left + x / pixelRatio,
        area.top + y / pixelRatio,
        tileWidth / pixelRatio,
        tileHeight / pixelRatio,
      );
      final image = await boundary.toImageRegion(tile, pixelRatio: pixelRatio);
      try {
        canvas.draw(await readPixels(image), x, y);
      } finally {
        image.dispose();
      }
    }
  }
  return canvas.toPixels();
}

/// Captures [area] of [boundary] as straight-alpha pixels, in one pass when
/// it fits a texture and in tiles otherwise.
Future<RgbaPixels> capturePixels(
  RenderCaptureBoundary boundary,
  Rect area, {
  required double pixelRatio,
  int tileExtent = maxTileExtent,
}) async {
  final (width, height) = physicalSize(area.size, pixelRatio);
  if (width > tileExtent || height > tileExtent) {
    return captureTiles(
      boundary,
      area,
      pixelRatio: pixelRatio,
      tileExtent: tileExtent,
    );
  }
  final ui.Image image = await boundary.toImageRegion(
    area,
    pixelRatio: pixelRatio,
  );
  try {
    return await readPixels(image);
  } finally {
    image.dispose();
  }
}
