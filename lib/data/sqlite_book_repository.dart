import '../models/book.dart';
import 'book_repository.dart';
import 'database_helper.dart';

/// The real, on-device [BookRepository], backed by sqflite.
class SqliteBookRepository implements BookRepository {
  SqliteBookRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  @override
  Future<int> insert(Book book) async {
    final db = await _databaseHelper.database;
    return db.insert('books', book.toMap()..remove('id'));
  }

  @override
  Future<void> update(Book book) async {
    assert(book.id != null, 'Cannot update a book with no id');
    final db = await _databaseHelper.database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Book?> getById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  @override
  Future<Book?> getByIsbn(String isbn) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'books',
      where: 'isbn = ?',
      whereArgs: [isbn],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  @override
  Future<List<Book>> getAll() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('books', orderBy: 'updated_at DESC');
    return rows.map(Book.fromMap).toList();
  }

  @override
  Future<List<Book>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAll();

    final db = await _databaseHelper.database;
    final like = '%$trimmed%';
    final rows = await db.query(
      'books',
      where: 'title LIKE ? OR author LIKE ? OR isbn LIKE ?',
      whereArgs: [like, like, like],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Book.fromMap).toList();
  }
}
