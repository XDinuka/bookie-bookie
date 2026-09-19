import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

import 'text_extraction_service.dart';

/// Runs Tesseract's Sinhala (+ English) trained model over a book's photos.
///
/// Google ML Kit's on-device recognizer doesn't support Sinhala script at
/// all, and Tesseract's own Sinhala model is known to be weaker than its
/// Latin one — especially on the stylized typography common on book covers
/// (see README). So this runs as a *second pass* alongside
/// [MlKitTextExtractor] rather than a replacement for it: between the two,
/// more of what's actually printed on the cover ends up in front of the
/// user to pick from, even if some of it is imperfect.
class TesseractSinhalaExtractor implements TextExtractor {
  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    final lines = <String>[];
    final seen = <String>{};

    for (final path in photoPaths) {
      try {
        final text = await FlutterTesseractOcr.extractText(
          path,
          language: 'sin+eng',
          args: const {'psm': '4', 'preserve_interword_spaces': '1'},
        );
        for (final rawLine in text.split('\n')) {
          final line = rawLine.trim();
          if (line.isEmpty || !seen.add(line)) continue;
          lines.add(line);
        }
      } catch (_) {
        // One unreadable photo shouldn't sink extraction for the rest.
      }
    }

    return ExtractionResult(lines: lines);
  }
}
