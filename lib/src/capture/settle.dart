import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Image providers shown by [Image] widgets and box decorations below
/// [root].
List<ImageProvider<Object>> collectImageProviders(Element root) {
  final providers = <ImageProvider<Object>>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Image) {
      providers.add(widget.image);
    } else if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && decoration.image != null) {
        providers.add(decoration.image!.image);
      }
    }
    element.visitChildren(visit);
  }

  visit(root);
  return providers;
}

/// Loads every image below [root] into the image cache, waiting at most
/// [timeout]. Images that fail or time out are skipped, not reported.
///
/// Returns whether any image was loaded, in which case the widgets showing
/// them need another frame before capturing.
Future<bool> precacheImages(Element root, Duration timeout) async {
  final providers = collectImageProviders(root);
  if (providers.isEmpty || timeout <= Duration.zero) return false;
  var loaded = false;
  await Future.wait([
    for (final provider in providers)
      precacheImage(
        provider,
        root,
        onError: (_, _) {},
      ).then((_) => loaded = true),
  ]).timeout(timeout, onTimeout: () => const []);
  return loaded;
}

/// Completes after the next frame has been drawn, scheduling one if needed.
Future<void> nextFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
}

/// Waits until no frame is pending, so the tree is laid out and painted.
Future<void> settleFrames({int maxFrames = 3}) async {
  final binding = SchedulerBinding.instance;
  for (var i = 0; i < maxFrames; i++) {
    if (!binding.hasScheduledFrame &&
        binding.schedulerPhase == SchedulerPhase.idle) {
      return;
    }
    await binding.endOfFrame;
  }
}
