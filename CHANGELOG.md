## 1.0.1 - 2026-11-18
- Docs: README now leads with tiled tall-widget capture and includes a measured
  comparison on Impeller/Vulkan, including the exact 16,384 px single-pass
  cutoff and how `pixelRatio` multiplies it.
- Docs: the migration section states explicitly that migrating does not add
  platform-view capture; that requires the separate `ScreenshotKit.captureScreen`
  call, which is Android and iOS only.
- Docs: fixed dartdoc references that could not resolve from this package.
- `screenshot.dart` imports `package:flutter/widgets.dart` rather than
  `material.dart`, narrowing the import surface. No API change.
## 1.0.0 - 2026-10-13

First release of `screenshot_kit`, an API-compatible alternative to the
`screenshot` package with tiled capture for tall widgets. Based on
screenshot 3.0.0 by Sachin Ganesh (MIT).

Compatible with screenshot 3.0.0: `Screenshot` and `ScreenshotController` keep
their method signatures, so migrating means changing the dependency and the
import.

### Added

* `ScreenshotController.captureImage`, `captureWidget` and `captureScrollable`,
  returning a `CaptureResult` (bytes, width, height, format).
* PNG, JPEG (with `quality`, white background by default) and raw RGBA output,
  with `pixelRatio`, `maxWidth`, `maxHeight` and `background` options.
* `ScreenshotException` with a `ScreenshotFailure` reason, thrown instead of
  returning `null`.
* `ScreenshotHost`, so off-screen captures can use providers that live inside
  a page.
* `ScreenshotKit.captureScreen` and `ScreenshotKit.isScreenCaptureSupported`:
  native capture of the whole window on Android and iOS, including platform
  views such as Google Maps, web views and ads.

### Fixed

Issue numbers refer to SachinGanesh/screenshot.

* A fixed 1 second wait before capturing; images are now awaited until they
  load (#64, #205).
* Provider and other inherited widgets lost in off-screen captures (#199).
* Images missing from off-screen captures (#107, #114).
* Long widgets truncated or blurry; they are now captured in tiles (#191,
  #204, #207).
* Scroll views could not be captured in full (#79, #112, #175).
* Failures returned `null` with no reason (#84, #171, #195).
* The off-screen widget tree was never disposed (#109).
* PNG only, with no background option (#124).
* Platform views were not captured (#24, #62, #208).
