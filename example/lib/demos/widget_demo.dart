import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

import '../preview_page.dart';

/// Demo 1: capture a widget that is on screen.
///
/// The card is wrapped in [Screenshot]; the controls map one to one onto the
/// parameters of [ScreenshotController.captureImage].
class WidgetCaptureDemo extends StatefulWidget {
  const WidgetCaptureDemo({super.key});

  @override
  State<WidgetCaptureDemo> createState() => _WidgetCaptureDemoState();
}

class _WidgetCaptureDemoState extends State<WidgetCaptureDemo> {
  final _controller = ScreenshotController();

  ImageFormat _format = ImageFormat.png;
  double _quality = 85;
  int _ratio = 0; // 0 means the device's pixel ratio.
  bool _limitWidth = false;
  bool _background = false;

  Future<CaptureResult> _capture() {
    return _controller.captureImage(
      format: _format,
      quality: _quality.round(),
      pixelRatio: _ratio == 0 ? null : _ratio.toDouble(),
      // A maximum width lowers the pixel ratio until the image fits.
      maxWidth: _limitWidth ? 400 : null,
      // Fills the transparent corners of the card (and is JPEG's backdrop).
      background: _background ? Colors.amber.shade200 : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jpeg = _format == ImageFormat.jpeg;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget capture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Screenshot(
              controller: _controller,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: _ProductCard(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Format', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ImageFormat>(
            segments: const [
              ButtonSegment(value: ImageFormat.png, label: Text('PNG')),
              ButtonSegment(value: ImageFormat.jpeg, label: Text('JPEG')),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 16),
          Text(
            'JPEG quality: ${_quality.round()}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Slider(
            value: _quality,
            min: 1,
            max: 100,
            divisions: 99,
            label: _quality.round().toString(),
            onChanged: jpeg ? (v) => setState(() => _quality = v) : null,
          ),
          Text('Pixel ratio', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1x')),
              ButtonSegment(value: 2, label: Text('2x')),
              ButtonSegment(value: 3, label: Text('3x')),
              ButtonSegment(value: 0, label: Text('Device')),
            ],
            selected: {_ratio},
            onSelectionChanged: (s) => setState(() => _ratio = s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Max width 400 px'),
            subtitle: const Text('Lowers the pixel ratio to fit'),
            value: _limitWidth,
            onChanged: (v) => setState(() => _limitWidth = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Background colour'),
            subtitle: const Text('Drawn under transparent areas'),
            value: _background,
            onChanged: (v) => setState(() => _background = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: CaptureButton(label: 'Capture', capture: _capture),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A65), Color(0xFFE91E63), Color(0xFF5E35B1)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white24,
            child: Icon(Icons.rocket_launch, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Rocket Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lift-off in one tap',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    r'$49.00',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              for (var i = 0; i < 5; i++)
                Icon(
                  i < 4 ? Icons.star : Icons.star_half,
                  color: Colors.yellow.shade300,
                  size: 20,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
