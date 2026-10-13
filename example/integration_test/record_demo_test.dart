// Drives the example app slowly, in real time, so the run can be screen
// recorded for the README. Not a regression test: it asserts very little.
//
//   flutter test integration_test/record_demo_test.dart -d <simulator>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:screenshot_kit_example/main.dart';
import 'package:screenshot_kit_example/preview_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> wait(WidgetTester tester, int ms) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 16)),
      );
      await tester.pump();
    }
  }

  void mark(String name) {
    // ignore: avoid_print
    print('DEMO_MARK $name ${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> scrollList(WidgetTester tester, Finder target) async {
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -150));
      await wait(tester, 100);
    }
    await tester.ensureVisible(target);
    await wait(tester, 300);
  }

  Future<void> captureAndShow(
    WidgetTester tester,
    String label, {
    bool scroll = false,
    int previewMs = 3000,
    Future<void> Function()? onPreview,
  }) async {
    final button = find.text(label);
    if (scroll) await scrollList(tester, button);
    await tester.tap(button);
    for (var i = 0; i < 300; i++) {
      await wait(tester, 100);
      if (find.byType(PreviewPage).evaluate().isNotEmpty) break;
    }
    expect(find.byType(PreviewPage), findsOneWidget);
    await wait(tester, 800);
    mark('preview');
    if (onPreview != null) {
      await onPreview();
    } else {
      await wait(tester, previewMs);
    }
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await wait(tester, 800);
  }

  Future<void> slowDrag(WidgetTester tester, double dy, int steps) async {
    // Dispatched as "device" events so the live binding does not paint its
    // yellow pointer crosshair into the recording.
    binding.shouldPropagateDevicePointerEvents = true;
    void send(PointerEvent e) => binding.handlePointerEventForSource(
      e,
      source: TestBindingEventSource.device,
    );
    final pointer = TestPointer(7);
    var pos = const Offset(200, 600);
    send(pointer.down(pos));
    for (var i = 0; i < steps; i++) {
      pos += Offset(0, dy / steps);
      send(pointer.move(pos));
      await wait(tester, 16);
    }
    send(pointer.up());
    binding.shouldPropagateDevicePointerEvents = false;
    await wait(tester, 200);
  }

  Future<void> openDemo(WidgetTester tester, int index, String name) async {
    mark('home_$name');
    await wait(tester, 1500);
    await tester.tap(find.byKey(Key('demo-$index')));
    await wait(tester, 1800);
    mark('open_$name');
  }

  testWidgets('record demos', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await wait(tester, 2000);

    await openDemo(tester, 0, 'widget');
    await captureAndShow(tester, 'Capture', scroll: true, previewMs: 3000);
    mark('end_widget');
    await back(tester);
    await back(tester);

    await openDemo(tester, 1, 'offscreen');
    await captureAndShow(tester, 'Capture share card', previewMs: 3000);
    mark('end_offscreen');
    await back(tester);
    await back(tester);

    await openDemo(tester, 2, 'longlist');
    await captureAndShow(
      tester,
      'Capture whole list',
      onPreview: () async {
        await wait(tester, 1000);
        await slowDrag(tester, -450, 40);
        await slowDrag(tester, -450, 40);
        await slowDrag(tester, -450, 40);
        await wait(tester, 800);
      },
    );
    mark('end_longlist');
    await back(tester);
    await back(tester);

    await openDemo(tester, 3, 'longwidget');
    await captureAndShow(
      tester,
      'Capture receipt',
      onPreview: () async {
        await wait(tester, 1000);
        await slowDrag(tester, -450, 40);
        await slowDrag(tester, -450, 40);
        await wait(tester, 800);
      },
    );
    mark('end_longwidget');
    await back(tester);
    await back(tester);

    await openDemo(tester, 4, 'webview');
    await wait(tester, 2500);
    await captureAndShow(tester, 'Capture screen', previewMs: 3500);
    mark('end_webview');
    await back(tester);
    await back(tester);
    await wait(tester, 500);
  });
}
