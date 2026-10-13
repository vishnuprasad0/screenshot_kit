import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot_kit/screenshot_kit.dart';
import 'package:screenshot_kit/src/capture/capture_boundary.dart';

import 'support/live.dart';

const red = Color(0xFFFF0000);
const green = Color(0xFF00FF00);
const blue = Color(0xFF0000FF);

/// Stands in for Provider, Bloc or Riverpod: an inherited value the captured
/// widget reads from its context.
class Paint extends InheritedWidget {
  const Paint({super.key, required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Paint>()!.color;

  @override
  bool updateShouldNotify(Paint old) => color != old.color;
}

class PaintedBox extends StatelessWidget {
  const PaintedBox({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: ColoredBox(color: Paint.of(context)),
  );
}

/// Captures the context of the widget it builds.
class ContextProbe extends StatelessWidget {
  const ContextProbe({super.key, required this.onContext});

  final void Function(BuildContext context) onContext;

  @override
  Widget build(BuildContext context) {
    onContext(context);
    return const SizedBox.expand();
  }
}

void main() {
  useLiveFrames();

  late ScreenshotController controller;
  setUp(() => controller = ScreenshotController());

  Future<CaptureResult> rawOf(Widget widget, {BuildContext? context}) =>
      controller.captureWidget(
        widget,
        context: context,
        format: ImageFormat.rawRgba,
        pixelRatio: 1,
      );

  group('captureWidget', () {
    testWidgets('renders without a context (isolated pipeline)', (
      tester,
    ) async {
      await show(tester, const SizedBox());

      final raw = await rawOf(
        const SizedBox(width: 30, height: 20, child: ColoredBox(color: red)),
      );

      expect((raw.width, raw.height), (30, 20));
      expect(pixelAt(raw, 15, 10), isColor(red));
    });

    testWidgets('inherits providers above the app (#199)', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Paint(
          color: green,
          child: MaterialApp(home: ContextProbe(onContext: (c) => context = c)),
        ),
      );

      final raw = await rawOf(const PaintedBox(), context: context);

      expect(pixelAt(raw, 20, 20), isColor(green));
    });

    testWidgets('ScreenshotHost passes on page-scoped providers', (
      tester,
    ) async {
      late BuildContext context;
      await show(
        tester,
        Paint(
          color: blue,
          child: ScreenshotHost(
            child: ContextProbe(onContext: (c) => context = c),
          ),
        ),
      );

      final raw = await rawOf(const PaintedBox(), context: context);

      expect(pixelAt(raw, 20, 20), isColor(blue));
    });

    testWidgets('removes the off-screen widget afterwards', (tester) async {
      late BuildContext context;
      await show(tester, ContextProbe(onContext: (c) => context = c));

      await rawOf(const SizedBox(width: 10, height: 10), context: context);
      await tester.pump();

      expect(find.byType(CaptureBoundary), findsNothing);
    });

    testWidgets('inherits the theme in the isolated pipeline', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Theme(
          data: ThemeData(canvasColor: green),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ContextProbe(onContext: (c) => context = c),
          ),
        ),
      );

      // No Overlay above this context, so the isolated pipeline is used.
      final raw = await rawOf(
        Builder(
          builder: (c) => SizedBox(
            width: 20,
            height: 20,
            child: ColoredBox(color: Theme.of(c).canvasColor),
          ),
        ),
        context: context,
      );

      expect(pixelAt(raw, 10, 10), isColor(green));
    });

    testWidgets('waits for images in off-screen widgets (#107)', (
      tester,
    ) async {
      await show(tester, const SizedBox());
      final pixel = img.Image(width: 2, height: 2)
        ..clear(img.ColorRgb8(0, 0, 255));

      final raw = await rawOf(
        SizedBox(
          width: 20,
          height: 20,
          child: Image.memory(img.encodePng(pixel), fit: BoxFit.fill),
        ),
      );

      expect(pixelAt(raw, 10, 10), isColor(blue));
    }, skip: vmOnly);
  });

  group('screenshot 3.0.0 API', () {
    testWidgets('captureFromWidget() returns PNG of the widget', (
      tester,
    ) async {
      await show(tester, const SizedBox());

      final png = await controller.captureFromWidget(
        const SizedBox(width: 30, height: 20, child: ColoredBox(color: red)),
        pixelRatio: 1,
      );

      final raw = await decode(png);
      expect((raw.width, raw.height), (30, 20));
    });

    testWidgets('captureFromWidget() keeps targetSize as the bound', (
      tester,
    ) async {
      await show(tester, const SizedBox());

      // A Container without a child expands to fill the bound.
      final png = await controller.captureFromWidget(
        Container(color: red),
        pixelRatio: 1,
        targetSize: const Size(60, 40),
      );

      final raw = await decode(png);
      expect((raw.width, raw.height), (60, 40));
    });

    testWidgets('captureFromLongWidget() captures past the screen height', (
      tester,
    ) async {
      await show(tester, const SizedBox());
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final color in [red, green, blue])
            SizedBox(width: 20, height: 1500, child: ColoredBox(color: color)),
        ],
      );

      final raw = await decode(
        await controller.captureFromLongWidget(column, pixelRatio: 2),
      );

      expect((raw.width, raw.height), (40, 9000));
      expect(pixelAt(raw, 20, 8990), isColor(blue));
    });

    testWidgets('widgetToUiImage() and longWidgetToUiImage()', (tester) async {
      await show(tester, const SizedBox());
      const widget = SizedBox(
        width: 30,
        height: 20,
        child: ColoredBox(color: red),
      );

      final a = await ScreenshotController.widgetToUiImage(
        widget,
        pixelRatio: 1,
      );
      final b = await controller.longWidgetToUiImage(widget, pixelRatio: 1);

      expect((a.width, a.height), (30, 20));
      expect((b.width, b.height), (30, 20));
      a.dispose();
      b.dispose();
    });
  });
}
