import 'package:flutter/material.dart';

import 'manual_entry_screen.dart';
import 'photo_capture_screen.dart';
import 'scan_screen.dart';

/// The three ways to add a book, per the README: scan a barcode, type an
/// ISBN, or capture photos for a book barcode lookup won't have data for.
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
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Capture photos'),
            subtitle: const Text(
              "For books where barcode lookup won't have data",
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
