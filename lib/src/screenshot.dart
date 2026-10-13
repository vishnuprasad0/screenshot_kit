import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'capture/capture_boundary.dart';
import 'capture/capture_options.dart';
import 'capture/in_tree_render.dart';
import 'capture/isolated_render.dart';
import 'capture/settle.dart';
import 'capture/tiler.dart';
import 'capture_result.dart';
import 'compat/file_saver.dart';
import 'errors.dart';
import 'scroll/scroll_capture.dart';

/// Captures the [Screenshot] widget it is attached to, or any widget given to
/// it, as an image.
///
/// The methods `capture`, `captureAsUiImage`, `captureAndSave`,
/// `captureFromWidget`, `captureFromLongWidget`, `widgetToUiImage` and
/// `longWidgetToUiImage` keep the signatures of the `screenshot` package, so
/// switching only needs a new import. The newer methods ([captureImage],
/// [captureWidget], [captureScrollable]) add formats and resizing and throw a
/// [ScreenshotException] with a reason instead of returning null.
class ScreenshotController {
  /// Creates a controller. Attach it to one [Screenshot] widget.
  ScreenshotController();

  final GlobalKey _containerKey = GlobalKey();

  BuildContext? get _context => _containerKey.currentContext;

  // ---------------------------------------------------------------------
  // New API
  // ---------------------------------------------------------------------

  /// Captures the attached [Screenshot] widget.
  ///
  /// Waits up to [imageTimeout] for images inside it to load, then for the
  /// frame to finish, so no fixed delay is needed. Use [delay] only to let an
  /// animation finish first. Widgets of any length are captured in full.
  ///
  /// - [format] and [quality]: PNG, JPEG (quality 1 to 100) or raw RGBA.
  /// - [pixelRatio]: physical pixels per logical pixel; the device's ratio
  ///   by default.
  /// - [maxWidth] and [maxHeight]: lower the pixel ratio so the image fits.
  /// - [background]: colour drawn under transparent areas.
  Future<CaptureResult> captureImage({
    ImageFormat format = ImageFormat.png,
    int quality = 90,
    double? pixelRatio,
    int? maxWidth,
    int? maxHeight,
    Color? background,
    Duration delay = Duration.zero,
    Duration imageTimeout = const Duration(seconds: 10),
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final boundary = await _readyBoundary(imageTimeout);
    return captureBoundary(
      boundary,
      CaptureOptions(
        format: format,
        quality: quality,
        pixelRatio: pixelRatio,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        background: background,
      ),
      devicePixelRatio: _devicePixelRatio(_context),
    );
  }

  /// Captures [widget] without showing it.
  ///
  /// With a [context], the widget is rendered off-screen at the nearest
  /// [ScreenshotHost] or [Overlay] above it, so it can use your providers,
  /// localizations, theme and media query. Without one it is rendered in an
  /// isolated pipeline that has none of those.
  ///
  /// [constraints] default to the screen size; pass, for example,
  /// `BoxConstraints(maxWidth: 400)` to capture something taller than the
  /// screen. See [captureImage] for the other parameters.
  Future<CaptureResult> captureWidget(
    Widget widget, {
    BuildContext? context,
    BoxConstraints? constraints,
    ImageFormat format = ImageFormat.png,
    int quality = 90,
    double? pixelRatio,
    int? maxWidth,
    int? maxHeight,
    Color? background,
    Duration imageTimeout = const Duration(seconds: 10),
  }) {
    final options = CaptureOptions(
      format: format,
      quality: quality,
      pixelRatio: pixelRatio,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      background: background,
    );
    final view = _viewOf(context);
    return _render(
      widget,
      context: context,
      view: view,
      constraints: constraints,
      imageTimeout: imageTimeout,
      capture: (boundary) => captureBoundary(
        boundary,
        options,
        devicePixelRatio: view.devicePixelRatio,
      ),
    );
  }

  /// Captures the full content of the scroll view controlled by
  /// [scrollController], which must be inside the attached [Screenshot]
  /// widget: every item of a `ListView`, `GridView` or `CustomScrollView`,
  /// not only the visible part.
  ///
  /// The view is scrolled one screen at a time and the pieces are stitched
  /// together; its original position is restored afterwards. Only the
  /// scrolling area is captured. See [captureImage] for the parameters.
  Future<CaptureResult> captureScrollable(
    ScrollController scrollController, {
    ImageFormat format = ImageFormat.png,
    int quality = 90,
    double? pixelRatio,
    int? maxWidth,
    int? maxHeight,
    Color? background,
    Duration imageTimeout = const Duration(seconds: 10),
  }) async {
    final boundary = await _readyBoundary(imageTimeout);
    return captureScrollView(
      boundary,
      scrollController,
      CaptureOptions(
        format: format,
        quality: quality,
        pixelRatio: pixelRatio,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        background: background,
      ),
      devicePixelRatio: _devicePixelRatio(_context),
      imageTimeout: imageTimeout,
    );
  }

  // ---------------------------------------------------------------------
  // screenshot 3.0.0 API
  // ---------------------------------------------------------------------

  /// Captures the attached [Screenshot] widget as PNG and saves it as
  /// [fileName] (a timestamp by default) in [directory]. Returns the file's
  /// path, or null when there is nothing to capture. Not available on the
  /// web.
  Future<String?> captureAndSave(
    String directory, {
    String? fileName,
    double? pixelRatio,
    Duration delay = const Duration(milliseconds: 20),
  }) async {
    final content = await capture(pixelRatio: pixelRatio, delay: delay);
    if (content == null) return null;
    return saveFile(
      content,
      directory,
      fileName ?? '${DateTime.now().microsecondsSinceEpoch}.png',
    );
  }

  /// Captures the attached [Screenshot] widget as PNG, or returns null when
  /// it is not in the tree or not laid out yet. [delay] is waited first.
  ///
  /// Prefer [captureImage], which reports why a capture failed.
  Future<Uint8List?> capture({
    double? pixelRatio,
    Duration delay = const Duration(milliseconds: 20),
  }) async {
    try {
      final result = await captureImage(pixelRatio: pixelRatio, delay: delay);
      return result.bytes;
    } on ScreenshotException catch (e) {
      if (e.reason == ScreenshotFailure.notAttached ||
          e.reason == ScreenshotFailure.notReady) {
        return null;
      }
      rethrow;
    }
  }

  /// Captures the attached [Screenshot] widget as a [ui.Image], or returns
  /// null when it is not in the tree or not laid out yet. The caller must
  /// dispose the image.
  ///
  /// The image is made in one GPU pass, so very large widgets can exceed
  /// the platform's texture size; [captureImage] has no such limit.
  Future<ui.Image?> captureAsUiImage({
    double? pixelRatio = 1,
    Duration delay = const Duration(milliseconds: 20),
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final RenderCaptureBoundary boundary;
    try {
      boundary = await _readyBoundary(const Duration(seconds: 10));
    } on ScreenshotException {
      return null;
    }
    return boundary.toImage(
      pixelRatio: pixelRatio ?? _devicePixelRatio(_context),
    );
  }

  /// Captures [widget] without showing it and returns it as PNG.
  ///
  /// [delay] is the longest time to wait for images inside the widget to
  /// load; the capture does not wait longer than needed. [targetSize] limits
  /// the widget's size (the screen size by default). With a [context], the
  /// widget can use your providers, localizations and theme; see
  /// [captureWidget].
  Future<Uint8List> captureFromWidget(
    Widget widget, {
    Duration delay = const Duration(seconds: 1),
    double? pixelRatio,
    BuildContext? context,
    Size? targetSize,
  }) async {
    final result = await captureWidget(
      widget,
      context: context,
      constraints: targetSize == null ? null : BoxConstraints.loose(targetSize),
      pixelRatio: pixelRatio,
      imageTimeout: delay,
    );
    return result.bytes;
  }

  /// Captures [widget] without showing it and returns it as a [ui.Image],
  /// which the caller must dispose. See [captureFromWidget].
  static Future<ui.Image> widgetToUiImage(
    Widget widget, {
    Duration delay = const Duration(seconds: 1),
    double? pixelRatio,
    BuildContext? context,
    Size? targetSize,
  }) {
    final view = _viewOf(context);
    return _render(
      widget,
      context: context,
      view: view,
      constraints: targetSize == null ? null : BoxConstraints.loose(targetSize),
      imageTimeout: delay,
      capture: (boundary) =>
          boundary.toImage(pixelRatio: pixelRatio ?? view.devicePixelRatio),
    );
  }

  /// Captures [widget] at its natural size, which may be taller than the
  /// screen, and returns it as PNG. Long results are captured in tiles, so
  /// they are not cut off.
  ///
  /// [constraints] bound the widget; pass them when it contains `Expanded`,
  /// `Flexible`, `Spacer` or a `Scaffold`. Scroll views can't be measured
  /// this way; use [captureScrollable] for those.
  Future<Uint8List> captureFromLongWidget(
    Widget widget, {
    Duration delay = const Duration(seconds: 1),
    double? pixelRatio,
    BuildContext? context,
    BoxConstraints? constraints,
  }) async {
    final result = await captureWidget(
      widget,
      context: context,
      constraints: constraints ?? const BoxConstraints(),
      pixelRatio: pixelRatio,
      imageTimeout: delay,
    );
    return result.bytes;
  }

  /// Captures [widget] at its natural size and returns it as a [ui.Image],
  /// which the caller must dispose. See [captureFromLongWidget].
  Future<ui.Image> longWidgetToUiImage(
    Widget widget, {
    Duration delay = const Duration(seconds: 1),
    double? pixelRatio,
    BuildContext? context,
    BoxConstraints constraints = const BoxConstraints(
      maxHeight: double.maxFinite,
    ),
  }) {
    final view = _viewOf(context);
    return _render(
      widget,
      context: context,
      view: view,
      constraints: constraints,
      imageTimeout: delay,
      capture: (boundary) =>
          boundary.toImage(pixelRatio: pixelRatio ?? view.devicePixelRatio),
    );
  }

  // ---------------------------------------------------------------------

  Future<RenderCaptureBoundary> _readyBoundary(Duration imageTimeout) async {
    final context = _context;
    if (context == null || !context.mounted) {
      throw const ScreenshotException(
        ScreenshotFailure.notAttached,
        'No Screenshot widget with this controller is in the widget tree',
      );
    }
    if (await precacheImages(context as Element, imageTimeout)) {
      await nextFrame();
    }
    await settleFrames();
    final boundary = _context?.findRenderObject();
    if (boundary is! RenderCaptureBoundary || !boundary.isReadyToCapture) {
      throw const ScreenshotException(
        ScreenshotFailure.notReady,
        'The Screenshot widget has not been laid out and painted yet, or '
        'has zero size',
      );
    }
    return boundary;
  }

  static double _devicePixelRatio(BuildContext? context) {
    if (context != null && context.mounted) {
      return MediaQuery.maybeDevicePixelRatioOf(context) ??
          _viewOf(context).devicePixelRatio;
    }
    return _viewOf(null).devicePixelRatio;
  }

  static ui.FlutterView _viewOf(BuildContext? context) {
    final fromContext = context != null && context.mounted
        ? View.maybeOf(context)
        : null;
    if (fromContext != null) return fromContext;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return dispatcher.implicitView ?? dispatcher.views.first;
  }

  static Future<T> _render<T>(
    Widget widget, {
    required BuildContext? context,
    required ui.FlutterView view,
    required BoxConstraints? constraints,
    required Duration imageTimeout,
    required Future<T> Function(RenderCaptureBoundary boundary) capture,
  }) {
    final bounds =
        constraints ??
        BoxConstraints.loose(view.physicalSize / view.devicePixelRatio);
    if (context != null && context.mounted) {
      final inTree = renderInTree(
        context,
        widget,
        constraints: bounds,
        capture: capture,
        imageTimeout: imageTimeout,
      );
      if (inTree != null) return inTree;
    }
    return renderIsolated(
      widget,
      view: view,
      constraints: bounds,
      capture: capture,
      inheritFrom: context != null && context.mounted ? context : null,
      imageTimeout: imageTimeout,
    );
  }
}

/// Makes its [child] capturable by [controller].
class Screenshot extends StatefulWidget {
  /// Wraps [child] so that [controller] can capture it.
  const Screenshot({super.key, required this.child, required this.controller});

  /// The widget to capture.
  final Widget? child;

  /// The controller that captures [child].
  final ScreenshotController controller;

  @override
  State<Screenshot> createState() => ScreenshotState();
}

/// State for [Screenshot].
class ScreenshotState extends State<Screenshot> {
  /// Creates the state. Created by [Screenshot.createState].
  ScreenshotState();

  @override
  Widget build(BuildContext context) => CaptureBoundary(
    key: widget.controller._containerKey,
    child: widget.child,
  );
}

/// Rounds a double, kept from the `screenshot` package for compatibility.
extension Ex on double {
  /// This value rounded to [n] decimal places.
  double toPrecision(int n) => double.parse(toStringAsFixed(n));
}
