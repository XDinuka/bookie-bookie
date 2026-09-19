import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/models/book.dart';
import 'package:bookie_bookie/screens/book_form_screen.dart';

import 'fakes/in_memory_book_repository.dart';

void main() {
  // The form is a single scrolling column (cover, detected lines, fields,
  // photos, save button); a couple of detected-line cards easily push the
  // fields below a normal test-sized viewport, and Flutter's sliver list
  // doesn't mount off-screen children. Use a tall surface so everything is
  // laid out and findable without needing to scroll mid-test.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      4000,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Future<Book> insertBookWithLines(
    InMemoryBookRepository repository,
    List<String> lines,
  ) async {
    final now = DateTime.now();
    final id = await repository.insert(
      Book(needsReview: true, ocrLines: lines, createdAt: now, updatedAt: now),
    );
    return (await repository.getById(id))!;
  }

  TextField findFieldLabeled(WidgetTester tester, String label) {
    return tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      ),
    );
  }

  testWidgets('tapping a detected line fills the matching field', (
    tester,
  ) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, [
      'The Great Gatsby',
      'F. Scott Fitzgerald',
      '9780743273565',
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<BookRepository>.value(value: repository)],
        child: MaterialApp(home: BookFormScreen(existingBook: book)),
      ),
    );
    await tester.pumpAndSettle();

    // All three detected lines should be shown for the user to pick from.
    expect(find.text('The Great Gatsby'), findsOneWidget);
    expect(find.text('F. Scott Fitzgerald'), findsOneWidget);
    expect(find.text('9780743273565'), findsOneWidget);

    // Fields start blank.
    expect(findFieldLabeled(tester, 'Title').controller?.text, isEmpty);

    // Assign each detected line to a field via its chip.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Title').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Author').at(1));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'ISBN').at(2));
    await tester.pump();

    expect(
      findFieldLabeled(tester, 'Title').controller?.text,
      'The Great Gatsby',
    );
    expect(
      findFieldLabeled(tester, 'Author').controller?.text,
      'F. Scott Fitzgerald',
    );
    expect(findFieldLabeled(tester, 'ISBN').controller?.text, '9780743273565');
  });

  testWidgets('reassigning a field moves the selection to the new line', (
    tester,
  ) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, [
      'Wrong Title Guess',
      'Actual Title',
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<BookRepository>.value(value: repository)],
        child: MaterialApp(home: BookFormScreen(existingBook: book)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Title').at(0));
    await tester.pump();
    expect(
      findFieldLabeled(tester, 'Title').controller?.text,
      'Wrong Title Guess',
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Title').at(1));
    await tester.pump();
    expect(findFieldLabeled(tester, 'Title').controller?.text, 'Actual Title');
  });
}
