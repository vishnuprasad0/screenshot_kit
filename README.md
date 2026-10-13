# screenshot_kit

Capture widgets, long scroll views and the whole screen, including maps and web views, as PNG or JPEG. A maintained, drop-in successor to [`screenshot`](https://pub.dev/packages/screenshot).

[![pub package](https://img.shields.io/pub/v/screenshot_kit.svg)](https://pub.dev/packages/screenshot_kit)
[![CI](https://github.com/vishnuprasad0/screenshot_kit/actions/workflows/ci.yaml/badge.svg)](https://github.com/vishnuprasad0/screenshot_kit/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Demo

<table>
  <tr>
    <td align="center">
      <img src="https://raw.githubusercontent.com/vishnuprasad0/screenshot_kit/main/doc/media/widget_capture.gif" width="240" alt="Capturing a widget as PNG"><br>
      <sub>Capture a widget</sub>
    </td>
    <td align="center">
      <img src="https://raw.githubusercontent.com/vishnuprasad0/screenshot_kit/main/doc/media/offscreen_capture.gif" width="240" alt="Capturing a widget that is never shown on screen"><br>
      <sub>Capture an off-screen widget</sub>
    </td>
    <td align="center">
      <img src="https://raw.githubusercontent.com/vishnuprasad0/screenshot_kit/main/doc/media/long_list.gif" width="240" alt="Scrolling through the capture of a 200 row list"><br>
      <sub>Capture a whole long list</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://raw.githubusercontent.com/vishnuprasad0/screenshot_kit/main/doc/media/long_widget.gif" width="240" alt="Capturing a receipt taller than the screen"><br>
      <sub>Capture a widget taller than the screen</sub>
    </td>
    <td align="center">
      <img src="https://raw.githubusercontent.com/vishnuprasad0/screenshot_kit/main/doc/media/webview_capture.gif" width="240" alt="Capturing the screen including a native WebView"><br>
      <sub>Capture the screen including a WebView</sub>
    </td>
    <td></td>
  </tr>
</table>

## Features

- Same `Screenshot` widget and `ScreenshotController` as `screenshot` 3.0.0. Migrating means changing the dependency and the import.
- `captureImage`, `captureWidget` and `captureScrollable` return a `CaptureResult` (bytes, width, height, format) and throw a `ScreenshotException` with a `ScreenshotFailure` reason instead of returning `null`.
- PNG, JPEG (with quality, white background by default) and raw RGBA, with `pixelRatio`, `maxWidth`, `maxHeight` and `background`.
- Long widgets are captured in tiles, so they are not cut off or blurry on Impeller.
- Waits for images to load instead of a fixed delay.
- Off-screen captures render at the nearest `ScreenshotHost` or `Overlay`, so Provider, localizations and theme work. An isolated pipeline is the fallback when there is no context.
- `ScreenshotKit.captureScreen` captures the whole window on Android and iOS, including platform views such as Google Maps, web views and ads.

## Install

```sh
flutter pub add screenshot_kit
```

```dart
import 'package:screenshot_kit/screenshot_kit.dart';
```

## Quick start

Wrap what you want to capture in a `Screenshot` widget and call the controller.

```dart
import 'package:flutter/material.dart';
import 'package:screenshot_kit/screenshot_kit.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final controller = ScreenshotController();

  Future<void> save() async {
    final result = await controller.captureImage();
    debugPrint('${result.width}x${result.height}, ${result.bytes.length} bytes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Screenshot(
        controller: controller,
        child: const Text('Total: 42.00'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: save,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
```

`captureImage` waits up to `imageTimeout` (10 seconds by default) for images inside the widget to load, then for the frame to finish. You do not need a delay.

## Capture a widget that isn't on screen

`captureWidget` renders a widget off-screen and captures it. Pass a `context` so the widget can use your providers, localizations, theme and media query.

```dart
Future<CaptureResult> captureCard(BuildContext context) {
  return ScreenshotController().captureWidget(
    const Card(child: Text('Hello')),
    context: context,
    constraints: const BoxConstraints(maxWidth: 400),
  );
}
```

By default the widget can be at most the screen size. Pass `constraints` to capture something taller than the screen or to fix its width.

The widget is rendered at the nearest `ScreenshotHost` above the context, or at the app's `Overlay` if there is none. If a provider lives inside one page, put a `ScreenshotHost` below it so captures started from that page can see it.

```dart
// Inside the page's providers, wrap the page body:
Widget buildCartPage(Widget page) => ScreenshotHost(child: page);
```

For example `BlocProvider(create: ..., child: ScreenshotHost(child: CartPage()))`. Widgets captured with a context from inside `CartPage` can then read the bloc.

With no `context`, the widget is rendered in an isolated pipeline that has no providers, localizations or theme.

## Capture a whole scroll view

`captureScrollable` scrolls the view one screen at a time, stitches the pieces together and puts the scroll position back. The scroll view must be inside the `Screenshot` widget, and the controller must be attached to it.

```dart
class LongList extends StatefulWidget {
  const LongList({super.key});

  @override
  State<LongList> createState() => _LongListState();
}

class _LongListState extends State<LongList> {
  final screenshot = ScreenshotController();
  final scroll = ScrollController();

  Future<CaptureResult> captureAll() {
    return screenshot.captureScrollable(scroll, format: ImageFormat.jpeg);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: screenshot,
      child: ListView.builder(
        controller: scroll,
        itemCount: 200,
        itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
      ),
    );
  }
}
```

Only the scrolling area is captured. App bars or other widgets around the scroll view inside the `Screenshot` widget are left out.

## Capture the screen including maps and web views

Widget captures cannot include platform views. `ScreenshotKit.captureScreen` asks the platform for the window as shown, so Google Maps, web views and ads are included, along with the status bar area and dialogs.

```dart
Future<CaptureResult?> captureWindow() async {
  if (!ScreenshotKit.isScreenCaptureSupported) return null;
  return ScreenshotKit.captureScreen(maxWidth: 1080);
}
```

Elsewhere it throws a `ScreenshotException` with `ScreenshotFailure.unsupportedPlatform`. After adding the package, do a full rebuild so the native plugin is registered.

## Formats and size

Every capture method takes the same output options.

```dart
Future<void> exportOptions(ScreenshotController controller) async {
  final jpeg = await controller.captureImage(
    format: ImageFormat.jpeg,
    quality: 85,
    background: Colors.white,
    maxWidth: 1080,
  );

  final raw = await controller.captureImage(format: ImageFormat.rawRgba);
  // 4 bytes per pixel, RGBA order, straight alpha, rows from the top.
  debugPrint('${raw.width}x${raw.height}, ${raw.bytes.length} bytes');
  debugPrint(jpeg.format.name);
}
```

| Option | Meaning |
| --- | --- |
| `format` | `ImageFormat.png` (default), `jpeg` or `rawRgba`. |
| `quality` | JPEG quality, 1 to 100. Default 90. |
| `pixelRatio` | Physical pixels per logical pixel. Defaults to the device's ratio. |
| `maxWidth`, `maxHeight` | Lower the pixel ratio so the image fits. |
| `background` | Colour drawn under transparent areas. JPEG uses white if you give none. |

`CaptureResult.width` and `height` are in physical pixels.

## Error handling

The new methods throw `ScreenshotException`. Check `reason` to decide what to do.

```dart
Future<void> safeCapture(ScreenshotController controller) async {
  try {
    final result = await controller.captureImage();
    debugPrint('Captured ${result.width}x${result.height}');
  } on ScreenshotException catch (e) {
    switch (e.reason) {
      case ScreenshotFailure.notAttached:
        debugPrint('No Screenshot widget uses this controller.');
      case ScreenshotFailure.tooLarge:
        debugPrint('Too large; try a lower pixelRatio or maxWidth.');
      default:
        debugPrint('${e.reason.name}: ${e.message}');
    }
  }
}
```

| Reason | Meaning |
| --- | --- |
| `notAttached` | The `Screenshot` widget for this controller is not in the tree. |
| `notReady` | The widget has not been laid out or painted yet, or has zero size. |
| `tooLarge` | The capture does not fit in memory or exceeds a platform limit. |
| `encodingFailed` | Encoding the image failed. |
| `invalidScrollController` | The scroll controller is not attached to exactly one scroll view inside the `Screenshot` widget. |
| `unsupportedPlatform` | Native screen capture is not available here. |
| `platformError` | The platform reported an error while capturing. |

The `screenshot` 3.0.0 methods `capture` and `captureAsUiImage` still return `null` when the widget is not attached or not ready.

## Migrating from screenshot

In `pubspec.yaml`:

```yaml
dependencies:
  screenshot_kit: ^1.0.0   # was: screenshot: ^3.0.0
```

In your code:

```dart
import 'package:screenshot_kit/screenshot_kit.dart'; // was: package:screenshot/screenshot.dart
```

Nothing else changes: `Screenshot`, `ScreenshotController`, `capture`, `captureAsUiImage`, `captureAndSave`, `captureFromWidget`, `captureFromLongWidget`, `widgetToUiImage` and `longWidgetToUiImage` have the same signatures.

What behaves differently:

- **Pixel ratio.** The off-screen methods (`captureFromWidget`, `captureFromLongWidget` and the `ui.Image` variants) default to the device's pixel ratio, so long captures are sharp. Pass `pixelRatio: 1` to get a smaller image. `captureAsUiImage` still defaults to 1.
- **`delay` is a maximum.** On the off-screen methods, `delay` is the longest time to wait for images to load. The capture continues as soon as they have loaded instead of always waiting.
- **More is inherited.** When you pass a `context`, the widget is rendered inside your tree at a `ScreenshotHost` or `Overlay`, so providers, localizations and theme work.
- **Long widgets are tiled.** Very tall widgets are no longer truncated.

## Platform support

| Platform | Widget and scroll capture | `captureScreen` |
| --- | --- | --- |
| Android | Yes | Yes |
| iOS | Yes | Yes |
| Web | Yes | No |
| macOS | Yes | No |
| Windows | Yes | No |
| Linux | Yes | No |

`captureAndSave` is not available on the web.

## Limitations

- Platform views (maps, web views, ads, video) are only captured by `ScreenshotKit.captureScreen`.
- Scrollbars and animations appear as they are rendered at the moment of capture.
- `captureScrollable` needs the scroll view to be inside the `Screenshot` widget.
- Very large captures are limited to 512 MB of RGBA pixels. Lower `pixelRatio` or set `maxWidth` and `maxHeight`; otherwise a `tooLarge` exception is thrown.
- `captureAsUiImage` renders in one pass, so very large widgets can exceed the platform's texture size. Use `captureImage` for those.

## Credits

Based on [screenshot](https://pub.dev/packages/screenshot) by Sachin Ganesh ([source](https://github.com/SachinGanesh/screenshot)), released under the MIT license.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
