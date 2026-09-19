import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/book.dart';
import '../services/extraction_queue.dart';
import '../services/photo_storage_service.dart';

/// For books where barcode lookup won't have data — the common case for
/// this audience. Take a few photos (cover, spine, title page, whatever's
/// legible), save immediately flagged for review, and let extraction run in
/// the background while the user moves straight on to the next book.
class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final List<String> _photoPaths = [];
  bool _busy = false;
  int _savedCount = 0;

  Future<void> _takePhoto() async {
    setState(() => _busy = true);
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null && mounted) {
      final saved = await context.read<PhotoStorageService>().saveImage(
        picked.path,
      );
      setState(() => _photoPaths.add(saved));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveAndCaptureNext() async {
    if (_photoPaths.isEmpty) return;
    final repository = context.read<BookRepository>();
    final extractionQueue = context.read<ExtractionQueue>();
    final now = DateTime.now();

    final photos = List<String>.of(_photoPaths);
    final id = await repository.insert(
      Book(
        coverImagePath: photos.first,
        extraPhotoPaths: photos,
        needsReview: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    extractionQueue.enqueue(id, photos);

    if (!mounted) return;
    setState(() {
      _savedCount += 1;
      _photoPaths.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved — flagged for review. On to the next one.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture photos'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_savedCount > 0 ? 'Done ($_savedCount saved)' : 'Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _photoPaths.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Take a few photos of the book — cover, spine, title page, '
                        'whatever is legible. Extraction runs in the background '
                        'once you save.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _photoPaths.length,
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_photoPaths[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _photoPaths.isEmpty ? null : _saveAndCaptureNext,
                    icon: const Icon(Icons.check),
                    label: const Text('Save book'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
