import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bookie_bookie/data/database_helper.dart';
import 'package:bookie_bookie/data/sqlite_book_repository.dart';
import 'package:bookie_bookie/models/book.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late SqliteBookRepository repository;
  late DatabaseHelper databaseHelper;
  late String dbPath;

  setUp(() {
    // A uniquely-named database per test — reusing the literal
    // `inMemoryDatabasePath` string across tests hits sqflite's global
    // singleton-by-path cache, so every "fresh" repository would actually
    // share the same underlying database and leak rows between tests.
    dbPath =
        '${Directory.systemTemp.path}/bookie_bookie_test_'
        '${DateTime.now().microsecondsSinceEpoch}.db';
    databaseHelper = DatabaseHelper.withPath(dbPath);
    repository = SqliteBookRepository(databaseHelper: databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
    final file = File(dbPath);
    if (await file.exists()) await file.delete();
  });

  Book newBook({
    String? isbn,
    String? title,
    String? author,
    bool needsReview = false,
  }) {
    final now = DateTime.now();
    return Book(
      isbn: isbn,
      title: title,
      author: author,
      needsReview: needsReview,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('insert then getAll round-trips a book', () async {
    await repository.insert(
      newBook(isbn: '9780141439518', title: 'Pride and Prejudice'),
    );

    final all = await repository.getAll();

    expect(all, hasLength(1));
    expect(all.first.title, 'Pride and Prejudice');
    expect(all.first.isbn, '9780141439518');
  });

  test(
    'getByIsbn finds an existing entry and returns null otherwise',
    () async {
      await repository.insert(
        newBook(isbn: '9780141439518', title: 'Pride and Prejudice'),
      );

      expect(
        (await repository.getByIsbn('9780141439518'))?.title,
        'Pride and Prejudice',
      );
      expect(await repository.getByIsbn('0000000000000'), isNull);
    },
  );

  test('search matches title, author, or isbn', () async {
    await repository.insert(
      newBook(
        isbn: '9780141439518',
        title: 'Pride and Prejudice',
        author: 'Jane Austen',
      ),
    );
    await repository.insert(
      newBook(
        isbn: '9780446310789',
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
      ),
    );

    expect(await repository.search('Austen'), hasLength(1));
    expect(await repository.search('Mockingbird'), hasLength(1));
    expect(await repository.search('9780141439518'), hasLength(1));
    expect(await repository.search(''), hasLength(2));
    expect(await repository.search('nonexistent'), isEmpty);
  });

  test('update persists field changes and clears needsReview', () async {
    final id = await repository.insert(newBook(title: null, needsReview: true));
    final saved = (await repository.getAll()).single;

    await repository.update(
      saved.copyWith(title: 'Now Titled', needsReview: false),
    );

    final updated = await repository.getById(id);
    expect(updated!.title, 'Now Titled');
    expect(updated.needsReview, isFalse);
  });

  test('insert then getAll round-trips ocrLines', () async {
    final now = DateTime.now();
    await repository.insert(
      Book(
        needsReview: true,
        ocrLines: const [
          'THE GREAT GATSBY',
          'F. Scott Fitzgerald',
          'garbled spine text',
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final saved = (await repository.getAll()).single;

    expect(saved.ocrLines, [
      'THE GREAT GATSBY',
      'F. Scott Fitzgerald',
      'garbled spine text',
    ]);
  });

  test('delete removes the entry', () async {
    final id = await repository.insert(newBook(title: 'Gone Soon'));

    await repository.delete(id);

    expect(await repository.getById(id), isNull);
    expect(await repository.getAll(), isEmpty);
  });
}
