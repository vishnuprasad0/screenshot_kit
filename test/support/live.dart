import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

/// Captures need real frames and real async image work, so tests run with a
/// live binding instead of the fake-async one.
void useLiveFrames() {
  final binding = LiveTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
}

/// Skips tests that `flutter test --platform chrome` can't run: it does
/// not decode JPEGs or paint `Image` widgets, and has no `dart:io`. A real
/// browser does both; this was checked with an app in headless Chrome.
const vmOnly = kIsWeb;

/// Shows [child] in a plain app with no animations or banner.
Future<void> show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, home: child),
  );
  await tester.pump();
}

/// The RGBA pixel at ([x], [y]) of a raw capture.
Color pixelAt(CaptureResult raw, int x, int y) {
  assert(raw.format == ImageFormat.rawRgba);
  final i = (y * raw.width + x) * 4;
  final b = raw.bytes;
  return Color.fromARGB(b[i + 3], b[i], b[i + 1], b[i + 2]);
}

/// Decodes an encoded image (PNG or JPEG) to raw RGBA for inspection.
Future<CaptureResult> decode(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final result = CaptureResult(
    bytes: data!.buffer.asUint8List(),
    width: image.width,
    height: image.height,
    format: ImageFormat.rawRgba,
  );
  image.dispose();
  codec.dispose();
  return result;
}

/// Matches a colour within [tolerance] per channel (JPEG and filtering are
/// not exact).
Matcher isColor(Color expected, {int tolerance = 2}) => predicate<Color>(
  (c) =>
      ((c.r - expected.r) * 255).abs() <= tolerance &&
      ((c.g - expected.g) * 255).abs() <= tolerance &&
      ((c.b - expected.b) * 255).abs() <= tolerance &&
      ((c.a - expected.a) * 255).abs() <= tolerance,
  'is $expected (±$tolerance)',
);
