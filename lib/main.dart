import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/book_repository.dart';
import 'data/sqlite_book_repository.dart';
import 'screens/home_shell.dart';
import 'services/extraction_queue.dart';
import 'services/ml_kit_text_extractor.dart';
import 'services/photo_storage_service.dart';
import 'services/sinhala_aware_text_extractor.dart';
import 'services/tesseract_sinhala_extractor.dart';
import 'theme/app_theme.dart';

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
            extractor: SinhalaAwareTextExtractor(
              primary: MlKitTextExtractor(),
              sinhala: TesseractSinhalaExtractor(),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Bookie Bookie',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    );
  }
}
