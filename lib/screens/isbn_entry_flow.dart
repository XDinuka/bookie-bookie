import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../services/isbn_lookup_service.dart';
import '../services/isbn_utils.dart';
import 'book_form_screen.dart';

/// Shared "scan or type an ISBN, then confirm" flow used by both the
/// barcode scan screen and the manual entry screen:
///
/// 1. If it's already cataloged, offer to open that entry instead of
///    creating a duplicate.
/// 2. If it's a Sri Lankan (955) ISBN, skip the online lookup entirely —
///    Open Library/Google Books have no coverage for it — and go straight
///    to the confirm screen with blank fields.
/// 3. Otherwise look it up (with a cancelable loading dialog) and prefill
///    whatever came back.
Future<void> handleIsbnEntered(BuildContext context, String rawIsbn) async {
  final isbn = IsbnUtils.normalize(rawIsbn);
  if (!IsbnUtils.isValid(isbn)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("That doesn't look like a valid ISBN.")),
    );
    return;
  }

  final repository = context.read<BookRepository>();
  final existing = await repository.getByIsbn(isbn);
  if (!context.mounted) return;

  if (existing != null) {
    final openExisting = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already in your catalog'),
        content: Text(existing.title ?? isbn),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open it'),
          ),
        ],
      ),
    );
    if (openExisting == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookFormScreen(existingBook: existing),
        ),
      );
    }
    return;
  }

  if (IsbnUtils.isSriLankan(isbn)) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookFormScreen(initialIsbn: isbn)),
    );
    return;
  }

  final service = IsbnLookupService();
  var cancelled = false;

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            const Expanded(child: Text('Looking up ISBN...')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              service.cancel();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  final metadata = await service.lookup(isbn);

  if (!context.mounted || cancelled) return;
  Navigator.of(context).pop(); // dismiss the loading dialog

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          BookFormScreen(initialIsbn: isbn, initialMetadata: metadata),
    ),
  );
}
