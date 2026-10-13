import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'demos/long_list_demo.dart';
import 'demos/long_widget_demo.dart';
import 'demos/offscreen_demo.dart';
import 'demos/webview_demo.dart';
import 'demos/widget_demo.dart';

void main() => runApp(const ExampleApp());

/// Home of the screenshot_kit example: a list of demos.
///
/// Each demo captures something and shows the result on a shared preview page
/// (see preview_page.dart).
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // App-level state, provided above MaterialApp like a real provider would
  // be. The off-screen demo shows that captured widgets can read it.
  final _settings = AppSettings();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: _settings,
      child: MaterialApp(
        title: 'screenshot_kit',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class _Demo {
  const _Demo(this.title, this.subtitle, this.icon, this.builder);

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

final _demos = <_Demo>[
  // 1. Capture a widget on screen with captureImage: format, quality,
  //    pixel ratio, maximum width and background colour.
  _Demo(
    'Widget capture',
    'A card on screen, with PNG/JPEG, ratio and size options',
    Icons.crop_original,
    (_) => const WidgetCaptureDemo(),
  ),
  // 2. Capture widgets that are never shown, using providers from the app
  //    (captureWidget with a context) and from a page (ScreenshotHost).
  _Demo(
    'Off-screen widget',
    'A share card built off-screen that reads app providers',
    Icons.visibility_off_outlined,
    (_) => const OffscreenDemo(),
  ),
  // 3. Capture every row of a 200-item ListView with captureScrollable.
  _Demo(
    'Long list',
    'Capture a whole ListView, not only the visible rows',
    Icons.view_list,
    (_) => const LongListDemo(),
  ),
  // 4. The old captureFromLongWidget API on a widget taller than the screen.
  _Demo(
    'Long widget',
    'A 60-line receipt through the screenshot package API',
    Icons.receipt_long,
    (_) => const LongWidgetDemo(),
  ),
  // 5. Capture the whole screen including a WebView, and compare with a
  //    widget capture, which leaves the WebView blank.
  _Demo(
    'Screen with WebView',
    'captureScreen includes platform views',
    Icons.language,
    (_) => const WebViewDemo(),
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('screenshot_kit')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _demos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final demo = _demos[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: Key('demo-$i'),
              leading: Icon(demo.icon),
              title: Text(demo.title),
              subtitle: Text(demo.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: demo.builder)),
            ),
          );
        },
      ),
    );
  }
}
