# screenshot_kit example

A Material 3 app with five demos of `screenshot_kit`. Each demo captures
something and shows the result on a preview page (a zoomable image on a
checkerboard, with its size, format, byte size and capture time).

| Demo | What it shows |
| --- | --- |
| Widget capture | `captureImage` with format, JPEG quality, pixel ratio, maximum width and background colour |
| Off-screen widget | `captureWidget(widget, context: context)` for a widget that is never shown, reading an app-level provider; `ScreenshotHost` for a provider declared inside a page |
| Long list | `captureScrollable` on a 200-row `ListView` |
| Long widget | the old `captureFromLongWidget` on a 60-line receipt taller than the screen |
| Screen with WebView | `ScreenshotKit.captureScreen()` includes the WebView; a widget capture leaves it blank |

## In code

```dart
final controller = ScreenshotController();

// 1. Wrap what you want to capture.
Screenshot(controller: controller, child: const ReceiptCard());

// 2. Capture it: PNG by default, or JPEG, resized, with a background.
final png = await controller.captureImage();
final jpeg = await controller.captureImage(
  format: ImageFormat.jpeg,
  quality: 85,
  maxWidth: 1080,
);

// 3. Capture a widget that is never shown. The context lets it read your
//    providers, theme and localizations.
final card = await controller.captureWidget(const ShareCard(), context: context);

// 4. Capture every row of a scroll view inside the Screenshot widget.
final list = await controller.captureScrollable(scrollController);

// 5. Capture the whole screen, including maps and web views (Android, iOS).
if (ScreenshotKit.isScreenCaptureSupported) {
  final screen = await ScreenshotKit.captureScreen();
}
```

The full code of each demo is in [`lib/demos/`](lib/demos).

## Run

```sh
cd example
flutter pub get
flutter run                 # a connected device, emulator or simulator
flutter run -d chrome       # web
flutter run -d macos        # macOS
```

`ScreenshotKit.captureScreen()` works on Android and iOS only. On other
platforms the WebView demo explains this instead of capturing, and the web
view itself is not shown.

The example enables Swift Package Manager for iOS in its `pubspec.yaml`
(`flutter: config: enable-swift-package-manager: true`), so the plugin is
integrated without CocoaPods.

## Tests

```sh
flutter test                                    # widget tests
flutter test integration_test -d <device id>    # on a device
```

The integration tests capture the screen with a web view, then open every
demo, trigger its capture and check the size of the result.
