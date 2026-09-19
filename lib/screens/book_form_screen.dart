import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/book.dart';
import '../services/isbn_lookup_service.dart';
import '../services/isbn_utils.dart';
import '../services/photo_storage_service.dart';

/// Create-or-edit form for a single catalog entry.
///
/// Used both as the confirm/edit step after a barcode scan or manual ISBN
/// entry (pass [initialIsbn]/[initialMetadata]) and as the plain edit/review
/// screen for any existing entry (pass [existingBook]) — title, author,
/// ISBN, and cover are all editable either way, which is what the README's
/// "review and correction" section calls for.
class BookFormScreen extends StatefulWidget {
  const BookFormScreen({
    super.key,
    this.existingBook,
    this.initialIsbn,
    this.initialMetadata,
  });

  final Book? existingBook;
  final String? initialIsbn;
  final BookMetadata? initialMetadata;

  bool get isEditing => existingBook != null;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _isbnController;

  String? _coverImagePath;
  String? _coverUrl;
  List<String> _extraPhotoPaths = const [];
  List<String> _ocrLines = const [];
  bool _saving = false;

  // Which detected line (if any) the user has assigned to each field, so
  // the matching chip can show as selected.
  int? _titleLineIndex;
  int? _authorLineIndex;
  int? _isbnLineIndex;

  // Line index -> the ISBN-shaped substring a regex found in that line, if
  // any. An ISBN barcode is unambiguous enough to detect automatically,
  // unlike title/author which genuinely need a human to pick.
  final Map<int, String> _isbnCandidates = {};

  @override
  void initState() {
    super.initState();
    final existing = widget.existingBook;
    _titleController = TextEditingController(
      text: existing?.title ?? widget.initialMetadata?.title ?? '',
    );
    _authorController = TextEditingController(
      text: existing?.author ?? widget.initialMetadata?.author ?? '',
    );
    _isbnController = TextEditingController(
      text: existing?.isbn ?? widget.initialIsbn ?? '',
    );
    _coverImagePath = existing?.coverImagePath;
    _coverUrl = existing?.coverUrl ?? widget.initialMetadata?.coverUrl;
    _extraPhotoPaths = existing?.extraPhotoPaths ?? const [];
    _ocrLines = existing?.ocrLines ?? const [];

    for (var i = 0; i < _ocrLines.length; i++) {
      final found = IsbnUtils.extractCandidates(_ocrLines[i]);
      if (found.isNotEmpty) _isbnCandidates[i] = found.first;
    }

    // Auto-fill the ISBN field when every detected candidate agrees on the
    // same number — still just a suggestion (the user can pick a different
    // line's chip instead), but a confident, unambiguous one.
    if (_isbnController.text.isEmpty && _isbnCandidates.isNotEmpty) {
      final distinct = _isbnCandidates.values.toSet();
      if (distinct.length == 1) {
        final firstIndex = _isbnCandidates.keys.first;
        _isbnController.text = _isbnCandidates[firstIndex]!;
        _isbnLineIndex = firstIndex;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _retakeCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    final savedPath = await context.read<PhotoStorageService>().saveImage(
      picked.path,
      prefix: 'cover',
    );
    if (!mounted) return;
    setState(() {
      _coverImagePath = savedPath;
      _coverUrl = null; // the fresh photo replaces any online cover
    });
  }

  void _assignLine(int index, _OcrField field) {
    setState(() {
      switch (field) {
        case _OcrField.title:
          _titleController.text = _ocrLines[index];
          _titleLineIndex = index;
        case _OcrField.author:
          _authorController.text = _ocrLines[index];
          _authorLineIndex = index;
        case _OcrField.isbn:
          // Prefer the extracted digits over the raw line — the line might
          // read "ISBN 978-955-20-1234-5" and the field wants just the
          // number.
          _isbnController.text = _isbnCandidates[index] ?? _ocrLines[index];
          _isbnLineIndex = index;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = context.read<BookRepository>();
    final now = DateTime.now();
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final isbn = _isbnController.text.trim();

    // Built directly rather than via copyWith: copyWith's `newValue ?? old`
    // pattern can't express "the user cleared this field", which matters
    // here since blanking out title/author/isbn is a valid edit.
    final book = Book(
      id: widget.existingBook?.id,
      title: title.isEmpty ? null : title,
      author: author.isEmpty ? null : author,
      isbn: isbn.isEmpty ? null : isbn,
      coverImagePath: _coverImagePath,
      coverUrl: _coverUrl,
      extraPhotoPaths: _extraPhotoPaths,
      ocrLines: _ocrLines,
      needsReview: false,
      createdAt: widget.existingBook?.createdAt ?? now,
      updatedAt: now,
    );

    if (widget.isEditing) {
      await repository.update(book);
    } else {
      await repository.insert(book);
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this book?'),
        content: const Text(
          'This removes it from your catalog. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<BookRepository>().delete(widget.existingBook!.id!);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit book' : 'Confirm details'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _retakeCover,
              child: _CoverPreview(imagePath: _coverImagePath, url: _coverUrl),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _retakeCover,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(
                _coverImagePath == null && _coverUrl == null
                    ? 'Add cover photo'
                    : 'Retake cover photo',
              ),
            ),
          ),
          if (_ocrLines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Detected text — tap a line to fill a field below',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _ocrLines.length; index++)
              _OcrLineCard(
                text: _ocrLines[index],
                isbnCandidate: _isbnCandidates[index],
                titleSelected: _titleLineIndex == index,
                authorSelected: _authorLineIndex == index,
                isbnSelected: _isbnLineIndex == index,
                onAssign: (field) => _assignLine(index, field),
              ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(labelText: 'Author'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _isbnController,
            decoration: const InputDecoration(labelText: 'ISBN'),
            keyboardType: TextInputType.text,
          ),
          if (_extraPhotoPaths.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Captured photos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _extraPhotoPaths.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_extraPhotoPaths[index]),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.imagePath, required this.url});

  final String? imagePath;
  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    Widget child;
    if (imagePath != null) {
      child = Image.file(
        File(imagePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (url != null) {
      child = Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _CoverPlaceholder(size: size),
      );
    } else {
      child = const _CoverPlaceholder(size: size);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: child);
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book, size: 48),
    );
  }
}

enum _OcrField { title, author, isbn }

/// One OCR-detected line, with a chip per field the user can file it under.
/// Exactly one line can be selected for a given field at a time — tapping a
/// chip on a different line just moves that field's selection.
class _OcrLineCard extends StatelessWidget {
  const _OcrLineCard({
    required this.text,
    this.isbnCandidate,
    required this.titleSelected,
    required this.authorSelected,
    required this.isbnSelected,
    required this.onAssign,
  });

  final String text;
  final String? isbnCandidate;
  final bool titleSelected;
  final bool authorSelected;
  final bool isbnSelected;
  final ValueChanged<_OcrField> onAssign;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            if (isbnCandidate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Looks like ISBN $isbnCandidate',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Title'),
                  selected: titleSelected,
                  onSelected: (_) => onAssign(_OcrField.title),
                ),
                ChoiceChip(
                  label: const Text('Author'),
                  selected: authorSelected,
                  onSelected: (_) => onAssign(_OcrField.author),
                ),
                ChoiceChip(
                  label: const Text('ISBN'),
                  selected: isbnSelected,
                  onSelected: (_) => onAssign(_OcrField.isbn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
