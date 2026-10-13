/// Capture widgets, long scroll views and the whole screen, including maps
/// and web views, as PNG or JPEG.
///
/// A maintained, drop-in successor to the `screenshot` package (MIT,
/// Sachin Ganesh): the `Screenshot` widget and `ScreenshotController` keep
/// their API, so switching only needs a new import.
library;

export 'src/capture/in_tree_render.dart' show ScreenshotHost;
export 'src/capture_result.dart' show CaptureResult, ImageFormat;
export 'src/errors.dart' show ScreenshotException, ScreenshotFailure;
export 'src/native/desktop_plugin.dart' show ScreenshotKitDesktop;
export 'src/native/screen_capture.dart' show ScreenshotKit;
export 'src/screenshot.dart'
    show Ex, Screenshot, ScreenshotController, ScreenshotState;
