// Real, dart:io-backed local CSV cache — used on iOS/Android/desktop
// (anywhere dart:library.io is available). See csv_cache_stub.dart for
// the web counterpart and csv_loader.dart for the conditional import
// that picks between them.
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> _contentDir(String subfolder) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$subfolder');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String?> readCachedContent(String subfolder, String fileName) async {
  try {
    final dir = await _contentDir(subfolder);
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      return await file.readAsString(encoding: utf8);
    }
  } catch (_) {}
  return null;
}

Future<void> writeCachedContent(
  String subfolder,
  String fileName,
  String content,
) async {
  try {
    final dir = await _contentDir(subfolder);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);
  } catch (_) {}
}
