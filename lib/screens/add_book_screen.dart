import 'package:flutter/material.dart';

import 'book_form_screen.dart';
import 'manual_entry_screen.dart';
import 'scan_screen.dart';

/// Three ways to add a book: scan a barcode, type just the ISBN (with a
/// lookup), or type everything by hand. Photo capture for OCR-assisted
/// extraction isn't a separate add flow — it lives inside a single book's
/// view (see [BookFormScreen]) since it's something you do to one book you
/// already have open, not a way of starting one.
class AddBookScreen extends StatelessWidget {
  const AddBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a book')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Scan barcode'),
            subtitle: const Text("Point the camera at the book's ISBN barcode"),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Enter ISBN manually'),
            subtitle: const Text("For when a barcode won't scan"),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Enter details manually'),
            subtitle: const Text(
              "For books with no ISBN, or when lookup won't have data",
            ),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const BookFormScreen())),
          ),
        ],
      ),
    );
  }
}
