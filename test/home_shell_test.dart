import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/screens/home_shell.dart';
import 'package:bookie_bookie/services/extraction_queue.dart';
import 'package:bookie_bookie/services/photo_storage_service.dart';

import 'fakes/in_memory_book_repository.dart';

void main() {
  Widget buildApp() {
    final repository = InMemoryBookRepository();
    return MultiProvider(
      providers: [
        Provider<BookRepository>.value(value: repository),
        Provider<PhotoStorageService>(create: (_) => PhotoStorageService()),
        Provider<ExtractionQueue>(
          create: (context) => ExtractionQueue(repository: repository),
        ),
      ],
      child: const MaterialApp(home: HomeShell()),
    );
  }

  // "Add"/"My Books"/"Settings" are the bottom nav button labels and are
  // always on screen regardless of which tab is active, so assertions use
  // content unique to each tab's body instead.
  const catalogEmptyState =
      'No books yet. Use Add below to scan a barcode, type an ISBN, or capture photos.';
  const addScreenTitle = 'Add a book';
  const settingsBody = 'Nothing here yet.';

  testWidgets('defaults to My Books', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text(catalogEmptyState), findsOneWidget);
    expect(find.text(addScreenTitle), findsNothing);
    expect(find.text(settingsBody), findsNothing);
  });

  testWidgets('the left button switches to Add, the right to Settings', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tapping the nav row's label text wouldn't hit anything — the label
    // sits below the FloatingActionButton as a separate, non-tappable
    // sibling — so target the FAB itself, identified by its icon.
    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.add));
    await tester.pumpAndSettle();
    expect(find.text(addScreenTitle), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Enter ISBN manually'), findsOneWidget);
    expect(find.text('Capture photos'), findsOneWidget);

    await tester.tap(
      find.widgetWithIcon(FloatingActionButton, Icons.settings),
    );
    await tester.pumpAndSettle();
    expect(find.text(settingsBody), findsOneWidget);
    expect(find.text(addScreenTitle), findsNothing);

    await tester.tap(
      find.widgetWithIcon(FloatingActionButton, Icons.menu_book),
    );
    await tester.pumpAndSettle();
    expect(find.text(catalogEmptyState), findsOneWidget);
    expect(find.text(settingsBody), findsNothing);
  });

  testWidgets('there is no floating add button on My Books anymore', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Exactly three FABs total: the bottom nav row, none extra from the
    // old per-screen add button.
    expect(find.byType(FloatingActionButton), findsNWidgets(3));
  });
}
