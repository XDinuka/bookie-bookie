/// Text pulled from a book's photos.
///
/// [lines] is every distinct line OCR recognized, in detection order —
/// the primary output. [title]/[author]/[isbn] are for an extractor that's
/// confident enough to guess; none of the extractors currently in this app
/// set them (see [MlKitTextExtractor]), since guessing wrong is worse than
/// just handing the raw lines to the user.
class ExtractionResult {
  final String? title;
  final String? author;
  final String? isbn;
  final List<String> lines;

  const ExtractionResult({
    this.title,
    this.author,
    this.isbn,
    this.lines = const [],
  });

  bool get isEmpty =>
      title == null && author == null && isbn == null && lines.isEmpty;
}

/// Runs OCR/text extraction over a set of photos captured for one book.
///
/// There is currently no free, on-device OCR engine with good Sinhala
/// support (see README — ML Kit and Vision don't support it, Tesseract's
/// Sinhala model is weak on stylized cover typography), and titles/authors
/// on this audience's book covers are frequently Sinhala script. So rather
/// than guess which recognized line is the title vs. the author vs. the
/// ISBN — a guess OCR itself can't be trusted to get right — every
/// extractor here just surfaces the raw lines and lets the user sort them
/// out in the review screen.
abstract class TextExtractor {
  Future<ExtractionResult> extract(List<String> photoPaths);
}

class NoOpTextExtractor implements TextExtractor {
  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    return const ExtractionResult();
  }
}
