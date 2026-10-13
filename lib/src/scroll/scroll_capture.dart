import 'package:flutter/widgets.dart';

import '../capture/capture_boundary.dart';
import '../capture/capture_options.dart';
import '../capture/pixel_canvas.dart';
import '../capture/settle.dart';
import '../capture/tiler.dart';
import '../capture_result.dart';
import '../encoding/encoder.dart';
import '../errors.dart';

/// Captures the full content of the scroll view driven by [controller],
/// which must be inside [boundary].
///
/// Scrolls one viewport at a time, captures the viewport, and stitches the
/// pieces into one image. Only the viewport is captured, so app bars or
/// other widgets around the scroll view inside the boundary are left out.
/// The original scroll position is restored afterwards.
Future<CaptureResult> captureScrollView(
  RenderCaptureBoundary boundary,
  ScrollController controller,
  CaptureOptions options, {
  required double devicePixelRatio,
  Duration imageTimeout = const Duration(seconds: 10),
}) async {
  if (!controller.hasClients || controller.positions.length != 1) {
    throw const ScreenshotException(
      ScreenshotFailure.invalidScrollController,
      'The ScrollController must be attached to exactly one scroll view',
    );
  }
  final position = controller.position;
  final viewportBox = position.context.notificationContext?.findRenderObject();
  if (viewportBox is! RenderBox || !boundary.isReadyToCapture) {
    throw const ScreenshotException(
      ScreenshotFailure.notReady,
      'The scroll view has not been laid out yet',
    );
  }
  if (!_isDescendant(viewportBox, boundary)) {
    throw const ScreenshotException(
      ScreenshotFailure.invalidScrollController,
      'The scroll view must be inside the Screenshot widget',
    );
  }

  final original = position.pixels;
  try {
    final end = await _settleEnd(position);
    final start = position.minScrollExtent;
    final viewport = position.viewportDimension;
    final vertical = position.axis == Axis.vertical;
    final viewportRect =
        viewportBox.localToGlobal(Offset.zero, ancestor: boundary) &
        viewportBox.size;
    final content = end - start + viewport;
    final logicalSize = vertical
        ? Size(viewportRect.width, content)
        : Size(content, viewportRect.height);
    final ratio = options.resolvePixelRatio(logicalSize, devicePixelRatio);
    final (width, height) = physicalSize(logicalSize, ratio);
    final canvas = PixelCanvas(width, height);

    var offset = start;
    double? previous;
    while (true) {
      position.jumpTo(offset);
      await nextFrame();
      if (await precacheImages(
        position.context.notificationContext! as Element,
        imageTimeout,
      )) {
        await nextFrame();
      }
      final shown = position.pixels;
      final pixels = await capturePixels(
        boundary,
        viewportRect,
        pixelRatio: ratio,
      );
      final at = ((shown - start) * ratio).round();
      canvas.draw(pixels, vertical ? 0 : at, vertical ? at : 0);
      // Stop at the end, or if the position refuses to move further.
      if (shown >= end || (previous != null && shown <= previous)) break;
      previous = shown;
      offset = shown + viewport < end ? shown + viewport : end;
    }
    return encodePixels(
      canvas.toPixels(),
      format: options.format,
      quality: options.quality,
      background: options.background,
    );
  } finally {
    if (controller.hasClients) {
      position.jumpTo(original);
    }
  }
}

/// Lazy lists only know their real extent once the end has been built, so
/// jump to the end until the maximum stops changing.
Future<double> _settleEnd(ScrollPosition position) async {
  var end = position.maxScrollExtent;
  for (var i = 0; i < 20; i++) {
    position.jumpTo(end);
    await nextFrame();
    if (position.maxScrollExtent == end) break;
    end = position.maxScrollExtent;
  }
  return end;
}

bool _isDescendant(RenderObject child, RenderObject ancestor) {
  RenderObject? node = child;
  while (node != null) {
    if (identical(node, ancestor)) return true;
    node = node.parent;
  }
  return false;
}
