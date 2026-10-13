import 'dart:io';
import 'dart:typed_data';

/// Writes [bytes] to [name] in [directory], creating the directory if
/// needed, and returns the file's path.
Future<String> saveFile(Uint8List bytes, String directory, String name) async {
  final file = await File('$directory/$name').create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
