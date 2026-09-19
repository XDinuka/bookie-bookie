import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/book_repository.dart';
import 'data/sqlite_book_repository.dart';
import 'screens/catalog_screen.dart';
import 'services/extraction_queue.dart';
import 'services/ml_kit_text_extractor.dart';
import 'services/photo_storage_service.dart';

void main() {
  runApp(const BookieBookieApp());
}

class BookieBookieApp extends StatelessWidget {
  const BookieBookieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BookRepository>(create: (_) => SqliteBookRepository()),
        Provider<PhotoStorageService>(create: (_) => PhotoStorageService()),
        Provider<ExtractionQueue>(
          create: (context) => ExtractionQueue(
            repository: context.read<BookRepository>(),
            extractor: MlKitTextExtractor(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Bookie Bookie',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const CatalogScreen(),
      ),
    );
  }
}
