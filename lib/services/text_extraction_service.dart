/// Best-guess title/author/ISBN pulled from a book's photos.
class ExtractionResult {
  final String? title;
  final String? author;
  final String? isbn;

  const ExtractionResult({this.title, this.author, this.isbn});

  bool get isEmpty => title == null && author == null && isbn == null;
}

/// Runs OCR/text extraction over a set of photos captured for one book.
///
/// There is currently no free, on-device OCR engine with good Sinhala
/// support (see README — ML Kit and Vision don't support it, Tesseract's
/// Sinhala model is weak on stylized cover typography), and titles/authors
/// on this audience's book covers are frequently Sinhala script. Wiring in
/// an engine that mostly fails would give a false sense of accuracy without
/// solving the actual problem.
///
/// [NoOpTextExtractor] keeps the async "capture now, extract in the
/// background, flag for review" pipeline fully working end-to-end without
/// pretending to have OCR it doesn't. Swap in a real engine behind this same
/// interface once one clears the accuracy bar for this audience.
abstract class TextExtractor {
  Future<ExtractionResult> extract(List<String> photoPaths);
}

class NoOpTextExtractor implements TextExtractor {
  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    return const ExtractionResult();
  }
}
