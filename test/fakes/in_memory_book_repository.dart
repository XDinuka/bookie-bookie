import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/models/book.dart';

/// A pure in-memory [BookRepository] for widget tests.
///
/// Widget tests should exercise UI behavior against a fake data layer, not
/// real sqlite plumbing (that's what book_repository_test.dart is for) — and
/// separately, `dart:ffi` calls through sqflite_common_ffi hang indefinitely
/// under the `flutter_tester` engine used by `testWidgets` in this
/// environment, so a real database isn't a workable option here anyway.
class InMemoryBookRepository implements BookRepository {
  final List<Book> _books = [];
  int _nextId = 1;

  @override
  Future<int> insert(Book book) async {
    final id = _nextId++;
    _books.add(
      Book(
        id: id,
        isbn: book.isbn,
        title: book.title,
        author: book.author,
        coverUrl: book.coverUrl,
        coverImagePath: book.coverImagePath,
        extraPhotoPaths: book.extraPhotoPaths,
        needsReview: book.needsReview,
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
      ),
    );
    return id;
  }

  @override
  Future<void> update(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) _books[index] = book;
  }

  @override
  Future<void> delete(int id) async {
    _books.removeWhere((b) => b.id == id);
  }

  @override
  Future<Book?> getById(int id) async {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<Book?> getByIsbn(String isbn) async {
    for (final book in _books) {
      if (book.isbn == isbn) return book;
    }
    return null;
  }

  @override
  Future<List<Book>> getAll() async => List.unmodifiable(_books);

  @override
  Future<List<Book>> search(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return getAll();
    return _books.where((book) {
      return (book.title?.toLowerCase().contains(trimmed) ?? false) ||
          (book.author?.toLowerCase().contains(trimmed) ?? false) ||
          (book.isbn?.toLowerCase().contains(trimmed) ?? false);
    }).toList();
  }
}
