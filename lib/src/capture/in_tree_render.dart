import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../errors.dart';
import 'capture_boundary.dart';
import 'settle.dart';

/// Marks where off-screen captures are rendered, so captured widgets can
/// read providers and other inherited widgets declared above this point.
///
/// Without a host, `captureWidget` renders into the nearest [Overlay], which
/// usually sits above your routes. Wrap a page in a [ScreenshotHost] when the
/// captured widget needs something provided inside that page:
///
/// ```dart
/// BlocProvider(
///   create: (_) => CartBloc(),
///   child: ScreenshotHost(child: CartPage()),
/// )
/// ```
class ScreenshotHost extends StatefulWidget {
  /// Creates a host around [child].
  const ScreenshotHost({super.key, required this.child});

  /// The content shown on screen.
  final Widget child;

  @override
  State<ScreenshotHost> createState() => _ScreenshotHostState();
}

class _ScreenshotHostState extends State<ScreenshotHost> {
  final _slots = <Widget>[];

  void _add(Widget slot) => setState(() => _slots.add(slot));

  void _remove(Widget slot) {
    if (mounted) setState(() => _slots.remove(slot));
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [widget.child, ..._slots],
  );
}

/// Renders [widget] off-screen at the nearest [ScreenshotHost] or [Overlay]
/// above [context] and runs [capture] once it is painted and its images
/// have loaded. Returns null when there is neither, so the caller can fall
/// back to an isolated render.
Future<T>? renderInTree<T>(
  BuildContext context,
  Widget widget, {
  required BoxConstraints constraints,
  required Future<T> Function(RenderCaptureBoundary boundary) capture,
  Duration imageTimeout = const Duration(seconds: 10),
}) {
  final host = context.findAncestorStateOfType<_ScreenshotHostState>();
  final overlay = host == null ? Overlay.maybeOf(context) : null;
  if (host == null && overlay == null) return null;

  final key = GlobalKey();
  final slot = Positioned(
    // Far left of the visible area, so it is laid out and painted but
    // never seen. Painting is not culled, so the layer is still recorded.
    left: -(constraints.hasBoundedWidth ? constraints.maxWidth : 10000) - 10000,
    top: 0,
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: ConstrainedBox(
            constraints: constraints,
            child: CaptureBoundary(
              key: key,
              child: Material(type: MaterialType.transparency, child: widget),
            ),
          ),
        ),
      ),
    ),
  );
  return _run(
    key,
    insert: host != null
        ? () => host._add(slot)
        : () {
            final entry = OverlayEntry(builder: (_) => slot);
            overlay!.insert(entry);
            return entry;
          },
    remove: (token) {
      if (token is OverlayEntry) {
        token
          ..remove()
          ..dispose();
      } else {
        host?._remove(slot);
      }
    },
    capture: capture,
    imageTimeout: imageTimeout,
  );
}

Future<T> _run<T>(
  GlobalKey key, {
  required Object? Function() insert,
  required void Function(Object? token) remove,
  required Future<T> Function(RenderCaptureBoundary boundary) capture,
  required Duration imageTimeout,
}) async {
  // Inserting during build or layout is not allowed; wait for the frame.
  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
    await SchedulerBinding.instance.endOfFrame;
  }
  final token = insert();
  try {
    await nextFrame();
    final element = key.currentContext as Element?;
    if (element != null && await precacheImages(element, imageTimeout)) {
      await nextFrame();
    }
    await settleFrames();
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderCaptureBoundary) {
      throw const ScreenshotException(
        ScreenshotFailure.notReady,
        'The off-screen widget was not rendered',
      );
    }
    return await capture(boundary);
  } finally {
    remove(token);
  }
}
