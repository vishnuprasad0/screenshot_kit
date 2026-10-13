import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

/// Runs [capture], then shows the result on a [PreviewPage].
///
/// A [ScreenshotException] is shown in a SnackBar together with its reason.
Future<void> captureAndPreview(
  BuildContext context,
  Future<CaptureResult> Function() capture,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final stopwatch = Stopwatch()..start();
  try {
    final result = await capture();
    stopwatch.stop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PreviewPage(result: result, elapsed: stopwatch.elapsed),
      ),
    );
  } on ScreenshotException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${e.reason.name}: ${e.message}'),
          duration: const Duration(seconds: 6),
        ),
      );
  }
}

/// A button that starts a capture, shows a spinner while it runs and opens
/// the result in a [PreviewPage].
class CaptureButton extends StatefulWidget {
  const CaptureButton({
    super.key,
    required this.label,
    required this.capture,
    this.icon = Icons.photo_camera_outlined,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final Future<CaptureResult> Function() capture;

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await captureAndPreview(context, widget.capture);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon);
    final onPressed = _busy ? null : _run;
    return widget.filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(widget.label),
          )
        : FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: icon,
            label: Text(widget.label),
          );
  }
}

/// Shows a captured image on a checkerboard (so transparency is visible)
/// inside an [InteractiveViewer], with its size, format and capture time.
class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key, required this.result, required this.elapsed});

  final CaptureResult result;
  final Duration elapsed;

  /// For example "1206 x 2622 px · PNG · 412 KB · 85 ms".
  String get summary {
    final kb = (result.bytes.length / 1024).round();
    return '${result.width} x ${result.height} px · '
        '${result.format.name.toUpperCase()} · $kb KB · '
        '${elapsed.inMilliseconds} ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Shown at the screen's width; pinch to zoom, drag to scroll.
                final width = constraints.maxWidth;
                return InteractiveViewer(
                  constrained: false,
                  minScale: 0.5,
                  maxScale: 8,
                  child: SizedBox(
                    width: width,
                    child: CustomPaint(
                      painter: const _CheckerboardPainter(),
                      child: Image.memory(
                        result.bytes,
                        key: const Key('preview-image'),
                        width: width,
                        fit: BoxFit.fitWidth,
                        // Decode at most this wide, so very tall images stay
                        // within the GPU texture limits.
                        cacheWidth: math.min(result.width, 1600),
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            elevation: 3,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    summary,
                    key: const Key('preview-summary'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  static const double _cell = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFF2F2F2);
    final dark = Paint()..color = const Color(0xFFCFCFCF);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0; y * _cell < size.height; y++) {
      for (var x = y.isEven ? 0 : 1; x * _cell < size.width; x += 2) {
        canvas.drawRect(
          Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
