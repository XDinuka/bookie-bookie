import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/models/book.dart';
import 'package:bookie_bookie/screens/book_form_screen.dart';

import 'fakes/in_memory_book_repository.dart';

void main() {
  // See book_form_screen_ocr_test.dart for why: a normal test-sized
  // viewport can leave later parts of this scrolling form unmounted.
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

  Widget buildApp(BookRepository repository, {Book? existingBook}) {
    return MultiProvider(
      providers: [Provider<BookRepository>.value(value: repository)],
      child: MaterialApp(home: BookFormScreen(existingBook: existingBook)),
    );
  }

  testWidgets('typing a custom tag and submitting adds it as a chip', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(InMemoryBookRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'My Own Label');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'My Own Label'), findsOneWidget);
    // The field clears after adding.
    expect(find.text('My Own Label'), findsOneWidget);
  });

  testWidgets('suggests popular genres while typing and adds on tap', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(InMemoryBookRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Ficti');
    await tester.pumpAndSettle();

    expect(find.text('Fiction'), findsOneWidget);

    await tester.tap(find.text('Fiction'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Fiction'), findsOneWidget);
  });

  testWidgets('removing a tag deletes its chip', (tester) async {
    final repository = InMemoryBookRepository();
    final now = DateTime.now();
    final id = await repository.insert(
      Book(
        title: 'Book',
        tags: const ['Fantasy'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final book = (await repository.getById(id))!;

    await tester.pumpWidget(buildApp(repository, existingBook: book));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Fantasy'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Fantasy'),
        matching: find.byType(Icon),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Fantasy'), findsNothing);
  });

  testWidgets('saving persists the tags', (tester) async {
    final repository = InMemoryBookRepository();
    final now = DateTime.now();
    final id = await repository.insert(
      Book(title: 'Book', createdAt: now, updatedAt: now),
    );
    final book = (await repository.getById(id))!;

    await tester.pumpWidget(buildApp(repository, existingBook: book));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Mystery');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = await repository.getById(id);
    expect(saved!.tags, ['Mystery']);
  });
}
