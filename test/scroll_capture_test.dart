import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

import 'support/live.dart';

const colors = [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)];

/// The colour of item [index] in the test lists.
Color colorOf(int index) => colors[index % colors.length];

void main() {
  useLiveFrames();

  late ScreenshotController controller;
  late ScrollController scroll;
  setUp(() {
    controller = ScreenshotController();
    scroll = ScrollController();
  });
  tearDown(() => scroll.dispose());

  Future<CaptureResult> captureRaw() => controller.captureScrollable(
    scroll,
    format: ImageFormat.rawRgba,
    pixelRatio: 1,
  );

  testWidgets('captures every item of a vertical list', (tester) async {
    await show(
      tester,
      Screenshot(
        controller: controller,
        child: ListView.builder(
          controller: scroll,
          itemCount: 100,
          itemExtent: 50,
          itemBuilder: (_, i) => ColoredBox(color: colorOf(i)),
        ),
      ),
    );

    final raw = await captureRaw();

    expect(raw.height, 100 * 50);
    for (final i in [0, 1, 37, 58, 99]) {
      expect(pixelAt(raw, 10, i * 50 + 25), isColor(colorOf(i)), reason: '$i');
    }
  });

  testWidgets('restores the scroll position', (tester) async {
    await show(
      tester,
      Screenshot(
        controller: controller,
        child: ListView.builder(
          controller: scroll,
          itemCount: 60,
          itemExtent: 50,
          itemBuilder: (_, i) => ColoredBox(color: colorOf(i)),
        ),
      ),
    );
    scroll.jumpTo(321);
    await tester.pump();

    await captureRaw();

    expect(scroll.offset, 321);
  });

  testWidgets('measures lazy lists with varying item heights', (tester) async {
    double heightOf(int i) => 20.0 + (i % 5) * 15;
    await show(
      tester,
      Screenshot(
        controller: controller,
        child: ListView.builder(
          controller: scroll,
          itemCount: 120,
          itemBuilder: (_, i) => SizedBox(
            height: heightOf(i),
            child: ColoredBox(color: colorOf(i)),
          ),
        ),
      ),
    );

    final raw = await captureRaw();

    final total = List.generate(120, heightOf).reduce((a, b) => a + b);
    expect(raw.height, total.round());
    final top = List.generate(119, heightOf).reduce((a, b) => a + b);
    expect(pixelAt(raw, 10, (top + 5).round()), isColor(colorOf(119)));
  });

  testWidgets('leaves out app bars around the scroll view', (tester) async {
    await show(
      tester,
      Screenshot(
        controller: controller,
        child: Scaffold(
          appBar: AppBar(title: const Text('Title')),
          body: ListView.builder(
            controller: scroll,
            itemCount: 40,
            itemExtent: 50,
            itemBuilder: (_, i) => ColoredBox(color: colorOf(i)),
          ),
        ),
      ),
    );

    final raw = await captureRaw();

    expect(raw.height, 40 * 50);
    expect(pixelAt(raw, 10, 5), isColor(colorOf(0)));
  });

  testWidgets('captures horizontal lists', (tester) async {
    await show(
      tester,
      Screenshot(
        controller: controller,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 80,
            child: ListView.builder(
              controller: scroll,
              scrollDirection: Axis.horizontal,
              itemCount: 50,
              itemExtent: 60,
              itemBuilder: (_, i) => ColoredBox(color: colorOf(i)),
            ),
          ),
        ),
      ),
    );

    final raw = await captureRaw();

    expect((raw.width, raw.height), (50 * 60, 80));
    expect(pixelAt(raw, 49 * 60 + 30, 40), isColor(colorOf(49)));
  });

  testWidgets('short content gives one viewport-sized image', (tester) async {
    await show(
      tester,
      Screenshot(
        controller: controller,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 300,
            child: ListView(
              controller: scroll,
              children: const [SizedBox(height: 100)],
            ),
          ),
        ),
      ),
    );

    final raw = await captureRaw();

    expect(raw.height, 300);
  });

  testWidgets('rejects an unattached controller', (tester) async {
    await show(
      tester,
      Screenshot(controller: controller, child: const SizedBox.expand()),
    );

    await expectLater(
      captureRaw(),
      throwsA(
        isA<ScreenshotException>().having(
          (e) => e.reason,
          'reason',
          ScreenshotFailure.invalidScrollController,
        ),
      ),
    );
  });

  testWidgets('rejects a scroll view outside the Screenshot widget', (
    tester,
  ) async {
    await show(
      tester,
      Column(
        children: [
          Screenshot(
            controller: controller,
            child: const SizedBox(width: 10, height: 10),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ],
      ),
    );

    await expectLater(
      captureRaw(),
      throwsA(
        isA<ScreenshotException>().having(
          (e) => e.reason,
          'reason',
          ScreenshotFailure.invalidScrollController,
        ),
      ),
    );
  });
}
