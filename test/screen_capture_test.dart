// Native capture runs on Android and iOS; on the web it is unsupported.
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot_kit/screenshot_kit.dart';
import 'package:screenshot_kit/src/capture/capture_options.dart';
import 'package:screenshot_kit/src/native/screen_capture.dart';

import 'support/live.dart';

Uint8List pngOf(int width, int height, img.Color color) => img.encodePng(
  img.Image(width: width, height: height, numChannels: 4)..clear(color),
);

void main() {
  useLiveFrames();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?>? Function(MethodCall call)? handler) =>
      messenger.setMockMethodCallHandler(ScreenshotKit.channel, handler);

  tearDown(() {
    answer(null);
    debugDefaultTargetPlatformOverride = null;
  });

  Matcher failsWith(ScreenshotFailure reason) => throwsA(
    isA<ScreenshotException>().having((e) => e.reason, 'reason', reason),
  );

  group('captureScreen', () {
    testWidgets('returns the platform PNG as is', (tester) async {
      final png = pngOf(12, 8, img.ColorRgb8(255, 0, 0));
      String? method;
      answer((call) async {
        method = call.method;
        return png;
      });

      final result = await ScreenshotKit.captureScreen();

      expect(method, 'captureScreen');
      expect(result.bytes, png);
      expect((result.width, result.height), (12, 8));
    });

    testWidgets('converts to JPEG and scales down', (tester) async {
      answer((_) async => pngOf(40, 20, img.ColorRgb8(0, 0, 255)));

      final result = await ScreenshotKit.captureScreen(
        format: ImageFormat.jpeg,
        maxWidth: 20,
      );

      expect(result.format, ImageFormat.jpeg);
      expect((result.width, result.height), (20, 10));
      expect(result.bytes.sublist(0, 2), [0xFF, 0xD8]);
    });

    testWidgets('reports platform errors', (tester) async {
      answer((_) async => throw PlatformException(code: 'pixelcopy'));

      await expectLater(
        ScreenshotKit.captureScreen(),
        failsWith(ScreenshotFailure.platformError),
      );
    });

    testWidgets('reports an empty platform answer', (tester) async {
      answer((_) async => null);

      await expectLater(
        ScreenshotKit.captureScreen(),
        failsWith(ScreenshotFailure.platformError),
      );
    });

    testWidgets('reports a missing plugin as unsupported', (tester) async {
      await expectLater(
        ScreenshotKit.captureScreen(),
        failsWith(ScreenshotFailure.unsupportedPlatform),
      );
    });

    test('is unsupported on desktop', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(ScreenshotKit.isScreenCaptureSupported, isFalse);

      await expectLater(
        ScreenshotKit.captureScreen(),
        failsWith(ScreenshotFailure.unsupportedPlatform),
      );
    });

    test('is supported on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(ScreenshotKit.isScreenCaptureSupported, isTrue);
    });
  });

  group('pngSize', () {
    test('reads the header', () {
      expect(pngSize(pngOf(7, 3, img.ColorRgb8(0, 0, 0))), (7, 3));
    });

    test('rejects other data', () {
      expect(
        () => pngSize(Uint8List(30)),
        failsWith(ScreenshotFailure.platformError),
      );
    });
  });

  testWidgets('transcodePng adds a background', (tester) async {
    final transparent = pngOf(4, 4, img.ColorRgba8(0, 0, 0, 0));

    final result = await transcodePng(
      transparent,
      const CaptureOptions(
        format: ImageFormat.rawRgba,
        background: Color(0xFF00FF00),
      ),
    );

    expect(pixelAt(result, 1, 1), isColor(const Color(0xFF00FF00)));
  });

  test('the desktop registration hook does nothing', () {
    expect(ScreenshotKitDesktop.registerWith, returnsNormally);
  });
}
