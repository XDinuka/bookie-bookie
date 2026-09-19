import '../data/book_repository.dart';
import 'text_extraction_service.dart';

/// Runs extraction jobs for photo-captured books one at a time in the
/// background, so cataloging a stack of books is never blocked waiting on
/// any single one — capture moves on immediately, results land whenever
/// they land.
class ExtractionQueue {
  ExtractionQueue({
    required BookRepository repository,
    TextExtractor? extractor,
  }) : _repository = repository,
       _extractor = extractor ?? NoOpTextExtractor();

  final BookRepository _repository;
  final TextExtractor _extractor;

  Future<void> _tail = Future.value();

  /// Fire-and-forget: chains this job onto the queue and returns
  /// immediately without waiting for it to run.
  void enqueue(int bookId, List<String> photoPaths) {
    _tail = _tail.then((_) => _process(bookId, photoPaths));
  }

  Future<void> _process(int bookId, List<String> photoPaths) async {
    final result = await _extractor.extract(photoPaths);
    if (result.isEmpty) return;

    final book = await _repository.getById(bookId);
    if (book == null) return; // deleted while extraction was running

    await _repository.update(
      book.copyWith(
        title: result.title ?? book.title,
        author: result.author ?? book.author,
        isbn: result.isbn ?? book.isbn,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
