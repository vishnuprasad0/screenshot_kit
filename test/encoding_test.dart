import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot_kit/screenshot_kit.dart';
import 'package:screenshot_kit/src/capture/capture_options.dart';
import 'package:screenshot_kit/src/capture/pixel_canvas.dart';
import 'package:screenshot_kit/src/encoding/encoder.dart';

RgbaPixels solid(int width, int height, List<int> rgba) => RgbaPixels(
  Uint8List.fromList([for (var i = 0; i < width * height; i++) ...rgba]),
  width,
  height,
);

void main() {
  group('composite', () {
    test('opaque pixels are unchanged', () {
      final out = composite(Uint8List.fromList([10, 20, 30, 255]), 0xFFFFFFFF);
      expect(out, [10, 20, 30, 255]);
    });

    test('half-transparent red over white is pink', () {
      final out = composite(Uint8List.fromList([255, 0, 0, 128]), 0xFFFFFFFF);
      expect(out, [255, 127, 127, 255]);
    });

    test('fully transparent pixels take the background', () {
      final out = composite(Uint8List.fromList([9, 9, 9, 0]), 0xFF0000FF);
      expect(out, [0, 0, 255, 255]);
    });

    test('a transparent background keeps transparency', () {
      final out = composite(Uint8List.fromList([9, 9, 9, 0]), 0x00000000);
      expect(out, [0, 0, 0, 0]);
    });

    test('a translucent background blends alpha', () {
      final out = composite(Uint8List.fromList([0, 0, 0, 0]), 0x80FF0000);
      expect(out, [255, 0, 0, 128]);
    });
  });

  group('encodeRgba', () {
    final pixels = solid(3, 2, [0, 255, 0, 255]);

    test('PNG decodes back to the same pixels', () {
      final png = encodeRgba(
        EncodeRequest(pixels.bytes, 3, 2, ImageFormat.png, 90, null),
      );
      final decoded = img.decodePng(png)!;
      expect((decoded.width, decoded.height), (3, 2));
      expect(decoded.getPixel(2, 1).g, 255);
    });

    test('JPEG output is a JPEG', () {
      final jpeg = encodeRgba(
        EncodeRequest(pixels.bytes, 3, 2, ImageFormat.jpeg, 80, 0xFFFFFFFF),
      );
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
    });

    test('raw output is the pixels', () {
      final raw = encodeRgba(
        EncodeRequest(pixels.bytes, 3, 2, ImageFormat.rawRgba, 90, null),
      );
      expect(raw, pixels.bytes);
    });

    test('works on views with an offset', () {
      final backing = Uint8List(8 + pixels.bytes.length)
        ..setRange(8, 8 + pixels.bytes.length, pixels.bytes);
      final view = Uint8List.sublistView(backing, 8);
      final png = encodeRgba(
        EncodeRequest(view, 3, 2, ImageFormat.png, 90, null),
      );
      expect(img.decodePng(png)!.getPixel(0, 0).g, 255);
    });
  });

  test('encodePixels rejects an invalid quality', () {
    expect(
      () => encodePixels(
        solid(1, 1, [0, 0, 0, 255]),
        format: ImageFormat.jpeg,
        quality: 0,
      ),
      throwsRangeError,
    );
  });

  group('PixelCanvas', () {
    test('draws at an offset and clips', () {
      final canvas = PixelCanvas(4, 4)..draw(solid(2, 2, [1, 2, 3, 4]), 3, -1);
      final bytes = canvas.toPixels().bytes;
      expect(bytes.sublist((0 * 4 + 3) * 4, (0 * 4 + 3) * 4 + 4), [1, 2, 3, 4]);
      expect(bytes.sublist((1 * 4 + 3) * 4, (1 * 4 + 3) * 4 + 4), [0, 0, 0, 0]);
      expect(bytes.sublist(0, 4), [0, 0, 0, 0]);
    });

    test('ignores sources completely outside', () {
      final canvas = PixelCanvas(2, 2)..draw(solid(1, 1, [9, 9, 9, 9]), 5, 5);
      expect(canvas.toPixels().bytes.every((b) => b == 0), isTrue);
    });

    test('refuses empty and oversized canvases', () {
      expect(
        () => PixelCanvas(0, 10),
        throwsA(
          isA<ScreenshotException>().having(
            (e) => e.reason,
            'reason',
            ScreenshotFailure.notReady,
          ),
        ),
      );
      expect(
        () => PixelCanvas(20000, 20000),
        throwsA(
          isA<ScreenshotException>().having(
            (e) => e.reason,
            'reason',
            ScreenshotFailure.tooLarge,
          ),
        ),
      );
    });
  });

  group('CaptureOptions.resolvePixelRatio', () {
    const size = Size(100, 50);

    test('uses the requested ratio, else the device ratio', () {
      expect(const CaptureOptions(pixelRatio: 2).resolvePixelRatio(size, 3), 2);
      expect(const CaptureOptions().resolvePixelRatio(size, 3), 3);
    });

    test('fits maxWidth and maxHeight', () {
      expect(
        const CaptureOptions(maxWidth: 150).resolvePixelRatio(size, 3),
        1.5,
      );
      expect(
        const CaptureOptions(
          maxWidth: 400,
          maxHeight: 50,
        ).resolvePixelRatio(size, 3),
        1,
      );
    });

    test('never raises the ratio', () {
      expect(
        const CaptureOptions(maxWidth: 1000).resolvePixelRatio(size, 2),
        2,
      );
    });
  });

  test('ScreenshotException describes itself', () {
    const plain = ScreenshotException(ScreenshotFailure.tooLarge, 'Too big');
    const caused = ScreenshotException(
      ScreenshotFailure.platformError,
      'Failed',
      cause: 'boom',
    );
    expect(plain.toString(), 'ScreenshotException(tooLarge): Too big');
    expect(caused.toString(), contains('(boom)'));
  });

  test('CaptureResult describes itself', () {
    final result = CaptureResult(
      bytes: Uint8List(3),
      width: 2,
      height: 1,
      format: ImageFormat.jpeg,
    );
    expect(result.toString(), 'CaptureResult(jpeg, 2x1, 3 bytes)');
  });
}
