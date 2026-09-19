import '../models/book.dart';

/// All reads/writes to the catalog go through this interface — screens
/// never touch sqflite (or any other storage) directly. [SqliteBookRepository]
/// is the real, on-device implementation; tests use a lightweight in-memory
/// fake instead so widget tests don't depend on a real database.
abstract class BookRepository {
  Future<int> insert(Book book);
  Future<void> update(Book book);
  Future<void> delete(int id);
  Future<Book?> getById(int id);
  Future<Book?> getByIsbn(String isbn);
  Future<List<Book>> getAll();

  /// Filters by title, author, or ISBN — the only management the README
  /// calls for. Empty/blank query returns the full catalog.
  Future<List<Book>> search(String query);
}
