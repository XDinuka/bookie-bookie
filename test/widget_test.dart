import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/models/book.dart';
import 'package:bookie_bookie/models/reading_status.dart';
import 'package:bookie_bookie/screens/catalog_screen.dart';
import 'package:bookie_bookie/services/extraction_queue.dart';
import 'package:bookie_bookie/services/photo_storage_service.dart';

import 'fakes/in_memory_book_repository.dart';

void main() {
  Widget buildApp(BookRepository repository) {
    return MultiProvider(
      providers: [
        Provider<BookRepository>.value(value: repository),
        Provider<PhotoStorageService>(create: (_) => PhotoStorageService()),
        Provider<ExtractionQueue>(
          create: (context) => ExtractionQueue(repository: repository),
        ),
      ],
      child: const MaterialApp(home: CatalogScreen()),
    );
  }

  testWidgets('shows the empty-catalog prompt when there are no books', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(InMemoryBookRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No books yet'), findsOneWidget);
  });

  testWidgets('lists a saved book and finds it via search', (tester) async {
    final repository = InMemoryBookRepository();
    final now = DateTime.now();
    await repository.insert(
      Book(
        title: 'Pride and Prejudice',
        author: 'Jane Austen',
        isbn: '9780141439518',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Pride and Prejudice'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nonexistent query');
    await tester.pumpAndSettle();

    expect(find.text('Pride and Prejudice'), findsNothing);
  });

  testWidgets('filters the list by reading status', (tester) async {
    final repository = InMemoryBookRepository();
    final now = DateTime.now();
    await repository.insert(
      Book(
        title: 'Currently Reading This',
        readingStatus: ReadingStatus.reading,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insert(
      Book(
        title: 'On The Wishlist',
        readingStatus: ReadingStatus.wishlist,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading This'), findsOneWidget);
    expect(find.text('On The Wishlist'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Reading'));
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading This'), findsOneWidget);
    expect(find.text('On The Wishlist'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading This'), findsOneWidget);
    expect(find.text('On The Wishlist'), findsOneWidget);
  });
}
