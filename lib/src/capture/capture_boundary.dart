import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A repaint boundary whose contents can be captured, in whole or by region.
class CaptureBoundary extends SingleChildRenderObjectWidget {
  /// Creates a boundary around [child].
  const CaptureBoundary({super.key, super.child});

  @override
  RenderCaptureBoundary createRenderObject(BuildContext context) =>
      RenderCaptureBoundary();
}

/// Render object for [CaptureBoundary].
class RenderCaptureBoundary extends RenderRepaintBoundary {
  /// Creates the render object.
  RenderCaptureBoundary({super.child});

  /// Whether this boundary has been laid out, painted and has a size.
  bool get isReadyToCapture =>
      attached && hasSize && !size.isEmpty && layer != null;

  /// Captures [region], given in this box's logical coordinates, at
  /// [pixelRatio]. The region may extend beyond what is visible on screen.
  Future<ui.Image> toImageRegion(Rect region, {required double pixelRatio}) {
    final offsetLayer = layer! as OffsetLayer;
    return offsetLayer.toImage(region, pixelRatio: pixelRatio);
  }
}
