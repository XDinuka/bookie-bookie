import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/models/book.dart';
import 'package:bookie_bookie/models/reading_status.dart';
import 'package:bookie_bookie/screens/book_form_screen.dart';

import 'fakes/in_memory_book_repository.dart';

void main() {
  // See book_form_screen_ocr_test.dart for why: the form is a single
  // scrolling column, and Flutter's sliver list doesn't mount off-screen
  // children, so a normal test-sized viewport can leave the Save button
  // unfindable.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      2400,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  testWidgets('defaults to To Read for a brand-new book', (tester) async {
    final repository = InMemoryBookRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<BookRepository>.value(value: repository)],
        child: const MaterialApp(home: BookFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ReadingStatus>>(
      find.byType(SegmentedButton<ReadingStatus>),
    );
    expect(segmented.selected, {ReadingStatus.toRead});
  });

  testWidgets('selecting a status and saving persists it', (tester) async {
    final repository = InMemoryBookRepository();
    final now = DateTime.now();
    final id = await repository.insert(
      Book(title: 'Some Book', createdAt: now, updatedAt: now),
    );
    final book = (await repository.getById(id))!;

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<BookRepository>.value(value: repository)],
        child: MaterialApp(home: BookFormScreen(existingBook: book)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reading'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = await repository.getById(id);
    expect(saved!.readingStatus, ReadingStatus.reading);
  });
}
