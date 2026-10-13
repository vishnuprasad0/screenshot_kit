import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:screenshot_kit/screenshot_kit.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captureScreen includes Flutter content and the web view', (
    tester,
  ) async {
    final controller = WebViewController()
      ..setBackgroundColor(const Color(0xFF0000FF))
      ..loadHtmlString(
        '<html><body style="margin:0;background:#0000ff"></body></html>',
      );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Column(
          children: [
            const Expanded(
              child: SizedBox.expand(
                child: ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
            Expanded(child: WebViewWidget(controller: controller)),
          ],
        ),
      ),
    );
    List<int> pixel(CaptureResult r, int x, int y) {
      final i = (y * r.width + x) * 4;
      return r.bytes.sublist(i, i + 3);
    }

    // pump() does not wait wall-clock time, and the web view needs a few
    // real seconds to load, so poll until it has painted.
    late CaptureResult result;
    late List<int> top;
    late List<int> bottom;
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      result = await ScreenshotKit.captureScreen(format: ImageFormat.rawRgba);
      top = pixel(result, result.width ~/ 2, result.height ~/ 4);
      bottom = pixel(result, result.width ~/ 2, result.height * 3 ~/ 4);
      if (attempt >= 2 && bottom[2] > 200) break;
    }
    expect(result.width, greaterThan(0));
    expect(result.height, greaterThan(0));
    // ignore: avoid_print
    print('size=${result.width}x${result.height} top=$top bottom=$bottom');
    void expectNear(List<int> actual, List<int> expected) {
      for (var c = 0; c < 3; c++) {
        expect(
          (actual[c] - expected[c]).abs(),
          lessThanOrEqualTo(10),
          reason: 'channel $c of $actual vs $expected',
        );
      }
    }

    expectNear(top, [255, 0, 0]);
    expectNear(bottom, [0, 0, 255]);
  });
}
