import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../preview_page.dart';

const _html = '''
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { margin: 0; font-family: sans-serif; background: #fff8e1; }
  h1 { margin: 0; padding: 16px; background: #ff6f00; color: white; }
  .blocks { display: flex; }
  .blocks div { flex: 1; height: 64px; }
  p { padding: 0 16px; }
</style>
</head>
<body>
  <h1>Hello from a WebView</h1>
  <div class="blocks">
    <div style="background:#d32f2f"></div>
    <div style="background:#388e3c"></div>
    <div style="background:#1976d2"></div>
  </div>
  <p>This page is rendered by the platform, not by Flutter.</p>
</body>
</html>
''';

/// Demo 5: a screen with a platform view.
///
/// `ScreenshotKit.captureScreen()` asks the platform for a picture of the
/// whole window, so the WebView is included. A widget capture only sees what
/// Flutter paints itself, and leaves the WebView blank.
class WebViewDemo extends StatefulWidget {
  const WebViewDemo({super.key});

  @override
  State<WebViewDemo> createState() => _WebViewDemoState();
}

class _WebViewDemoState extends State<WebViewDemo> {
  final _controller = ScreenshotController();
  WebViewController? _web;

  @override
  void initState() {
    super.initState();
    // webview_flutter only has Android and iOS implementations here.
    if (ScreenshotKit.isScreenCaptureSupported) {
      _web = WebViewController()..loadHtmlString(_html);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ScreenshotKit.isScreenCaptureSupported;
    return Scaffold(
      appBar: AppBar(title: const Text('Screen with WebView')),
      body: Column(
        children: [
          Expanded(
            child: Screenshot(
              controller: _controller,
              child: Column(
                children: [
                  const Expanded(child: _FlutterHalf()),
                  Expanded(
                    child: _web == null
                        ? const _Unavailable()
                        : WebViewWidget(controller: _web!),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!supported)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'ScreenshotKit.captureScreen() is only available on '
                        'Android and iOS. On this platform use a widget '
                        'capture instead.',
                        key: Key('unsupported-message'),
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      CaptureButton(
                        label: 'Capture screen',
                        icon: Icons.smartphone,
                        // Throws a ScreenshotException where unsupported.
                        capture: () => ScreenshotKit.captureScreen(),
                      ),
                      CaptureButton(
                        label: 'Widget capture',
                        icon: Icons.widgets_outlined,
                        filled: false,
                        // The WebView comes out blank here.
                        capture: () => _controller.captureImage(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlutterHalf extends StatelessWidget {
  const _FlutterHalf();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3949AB), Color(0xFF00ACC1)],
        ),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlutterLogo(size: 72),
          SizedBox(height: 12),
          Text(
            'Flutter content',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEEEEEE),
      child: Center(child: Text('WebView is not available on this platform')),
    );
  }
}
