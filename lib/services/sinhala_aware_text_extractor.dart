import 'isbn_utils.dart';
import 'text_extraction_service.dart';

/// Runs [primary] (ML Kit, Latin-script) first, and only adds a second
/// pass from [sinhala] (Tesseract) if [primary]'s own lines already turned
/// up an ISBN candidate in Sri Lanka's registration group (955).
///
/// Tesseract is much slower and more battery-hungry than ML Kit, and most
/// captures won't be Sri Lankan books — the ISBN itself isn't known until
/// after some OCR has run, but a 955 prefix on whatever ML Kit already
/// found is a strong, cheap signal that the Sinhala pass is actually worth
/// paying for.
class SinhalaAwareTextExtractor implements TextExtractor {
  SinhalaAwareTextExtractor({required this.primary, required this.sinhala});

  final TextExtractor primary;
  final TextExtractor sinhala;

  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    final primaryResult = await primary.extract(photoPaths);

    final looksSriLankan = primaryResult.lines.any(
      (line) => IsbnUtils.extractCandidates(line).any(IsbnUtils.isSriLankan),
    );
    if (!looksSriLankan) return primaryResult;

    final sinhalaResult = await sinhala.extract(photoPaths);
    final seen = primaryResult.lines.toSet();
    final merged = [...primaryResult.lines];
    for (final line in sinhalaResult.lines) {
      if (seen.add(line)) merged.add(line);
    }
    return ExtractionResult(lines: merged);
  }
}
