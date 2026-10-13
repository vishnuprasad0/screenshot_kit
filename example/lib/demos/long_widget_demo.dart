import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

import '../preview_page.dart';

/// Demo 4: the `screenshot` package's `captureFromLongWidget` still works,
/// and the result is not truncated.
///
/// The receipt is taller than the screen and is never shown.
class LongWidgetDemo extends StatelessWidget {
  const LongWidgetDemo({super.key});

  Future<CaptureResult> _capture(BuildContext context) async {
    // The old API returns only the PNG bytes.
    final bytes = await ScreenshotController().captureFromLongWidget(
      const Receipt(lineItems: 60),
      context: context,
      pixelRatio: 2,
    );
    // Read the size back so the preview can show it.
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final result = CaptureResult(
      bytes: bytes,
      width: frame.image.width,
      height: frame.image.height,
      format: ImageFormat.png,
    );
    frame.image.dispose();
    codec.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Long widget')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.receipt_long,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'A 60-line receipt',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'The receipt is built off-screen and captured with the old '
              'captureFromLongWidget API. It is much taller than the screen '
              'and comes out in full.',
            ),
            const SizedBox(height: 24),
            CaptureButton(
              label: 'Capture receipt',
              icon: Icons.receipt_long_outlined,
              capture: () => _capture(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tall receipt: a header, [lineItems] lines and a total.
class Receipt extends StatelessWidget {
  const Receipt({super.key, required this.lineItems});

  final int lineItems;

  @override
  Widget build(BuildContext context) {
    var total = 0.0;
    final rows = <Widget>[];
    for (var i = 0; i < lineItems; i++) {
      final price = 2.5 + (i * 7 % 23) * 1.25;
      total += price;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 32, child: Text('${i + 1}.')),
              Expanded(child: Text('Item number ${i + 1}')),
              Text(price.toStringAsFixed(2)),
            ],
          ),
        ),
      );
    }
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 48),
              const SizedBox(height: 8),
              const Text(
                'CORNER SHOP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 32),
              ...rows,
              const Divider(height: 32),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    total.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Thank you!', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
