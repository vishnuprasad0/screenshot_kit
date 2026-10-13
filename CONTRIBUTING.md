# Contributing

Thanks for helping improve `screenshot_kit`. Bug reports, fixes, new
features, tests and documentation are all welcome.

## Ways to contribute

- **Report a bug** with the bug report template. Include a minimal
  reproduction and the `ScreenshotException` reason if there is one.
- **Suggest a feature** with the feature request template.
- **Fix a bug or improve the code.** Small fixes can go straight to a pull
  request. For larger changes, open an issue first so we can agree on the
  approach before you spend time on it.

## Workflow

1. Fork the repository and create a branch from `main`.
2. Make your change, with tests that fail without it.
3. Run the checks below.
4. Open a pull request that describes the problem and the fix, and links the
   issue it closes.

## Setup

```sh
flutter pub get
```

## Before opening a pull request

Run the same checks as CI:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
```

For changes to the native code or the example app, build the example and run
its integration tests on a device or simulator:

```sh
cd example
flutter pub get
flutter analyze
flutter test integration_test -d <device id>
```

## Guidelines

- Captures need real frames and real async image work, so widget tests use a
  live frame binding instead of the fake-async one. Start from
  `test/support/live.dart` (`useLiveFrames`, `show`, `pixelAt`).
- Check pixels, not just that bytes came back: capture as raw RGBA and assert
  on colours, as the existing tests do.
- Platform code (`android/`, `ios/`) cannot be covered by `flutter test`. The
  tests in `example/integration_test` run on a device or simulator; run them
  when you change native code.
- Every public member needs a doc comment.
- Keep the `screenshot` 3.0.0 method signatures on `ScreenshotController`
  unchanged. Behaviour fixes are fine; signature changes are not.
- Add a `CHANGELOG.md` entry for user-visible changes.

## Reporting bugs

Open an issue with the package version, platform and device, a minimal
reproduction, and the exception you see. For `captureScreen` problems, say
whether the screen contains platform views (maps, web views, ads).
