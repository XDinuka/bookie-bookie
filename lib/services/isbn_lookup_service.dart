import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'isbn_utils.dart';

/// Best-guess metadata for a scanned/typed ISBN. Any field can be null —
/// the confirm screen just shows blanks for whatever wasn't found.
class BookMetadata {
  final String? title;
  final String? author;
  final String? coverUrl;

  const BookMetadata({this.title, this.author, this.coverUrl});

  bool get isEmpty => title == null && author == null && coverUrl == null;
}

/// Looks up an ISBN against Open Library, falling back to Google Books.
/// Both are free and keyless, per the README, and neither has meaningful
/// coverage for Sri Lankan (955) ISBNs, so those are skipped before any
/// network call is made.
///
/// One instance should back exactly one in-flight lookup: call [cancel] to
/// abort it (closing the underlying client makes any pending request fail
/// fast instead of leaving the caller waiting out the full timeout).
class IsbnLookupService {
  IsbnLookupService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  bool _cancelled = false;

  Future<BookMetadata?> lookup(String rawIsbn) async {
    if (IsbnUtils.isSriLankan(rawIsbn)) return null;

    final isbn = IsbnUtils.normalize(rawIsbn);
    final fromOpenLibrary = await _tryOpenLibrary(isbn);
    if (_cancelled) return null;
    if (fromOpenLibrary != null && !fromOpenLibrary.isEmpty) {
      return fromOpenLibrary;
    }
    return _tryGoogleBooks(isbn);
  }

  Future<BookMetadata?> _tryOpenLibrary(String isbn) async {
    final uri = Uri.parse(
      'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data',
    );
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entry = body['ISBN:$isbn'] as Map<String, dynamic>?;
      if (entry == null) return null;

      final authorsList = entry['authors'] as List?;
      final author = authorsList == null || authorsList.isEmpty
          ? null
          : authorsList
                .map((a) => (a as Map<String, dynamic>)['name'] as String?)
                .whereType<String>()
                .join(', ');

      final cover = entry['cover'] as Map<String, dynamic>?;
      final coverUrl =
          cover?['medium'] as String? ?? cover?['large'] as String?;

      return BookMetadata(
        title: entry['title'] as String?,
        author: (author == null || author.isEmpty) ? null : author,
        coverUrl: coverUrl,
      );
    } catch (_) {
      // Network failure, timeout, or unexpected shape: treat as "no data"
      // and fall through to the next source rather than failing the flow.
      return null;
    }
  }

  Future<BookMetadata?> _tryGoogleBooks(String isbn) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn',
    );
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'] as List?;
      if (items == null || items.isEmpty) return null;

      final volumeInfo =
          (items.first as Map<String, dynamic>)['volumeInfo']
              as Map<String, dynamic>?;
      if (volumeInfo == null) return null;

      final authorsList = volumeInfo['authors'] as List?;
      final author = authorsList?.whereType<String>().join(', ');

      final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
      final coverUrl =
          imageLinks?['thumbnail'] as String? ??
          imageLinks?['smallThumbnail'] as String?;

      return BookMetadata(
        title: volumeInfo['title'] as String?,
        author: (author == null || author.isEmpty) ? null : author,
        coverUrl: coverUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Aborts whatever request is in flight. Safe to call more than once.
  void cancel() {
    _cancelled = true;
    _client.close();
  }
}
