import 'dart:typed_data';

/// Writes [bytes] to [name] in [directory]. Not available without
/// `dart:io`, such as on the web.
Future<String> saveFile(Uint8List bytes, String directory, String name) =>
    throw UnsupportedError(
      'captureAndSave needs a file system. On the web, use capture() and '
      'download the bytes instead.',
    );
