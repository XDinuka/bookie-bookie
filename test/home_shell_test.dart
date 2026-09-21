import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bookie_bookie/data/book_repository.dart';
import 'package:bookie_bookie/screens/home_shell.dart';
import 'package:bookie_bookie/services/photo_storage_service.dart';
import 'package:bookie_bookie/services/text_extraction_service.dart';

import 'fakes/in_memory_book_repository.dart';

void main() {
  // AddBookScreen's ListView doesn't have enough room in a normal
  // test-sized viewport once the AppBar and the bottom nav bar eat into
  // it, and Flutter's sliver list doesn't mount off-screen children — see
  // book_form_screen_ocr_test.dart for the same issue. Use a tall surface.
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

  Widget buildApp() {
    final repository = InMemoryBookRepository();
    return MultiProvider(
      providers: [
        Provider<BookRepository>.value(value: repository),
        Provider<PhotoStorageService>(create: (_) => PhotoStorageService()),
        Provider<TextExtractor>(create: (_) => NoOpTextExtractor()),
      ],
      child: const MaterialApp(home: HomeShell()),
    );
  }

  // "Add"/"My Books"/"Settings" are the bottom nav button labels and are
  // always on screen regardless of which tab is active, so assertions use
  // content unique to each tab's body instead.
  const catalogEmptyState =
      'No books yet. Use Add below to scan a barcode, type an ISBN, or enter details.';
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
    // sits below the icon as a separate, non-tappable sibling inside the
    // same InkWell segment — so target the segment itself, identified by
    // its icon.
    await tester.tap(find.widgetWithIcon(InkWell, Icons.add));
    await tester.pumpAndSettle();
    expect(find.text(addScreenTitle), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Enter ISBN manually'), findsOneWidget);
    expect(find.text('Enter details manually'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(InkWell, Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text(settingsBody), findsOneWidget);
    expect(find.text(addScreenTitle), findsNothing);

    await tester.tap(find.widgetWithIcon(InkWell, Icons.menu_book));
    await tester.pumpAndSettle();
    expect(find.text(catalogEmptyState), findsOneWidget);
    expect(find.text(settingsBody), findsNothing);
  });

  testWidgets('the nav is a single floating bar, not separate buttons', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // No standalone FloatingActionButtons anywhere — the three
    // destinations are segments inside one shared Material bar.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithIcon(InkWell, Icons.add), findsOneWidget);
    expect(find.widgetWithIcon(InkWell, Icons.menu_book), findsOneWidget);
    expect(find.widgetWithIcon(InkWell, Icons.settings), findsOneWidget);
  });
}
