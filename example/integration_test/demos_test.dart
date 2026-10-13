import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:screenshot_kit/screenshot_kit.dart';
import 'package:screenshot_kit_example/main.dart';
import 'package:screenshot_kit_example/preview_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Taps the button with [label] and waits for the preview page.
  Future<PreviewPage> capture(
    WidgetTester tester,
    String label, {
    bool scroll = false,
  }) async {
    final button = find.text(label);
    if (scroll) {
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.tap(button);
    for (var i = 0; i < 300; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.byType(PreviewPage).evaluate().isNotEmpty) break;
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'capture failed with an error',
      );
    }
    expect(find.byType(PreviewPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    final page = tester.widget<PreviewPage>(find.byType(PreviewPage));
    // ignore: avoid_print
    print('"$label": ${page.summary}');
    expect(find.byKey(const Key('preview-image')), findsOneWidget);
    return page;
  }

  Future<void> open(WidgetTester tester, int index) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.byKey(Key('demo-$index')));
    await tester.pumpAndSettle();
  }

  testWidgets('widget capture: PNG, then JPEG limited to 400 px', (
    tester,
  ) async {
    await open(tester, 0);
    final png = await capture(tester, 'Capture', scroll: true);
    expect(png.result.format, ImageFormat.png);
    expect(png.result.width, greaterThan(300));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('JPEG'));
    await tester.tap(find.text('Max width 400 px'));
    await tester.pump();
    final jpeg = await capture(tester, 'Capture', scroll: true);
    expect(jpeg.result.format, ImageFormat.jpeg);
    expect(jpeg.result.width, lessThanOrEqualTo(400));
    expect(jpeg.result.bytes.length, lessThan(png.result.bytes.length));
  });

  testWidgets('off-screen widget: app provider and ScreenshotHost', (
    tester,
  ) async {
    await open(tester, 1);
    final view = tester.view;
    final share = await capture(tester, 'Capture share card');
    // The card is 360 logical pixels wide.
    expect(share.result.width, (360 * view.devicePixelRatio).round());
    expect(share.result.height, greaterThan(100));
    await tester.pageBack();
    await tester.pumpAndSettle();

    final banner = await capture(
      tester,
      'Capture with ScreenshotHost',
      scroll: true,
    );
    expect(banner.result.width, (360 * view.devicePixelRatio).round());
    expect(banner.result.height, greaterThan(50));
  });

  testWidgets('long list: the whole list, not only the visible rows', (
    tester,
  ) async {
    await open(tester, 2);
    final page = await capture(tester, 'Capture whole list');
    // 200 rows of 56 to 80 logical pixels, captured at 1x.
    expect(page.result.height, greaterThan(5000));
    expect(page.result.format, ImageFormat.jpeg);
    expect(page.result.height, greaterThan(tester.view.physicalSize.height));
  });

  testWidgets('long widget: taller than the screen and not truncated', (
    tester,
  ) async {
    await open(tester, 3);
    final page = await capture(tester, 'Capture receipt');
    expect(page.result.height, greaterThan(tester.view.physicalSize.height));
    // 60 lines of about 30 logical pixels at 2x.
    expect(page.result.height, greaterThan(3000));
    expect(page.result.width, 720);
  });

  testWidgets('screen with WebView: screen capture and widget capture', (
    tester,
  ) async {
    await open(tester, 4);
    // Give the web view a moment to load its page.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    final screen = await capture(tester, 'Capture screen');
    final physical = tester.view.physicalSize;
    expect(screen.result.width, physical.width.round());
    expect(screen.result.height, greaterThan(physical.height * 0.8));
    await tester.pageBack();
    await tester.pumpAndSettle();

    final widget = await capture(tester, 'Widget capture');
    expect(widget.result.width, greaterThan(0));
    expect(widget.result.height, greaterThan(0));
  });
}
