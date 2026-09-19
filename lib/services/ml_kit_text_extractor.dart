import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'text_extraction_service.dart';

/// Runs on-device (Latin-script) OCR over a book's captured photos.
///
/// It deliberately does not try to guess which recognized line is the
/// title, author, or ISBN — this audience's covers are frequently Sinhala
/// script or stylized typography that trips up automated classification
/// (see README) even when the raw text comes through fine, so guessing
/// would just add confident-looking wrong answers. Instead it hands back
/// every distinct line it found and lets the review screen's line picker
/// do the sorting.
class MlKitTextExtractor implements TextExtractor {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    final lines = <String>[];
    final seen = <String>{};

    for (final path in photoPaths) {
      try {
        final recognized = await _recognizer.processImage(
          InputImage.fromFilePath(path),
        );
        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            final text = line.text.trim();
            if (text.isEmpty || !seen.add(text)) continue;
            lines.add(text);
          }
        }
      } catch (_) {
        // One unreadable photo (corrupt file, decode failure) shouldn't
        // sink extraction for the rest of the book's photos.
      }
    }

    return ExtractionResult(lines: lines);
  }

  void dispose() {
    _recognizer.close();
  }
}
