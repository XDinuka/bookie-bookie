import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';

class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 44, height: 60, child: _buildCover()),
      ),
      title: Text(
        book.title ?? '(untitled)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          book.author,
          book.isbn,
        ].where((s) => s != null && s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: book.needsReview
          ? const Chip(
              label: Text('Needs review'),
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }

  Widget _buildCover() {
    final imagePath = book.coverImagePath;
    final url = book.coverUrl;
    if (imagePath != null) {
      return Image.file(File(imagePath), fit: BoxFit.cover);
    }
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _PlaceholderCover(),
      );
    }
    return const _PlaceholderCover();
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book, size: 20),
    );
  }
}
