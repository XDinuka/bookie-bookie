import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies photos the user captured (which live in a temp/cache location
/// managed by image_picker) into permanent app storage, so they survive
/// after the picker's temp file is cleaned up.
class PhotoStorageService {
  Future<String> saveImage(String sourcePath, {String prefix = 'photo'}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(docsDir.path, 'book_photos'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final fileName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}$ext';
    final destPath = p.join(booksDir.path, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
