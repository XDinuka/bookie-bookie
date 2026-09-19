import 'text_extraction_service.dart';

/// Runs several extractors over the same photos and merges their lines
/// (in order, exact duplicates removed) into one list. Used to combine
/// ML Kit's Latin-script recognition with Tesseract's Sinhala pass, since
/// neither one alone covers what's actually on a typical cover for this
/// audience.
class CombinedTextExtractor implements TextExtractor {
  CombinedTextExtractor(this._extractors);

  final List<TextExtractor> _extractors;

  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    final lines = <String>[];
    final seen = <String>{};

    for (final extractor in _extractors) {
      final result = await extractor.extract(photoPaths);
      for (final line in result.lines) {
        if (seen.add(line)) lines.add(line);
      }
    }

    return ExtractionResult(lines: lines);
  }
}
