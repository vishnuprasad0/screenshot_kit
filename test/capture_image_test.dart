import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot_kit/screenshot_kit.dart';

import 'support/live.dart';

const red = Color(0xFFFF0000);
const green = Color(0xFF00FF00);
const blue = Color(0xFF0000FF);

Widget box(double width, double height, Color color) => SizedBox(
  width: width,
  height: height,
  child: ColoredBox(color: color),
);

void main() {
  useLiveFrames();

  late ScreenshotController controller;
  setUp(() => controller = ScreenshotController());

  Future<void> showBox(WidgetTester tester, Widget child) => show(
    tester,
    Center(
      child: Screenshot(controller: controller, child: child),
    ),
  );

  group('captureImage', () {
    testWidgets('captures at the given pixel ratio', (tester) async {
      await showBox(tester, box(100, 50, red));

      final raw = await controller.captureImage(
        format: ImageFormat.rawRgba,
        pixelRatio: 2,
      );

      expect((raw.width, raw.height), (200, 100));
      expect(pixelAt(raw, 100, 50), isColor(red));
    });

    testWidgets('uses the device pixel ratio by default', (tester) async {
      await showBox(tester, box(100, 50, red));
      final ratio = tester.view.devicePixelRatio;

      final result = await controller.captureImage();

      expect(result.width, (100 * ratio).round());
      expect(result.format, ImageFormat.png);
    });

    testWidgets('maxWidth and maxHeight lower the ratio', (tester) async {
      await showBox(tester, box(100, 50, red));

      final wide = await controller.captureImage(pixelRatio: 3, maxWidth: 50);
      final tall = await controller.captureImage(pixelRatio: 3, maxHeight: 10);

      expect((wide.width, wide.height), (50, 25));
      expect((tall.width, tall.height), (20, 10));
    });

    testWidgets('JPEG fills transparency with white, or the background', (
      tester,
    ) async {
      await showBox(tester, const SizedBox(width: 40, height: 40));

      final white = await decode(
        (await controller.captureImage(
          format: ImageFormat.jpeg,
          pixelRatio: 1,
        )).bytes,
      );
      final tinted = await decode(
        (await controller.captureImage(
          format: ImageFormat.jpeg,
          pixelRatio: 1,
          background: blue,
        )).bytes,
      );

      expect(pixelAt(white, 20, 20), isColor(Colors.white, tolerance: 4));
      expect(pixelAt(tinted, 20, 20), isColor(blue, tolerance: 4));
    }, skip: vmOnly);

    testWidgets('PNG with a background is opaque', (tester) async {
      await showBox(tester, const SizedBox(width: 40, height: 40));

      final png = await controller.captureImage(
        pixelRatio: 1,
        background: green,
      );

      expect(pixelAt(await decode(png.bytes), 5, 5), isColor(green));
    });

    testWidgets('waits for images instead of using a fixed delay', (
      tester,
    ) async {
      final pixel = img.Image(width: 4, height: 4)
        ..clear(img.ColorRgb8(0, 255, 0));
      await showBox(
        tester,
        SizedBox(
          width: 40,
          height: 40,
          child: Image.memory(
            img.encodePng(pixel),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      );

      final raw = await controller.captureImage(
        format: ImageFormat.rawRgba,
        pixelRatio: 1,
      );

      expect(pixelAt(raw, 20, 20), isColor(green));
    }, skip: vmOnly);

    testWidgets('waits for decoration images too', (tester) async {
      final pixel = img.Image(width: 4, height: 4)
        ..clear(img.ColorRgb8(0, 0, 255));
      await showBox(
        tester,
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: MemoryImage(img.encodePng(pixel)),
              fit: BoxFit.fill,
            ),
          ),
        ),
      );

      final raw = await controller.captureImage(
        format: ImageFormat.rawRgba,
        pixelRatio: 1,
      );

      expect(pixelAt(raw, 20, 20), isColor(blue));
    }, skip: vmOnly);

    testWidgets('captures widgets taller than one texture in full', (
      tester,
    ) async {
      // 3,000 logical px at ratio 2 is 6,000 px: two tiles.
      await show(
        tester,
        SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: Screenshot(
              controller: controller,
              child: Column(
                children: [
                  box(50, 1000, red),
                  box(50, 1000, green),
                  box(50, 1000, blue),
                ],
              ),
            ),
          ),
        ),
      );

      final raw = await controller.captureImage(
        format: ImageFormat.rawRgba,
        pixelRatio: 2,
      );

      expect((raw.width, raw.height), (100, 6000));
      expect(pixelAt(raw, 50, 10), isColor(red));
      expect(pixelAt(raw, 50, 3000), isColor(green));
      expect(pixelAt(raw, 50, 5990), isColor(blue));
    });

    testWidgets('throws notAttached without a Screenshot widget', (
      tester,
    ) async {
      await show(tester, const SizedBox());

      await expectLater(
        controller.captureImage(),
        throwsA(
          isA<ScreenshotException>().having(
            (e) => e.reason,
            'reason',
            ScreenshotFailure.notAttached,
          ),
        ),
      );
    });
  });

  group('screenshot 3.0.0 API', () {
    testWidgets('capture() returns PNG bytes', (tester) async {
      await showBox(tester, box(30, 20, red));

      final png = await controller.capture(pixelRatio: 1);

      final raw = await decode(png!);
      expect((raw.width, raw.height), (30, 20));
    });

    testWidgets('capture() returns null when nothing is attached', (
      tester,
    ) async {
      await show(tester, const SizedBox());

      expect(await controller.capture(), isNull);
      expect(await controller.captureAsUiImage(), isNull);
      expect(
        await controller.captureAndSave(Directory.systemTemp.path),
        isNull,
      );
    }, skip: vmOnly);

    testWidgets('captureAsUiImage() defaults to ratio 1', (tester) async {
      await showBox(tester, box(30, 20, red));

      final image = await controller.captureAsUiImage();

      expect((image!.width, image.height), (30, 20));
      image.dispose();
    });

    testWidgets('captureAndSave() writes a PNG file', (tester) async {
      await showBox(tester, box(30, 20, red));
      final dir = Directory.systemTemp.createTempSync('screenshot_kit');
      addTearDown(() => dir.deleteSync(recursive: true));

      final path = await tester.runAsync(
        () => controller.captureAndSave(dir.path, fileName: 'shot.png'),
      );

      expect(path, '${dir.path}/shot.png');
      final raw = await decode(File(path!).readAsBytesSync());
      expect(raw.width, (30 * tester.view.devicePixelRatio).round());
    }, skip: vmOnly);

    test('toPrecision is kept', () {
      expect(1.23456.toPrecision(2), 1.23);
    });
  });
}
