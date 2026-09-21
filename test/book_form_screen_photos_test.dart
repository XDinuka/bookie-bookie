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

  testWidgets(
    'the photo-for-detection section is visible even with no photos yet',
    (tester) async {
      final repository = InMemoryBookRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<BookRepository>.value(value: repository)],
          child: const MaterialApp(home: BookFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photos for text detection'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    },
  );

  testWidgets('shows an existing book\'s photos as thumbnails', (tester) async {
    final repository = InMemoryBookRepository();
    final now = DateTime.now();
    final id = await repository.insert(
      Book(
        title: 'Some Book',
        extraPhotoPaths: const ['/tmp/one.jpg', '/tmp/two.jpg'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final book = (await repository.getById(id))!;

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<BookRepository>.value(value: repository)],
        child: MaterialApp(home: BookFormScreen(existingBook: book)),
      ),
    );
    await tester.pumpAndSettle();

    // Two saved photos plus the always-present "add another" tile.
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });
}
