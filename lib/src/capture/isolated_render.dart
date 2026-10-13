import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'capture_boundary.dart';
import 'settle.dart';

/// Builds, lays out and paints [widget] in a private pipeline that is not
/// attached to the screen, then runs [capture] on its boundary.
///
/// Used when there is no `ScreenshotHost` or `Overlay` to render into. The
/// widget only sees what [inheritFrom] can pass on explicitly (themes,
/// media query, localizations and text direction), and the whole tree is
/// unmounted and disposed afterwards.
Future<T> renderIsolated<T>(
  Widget widget, {
  required ui.FlutterView view,
  required BoxConstraints constraints,
  required Future<T> Function(RenderCaptureBoundary boundary) capture,
  BuildContext? inheritFrom,
  Duration imageTimeout = const Duration(seconds: 10),
  int maxRebuilds = 3,
}) async {
  final child = inheritFrom == null
      ? Directionality(textDirection: TextDirection.ltr, child: widget)
      : inheritContext(inheritFrom, widget);
  // A RenderView needs finite constraints, so measure the widget first and
  // render it at exactly that size, as the original screenshot package did
  // for long widgets.
  final size = measureWidget(child, constraints);
  final boundary = RenderCaptureBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.loose(size),
      devicePixelRatio: view.devicePixelRatio,
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  var dirty = false;
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(
    focusManager: focusManager,
    onBuildScheduled: () => dirty = true,
  );
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: child,
  ).attachToRenderTree(buildOwner);

  void drawFrame() {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
  }

  try {
    drawFrame();
    if (await precacheImages(root, imageTimeout)) {
      // Image widgets rebuild asynchronously once their stream completes.
      await Future<void>.delayed(Duration.zero);
      dirty = true;
    }
    for (var i = 0; dirty && i < maxRebuilds; i++) {
      dirty = false;
      drawFrame();
      await Future<void>.delayed(Duration.zero);
    }
    return await capture(boundary);
  } finally {
    root.update(RenderObjectToWidgetAdapter<RenderBox>(container: boundary));
    buildOwner.finalizeTree();
    pipelineOwner.rootNode = null;
    pipelineOwner.dispose();
    focusManager.dispose();
    boundary.dispose();
    renderView.dispose();
  }
}

/// The size [widget] takes within [constraints], from a throwaway layout.
Size measureWidget(Widget widget, BoxConstraints constraints) {
  final pipelineOwner = PipelineOwner();
  final root = pipelineOwner.rootNode = _MeasureRoot(constraints);
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(focusManager: focusManager);
  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: root,
    child: widget,
  ).attachToRenderTree(buildOwner);
  try {
    root.scheduleInitialLayout();
    pipelineOwner.flushLayout();
    return root.size;
  } finally {
    element.update(RenderObjectToWidgetAdapter<RenderBox>(container: root));
    buildOwner.finalizeTree();
    pipelineOwner.rootNode = null;
    pipelineOwner.dispose();
    focusManager.dispose();
    root.dispose();
  }
}

/// Root that lays its child out with fixed constraints and takes its size.
class _MeasureRoot extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _MeasureRoot(this._constraints);

  final BoxConstraints _constraints;

  @override
  void performLayout() {
    final child = this.child;
    size = child == null
        ? _constraints.smallest
        : (child..layout(_constraints, parentUsesSize: true)).size;
  }

  @override
  void debugAssertDoesMeetConstraints() {}
}

/// Wraps [child] with what can be copied from [context]: themes, text style,
/// media query, localizations and text direction, on a transparent
/// [Material].
Widget inheritContext(BuildContext context, Widget child) {
  Widget result = Material(type: MaterialType.transparency, child: child);
  if (Localizations.maybeLocaleOf(context) != null) {
    result = Localizations.override(context: context, child: result);
  }
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery != null) {
    result = MediaQuery(data: mediaQuery, child: result);
  }
  return Directionality(
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    child: InheritedTheme.captureAll(context, result),
  );
}
