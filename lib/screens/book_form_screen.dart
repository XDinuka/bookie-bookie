import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/book.dart';
import '../models/popular_genres.dart';
import '../models/reading_status.dart';
import '../services/isbn_lookup_service.dart';
import '../services/isbn_utils.dart';
import '../services/photo_storage_service.dart';
import '../services/text_extraction_service.dart';

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

/// A single word (or ISBN barcode fragment) from a detected line, addressed
/// by its position, so a selection can span multiple lines in any
/// combination.
typedef _WordRef = (int line, int word);

class _BookFormScreenState extends State<BookFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _isbnController;

  String? _coverImagePath;
  String? _coverUrl;
  List<String> _extraPhotoPaths = const [];
  List<String> _ocrLines = const [];
  List<List<String>> _lineWords = const [];
  bool _saving = false;
  bool _extracting = false;
  late ReadingStatus _readingStatus;
  late List<String> _tags;

  // Tags used anywhere else in the catalog, offered as autocomplete
  // suggestions alongside the popular-genres list — loaded once, best
  // effort (an empty catalog or a failed fetch just means fewer
  // suggestions, not a broken form).
  Set<String> _knownTags = const {};

  // Line index -> the ISBN-shaped substring a regex found in that line, if
  // any. An ISBN barcode is unambiguous enough to detect automatically,
  // unlike title/author which genuinely need a human to pick.
  final Map<int, String> _isbnCandidates = {};

  // Words currently tapped, building up toward being assigned to a field.
  // Only membership matters, not tap order — the assigned text always reads
  // in original line/word order regardless of the order they were tapped.
  final Set<_WordRef> _selection = {};

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
    _readingStatus = existing?.readingStatus ?? ReadingStatus.toRead;
    _tags = List.of(existing?.tags ?? const []);
    _loadKnownTags();
    _applyDetectedLines(existing?.ocrLines ?? const []);
  }

  /// Rebuilds the word-picker state (lines, per-word tokens, ISBN
  /// candidates) from a fresh set of detected lines, and auto-fills the
  /// ISBN field if every candidate agrees on one number and the field is
  /// still blank. Used both for whatever the book already had on open and
  /// for the result of a fresh extraction after adding photos.
  void _applyDetectedLines(List<String> lines) {
    _ocrLines = lines;
    _lineWords = [for (final line in lines) line.split(RegExp(r'\s+'))];
    _isbnCandidates.clear();
    for (var i = 0; i < lines.length; i++) {
      final found = IsbnUtils.extractCandidates(lines[i]);
      if (found.isNotEmpty) _isbnCandidates[i] = found.first;
    }
    if (_isbnController.text.isEmpty && _isbnCandidates.isNotEmpty) {
      final distinct = _isbnCandidates.values.toSet();
      if (distinct.length == 1) {
        _isbnController.text = distinct.first;
      }
    }
    // Old selection indices may no longer correspond to the same words.
    _selection.clear();
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

  /// Takes one more photo for this book and re-runs text extraction over
  /// all of its photos so far, refreshing the word-picker with whatever
  /// turns up. Runs in the foreground with a small indicator rather than
  /// in the background — unlike the old multi-book batch capture flow,
  /// there's no "next book" to move on to here, so there's nothing to
  /// avoid blocking.
  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    final saved = await context.read<PhotoStorageService>().saveImage(
      picked.path,
    );
    if (!mounted) return;
    setState(() {
      _extraPhotoPaths = [..._extraPhotoPaths, saved];
      _extracting = true;
    });

    final result = await context.read<TextExtractor>().extract(
      _extraPhotoPaths,
    );
    if (!mounted) return;
    setState(() {
      _extracting = false;
      _applyDetectedLines(result.lines);
    });
  }

  Future<void> _loadKnownTags() async {
    final books = await context.read<BookRepository>().getAll();
    if (!mounted) return;
    setState(() {
      _knownTags = {for (final book in books) ...book.tags};
    });
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    final alreadyAdded = _tags.any(
      (existing) => existing.toLowerCase() == tag.toLowerCase(),
    );
    if (alreadyAdded) return;
    setState(() => _tags.add(tag));
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Iterable<String> _tagSuggestions(String query) {
    final notAlreadyAdded = <String>{...popularGenres, ..._knownTags}.where(
      (candidate) => !_tags.any(
        (existing) => existing.toLowerCase() == candidate.toLowerCase(),
      ),
    );
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return notAlreadyAdded.take(8);
    return notAlreadyAdded
        .where((candidate) => candidate.toLowerCase().contains(trimmed))
        .take(8);
  }

  void _toggleWord(int lineIndex, int wordIndex) {
    setState(() {
      final ref = (lineIndex, wordIndex);
      if (!_selection.remove(ref)) _selection.add(ref);
    });
  }

  void _toggleWholeLine(int lineIndex) {
    setState(() {
      final wordCount = _lineWords[lineIndex].length;
      final refs = [for (var w = 0; w < wordCount; w++) (lineIndex, w)];
      final allSelected = refs.every(_selection.contains);
      if (allSelected) {
        _selection.removeAll(refs);
      } else {
        _selection.addAll(refs);
      }
    });
  }

  /// The current selection's words, in original document order (not tap
  /// order), joined with single spaces.
  String get _selectionText {
    final sorted = _selection.toList()
      ..sort((a, b) {
        final lineCompare = a.$1.compareTo(b.$1);
        return lineCompare != 0 ? lineCompare : a.$2.compareTo(b.$2);
      });
    return sorted.map((ref) => _lineWords[ref.$1][ref.$2]).join(' ');
  }

  void _commitSelection(_OcrField field) {
    if (_selection.isEmpty) return;
    final joined = _selectionText;
    setState(() {
      switch (field) {
        case _OcrField.title:
          _titleController.text = joined;
        case _OcrField.author:
          _authorController.text = joined;
        case _OcrField.isbn:
          // Prefer the extracted digits over the raw selection — it might
          // read "ISBN 978-955-20-1234-5" and the field wants just the
          // number.
          final candidates = IsbnUtils.extractCandidates(joined);
          _isbnController.text = candidates.isNotEmpty
              ? candidates.first
              : joined;
      }
      _selection.clear();
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
      readingStatus: _readingStatus,
      tags: _tags,
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

  String get _appBarTitle {
    if (widget.isEditing) return 'Edit book';
    if (widget.initialIsbn == null && widget.initialMetadata == null) {
      return 'Add book details';
    }
    return 'Confirm details';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
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
          const SizedBox(height: 20),
          Text(
            'Photos for text detection',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final path in _extraPhotoPaths)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(path),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                _AddPhotoTile(onTap: _extracting ? null : _addPhoto),
              ],
            ),
          ),
          if (_extracting) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Detecting text...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (_ocrLines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Detected text — tap words to build a value, then assign it',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _ocrLines.length; index++)
              _OcrLineWords(
                words: _lineWords[index],
                isbnCandidate: _isbnCandidates[index],
                isWordSelected: (word) => _selection.contains((index, word)),
                onToggleWord: (word) => _toggleWord(index, word),
                onToggleWholeLine: () => _toggleWholeLine(index),
              ),
            const SizedBox(height: 8),
            _SelectionBar(
              previewText: _selection.isEmpty ? null : _selectionText,
              onAssign: _commitSelection,
              onClear: () => setState(_selection.clear),
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
          const SizedBox(height: 20),
          Text('Status', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ReadingStatus>(
            segments: [
              for (final status in ReadingStatus.values)
                ButtonSegment(value: status, label: Text(status.label)),
            ],
            selected: {_readingStatus},
            onSelectionChanged: (selected) =>
                setState(() => _readingStatus = selected.first),
          ),
          const SizedBox(height: 20),
          Text('Tags', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _TagEditor(
            tags: _tags,
            suggestionsFor: _tagSuggestions,
            onAdd: _addTag,
            onRemove: _removeTag,
          ),
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

/// One detected line, rendered as tappable word chips plus a "select whole
/// line" shortcut for the common case where the whole line is one field.
class _OcrLineWords extends StatelessWidget {
  const _OcrLineWords({
    required this.words,
    this.isbnCandidate,
    required this.isWordSelected,
    required this.onToggleWord,
    required this.onToggleWholeLine,
  });

  final List<String> words;
  final String? isbnCandidate;
  final bool Function(int wordIndex) isWordSelected;
  final ValueChanged<int> onToggleWord;
  final VoidCallback onToggleWholeLine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < words.length; i++)
                        ChoiceChip(
                          label: Text(words[i]),
                          selected: isWordSelected(i),
                          onSelected: (_) => onToggleWord(i),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Select whole line',
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleWholeLine,
                ),
              ],
            ),
            if (isbnCandidate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Looks like ISBN $isbnCandidate',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Existing tags as removable chips, plus a text field with autocomplete
/// suggestions (popular genres + tags already used elsewhere in the
/// catalog) for adding new ones. Typing something that matches no
/// suggestion and submitting still adds it — tags aren't limited to the
/// suggested list.
class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tags,
    required this.suggestionsFor,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> tags;
  final Iterable<String> Function(String query) suggestionsFor;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    // Autocomplete sets the field's text to whatever was selected but
    // never clears it; capturing the controller it hands fieldViewBuilder
    // lets onSelected clear it too, so the field is ready for the next tag
    // immediately instead of showing the just-added one.
    TextEditingController? fieldController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in tags)
                InputChip(label: Text(tag), onDeleted: () => onRemove(tag)),
            ],
          ),
        if (tags.isNotEmpty) const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (value) => suggestionsFor(value.text),
          onSelected: (selection) {
            onAdd(selection);
            fieldController?.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            fieldController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Add a tag',
                hintText: 'Genre or anything else',
              ),
              onSubmitted: (value) {
                onAdd(value);
                controller.clear();
                // Deliberately not calling the framework's onFieldSubmitted:
                // it tries to auto-select whichever option is currently
                // highlighted, which races with the controller.clear()
                // above and can throw once the options list it captured
                // goes stale. We already commit whatever was typed above.
              },
            );
          },
        ),
      ],
    );
  }
}

/// Shows the in-progress word selection and lets the user file it under a
/// field. Scrolls with the rest of the form rather than staying docked —
/// simpler to build and, for the short OCR outputs this screen deals with,
/// rarely far from view.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.previewText,
    required this.onAssign,
    required this.onClear,
  });

  final String? previewText;
  final ValueChanged<_OcrField> onAssign;
  final VoidCallback onClear;

  bool get _hasSelection => previewText != null;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hasSelection
                  ? 'Selected: $previewText'
                  : 'Tap words above, then assign them to a field',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: _hasSelection
                      ? () => onAssign(_OcrField.title)
                      : null,
                  child: const Text('→ Title'),
                ),
                FilledButton.tonal(
                  onPressed: _hasSelection
                      ? () => onAssign(_OcrField.author)
                      : null,
                  child: const Text('→ Author'),
                ),
                FilledButton.tonal(
                  onPressed: _hasSelection
                      ? () => onAssign(_OcrField.isbn)
                      : null,
                  child: const Text('→ ISBN'),
                ),
                if (_hasSelection)
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "take another photo" tile appended after existing photo thumbnails.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(Icons.add_a_photo_outlined, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
