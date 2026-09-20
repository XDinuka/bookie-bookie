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

  Future<void> pumpForm(WidgetTester tester, Book book) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BookRepository>.value(value: InMemoryBookRepository()),
        ],
        child: MaterialApp(home: BookFormScreen(existingBook: book)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('selecting a word and assigning it fills the field', (
    tester,
  ) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, ['The Great Gatsby']);
    await pumpForm(tester, book);

    // All words of the line should be shown as individually tappable chips.
    expect(find.widgetWithText(ChoiceChip, 'The'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Great'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Gatsby'), findsOneWidget);

    // Nothing selected yet, so the assign buttons are disabled.
    final titleButtonBefore = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '→ Title'),
    );
    expect(titleButtonBefore.onPressed, isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, 'The'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Great'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Gatsby'));
    await tester.pump();

    expect(find.text('Selected: The Great Gatsby'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '→ Title'));
    await tester.pump();

    expect(
      findFieldLabeled(tester, 'Title').controller?.text,
      'The Great Gatsby',
    );
    // Assigning clears the working selection.
    expect(
      find.text('Tap words above, then assign them to a field'),
      findsOneWidget,
    );
  });

  testWidgets(
    'combines words picked from two different lines, in document order',
    (tester) async {
      final repository = InMemoryBookRepository();
      final book = await insertBookWithLines(repository, ['John', 'Smith']);
      await pumpForm(tester, book);

      // Tap out of document order; the assigned text should still read in
      // document order, not tap order.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Smith'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'John'));
      await tester.pump();

      expect(find.text('Selected: John Smith'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '→ Author'));
      await tester.pump();

      expect(findFieldLabeled(tester, 'Author').controller?.text, 'John Smith');
    },
  );

  testWidgets('the whole-line shortcut selects and deselects every word', (
    tester,
  ) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, ['Some publisher note']);
    await pumpForm(tester, book);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pump();
    expect(find.text('Selected: Some publisher note'), findsOneWidget);

    // Tapping again deselects the whole line.
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pump();
    expect(
      find.text('Tap words above, then assign them to a field'),
      findsOneWidget,
    );
  });

  testWidgets('reassigning a field just overwrites its text', (tester) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, [
      'Wrong Guess',
      'Actual Title',
    ]);
    await pumpForm(tester, book);

    await tester.tap(find.byIcon(Icons.checklist).at(0));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '→ Title'));
    await tester.pump();
    expect(findFieldLabeled(tester, 'Title').controller?.text, 'Wrong Guess');

    await tester.tap(find.byIcon(Icons.checklist).at(1));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '→ Title'));
    await tester.pump();
    expect(findFieldLabeled(tester, 'Title').controller?.text, 'Actual Title');
  });

  testWidgets('auto-fills the ISBN field when a line looks like one', (
    tester,
  ) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, [
      'The Great Gatsby',
      'ISBN 978-0-14-143951-8',
    ]);
    await pumpForm(tester, book);

    // Filled automatically, with the digits only — no need to tap anything.
    expect(findFieldLabeled(tester, 'ISBN').controller?.text, '9780141439518');
    expect(
      find.textContaining('Looks like ISBN 9780141439518'),
      findsOneWidget,
    );
  });

  testWidgets('assigning a selected ISBN line uses the extracted digits', (
    tester,
  ) async {
    final repository = InMemoryBookRepository();
    final book = await insertBookWithLines(repository, [
      'ISBN 978-0-14-143951-8',
      '9780446310789',
    ]);
    await pumpForm(tester, book);

    // Two different candidates, so it shouldn't guess — starts blank.
    expect(findFieldLabeled(tester, 'ISBN').controller?.text, isEmpty);

    await tester.tap(find.byIcon(Icons.checklist).at(1));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '→ ISBN'));
    await tester.pump();

    expect(findFieldLabeled(tester, 'ISBN').controller?.text, '9780446310789');
  });
}
