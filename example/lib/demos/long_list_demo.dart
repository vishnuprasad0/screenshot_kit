import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

import '../preview_page.dart';

/// Demo 3: capture a whole scrollable, not only the visible part.
///
/// `captureScrollable` scrolls the list one screen at a time, stitches the
/// pieces together and restores the scroll position.
class LongListDemo extends StatefulWidget {
  const LongListDemo({super.key});

  @override
  State<LongListDemo> createState() => _LongListDemoState();
}

class _LongListDemoState extends State<LongListDemo> {
  static const itemCount = 200;

  final _controller = ScreenshotController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Long list')),
      body: Column(
        children: [
          Expanded(
            // The scroll view (and its controller) must be inside Screenshot.
            child: Screenshot(
              controller: _controller,
              child: ListView.builder(
                controller: _scroll,
                itemCount: itemCount,
                itemBuilder: (context, i) => _Row(index: i),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CaptureButton(
                label: 'Capture whole list',
                icon: Icons.vertical_align_center,
                capture: () => _controller.captureScrollable(
                  _scroll,
                  format: ImageFormat.jpeg,
                  quality: 80,
                  // 1x keeps the 200-row image within GPU texture limits.
                  pixelRatio: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.index});

  final int index;

  static const _icons = [
    Icons.coffee,
    Icons.directions_bike,
    Icons.music_note,
    Icons.local_pizza,
    Icons.camera_alt,
    Icons.flight,
  ];

  @override
  Widget build(BuildContext context) {
    final hue = (index * 29) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.45).toColor();
    return Container(
      // Rows have three different heights.
      height: 56.0 + (index % 3) * 12,
      color: index.isEven ? Colors.grey.shade100 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(_icons[index % _icons.length], color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Item ${index + 1}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Text('#${index.toString().padLeft(3, '0')}'),
        ],
      ),
    );
  }
}
