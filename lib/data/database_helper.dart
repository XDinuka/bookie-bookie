import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and creates, on first run) the single local sqlite database that
/// backs the whole catalog. There's no backend and no sync, so this is the
/// entire persistence layer.
class DatabaseHelper {
  DatabaseHelper._({String? path}) : _explicitPath = path;

  /// For tests: pass e.g. `inMemoryDatabasePath` (from `sqflite_common`)
  /// with the ffi database factory so repository tests can run on the host
  /// without a real device.
  factory DatabaseHelper.withPath(String path) => DatabaseHelper._(path: path);

  static final DatabaseHelper instance = DatabaseHelper._();

  final String? _explicitPath;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opened = await _open();
    _database = opened;
    return opened;
  }

  Future<Database> _open() async {
    final path =
        _explicitPath ?? join(await getDatabasesPath(), 'bookie_bookie.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            isbn TEXT,
            title TEXT,
            author TEXT,
            cover_url TEXT,
            cover_image_path TEXT,
            extra_photo_paths TEXT NOT NULL DEFAULT '[]',
            needs_review INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_books_isbn ON books (isbn)');
      },
    );
  }

  Future<void> close() async {
    final existing = _database;
    if (existing != null) {
      await existing.close();
      _database = null;
    }
  }
}
