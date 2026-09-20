import 'dart:convert';

import 'reading_status.dart';

/// A single catalog entry.
///
/// Cover art can come from either an online lookup (`coverUrl`) or a photo
/// the user took of the physical book (`coverImagePath`) — the latter takes
/// priority when both are present, since it's the one the user actually
/// confirmed matches their copy.
class Book {
  final int? id;
  final String? isbn;
  final String? title;
  final String? author;
  final String? coverUrl;
  final String? coverImagePath;

  /// Extra photos captured for background extraction (cover/spine/title
  /// page/etc.) — kept even after extraction so the user can re-check them.
  final List<String> extraPhotoPaths;

  /// Raw text lines OCR found across those photos, in detection order with
  /// exact duplicates removed. The review screen shows these so the user
  /// can pick which line is the title/author/ISBN themselves, rather than
  /// trusting an automated guess.
  final List<String> ocrLines;

  /// True while this entry hasn't been confirmed by the user yet: either
  /// background extraction hasn't finished, or it has and produced only a
  /// best guess that still needs a human look.
  final bool needsReview;

  /// Where this book stands in the user's reading life: wishlist, to-read,
  /// reading, or read.
  final ReadingStatus readingStatus;

  /// Freeform labels — genres or anything else the user wants. Not limited
  /// to a fixed list.
  final List<String> tags;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Book({
    this.id,
    this.isbn,
    this.title,
    this.author,
    this.coverUrl,
    this.coverImagePath,
    this.extraPhotoPaths = const [],
    this.ocrLines = const [],
    this.needsReview = false,
    this.readingStatus = ReadingStatus.toRead,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String? get displayCoverPath => coverImagePath ?? coverUrl;

  Book copyWith({
    int? id,
    String? isbn,
    String? title,
    String? author,
    String? coverUrl,
    String? coverImagePath,
    List<String>? extraPhotoPaths,
    List<String>? ocrLines,
    bool? needsReview,
    ReadingStatus? readingStatus,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      extraPhotoPaths: extraPhotoPaths ?? this.extraPhotoPaths,
      ocrLines: ocrLines ?? this.ocrLines,
      needsReview: needsReview ?? this.needsReview,
      readingStatus: readingStatus ?? this.readingStatus,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'cover_url': coverUrl,
      'cover_image_path': coverImagePath,
      'extra_photo_paths': jsonEncode(extraPhotoPaths),
      'ocr_lines': jsonEncode(ocrLines),
      'needs_review': needsReview ? 1 : 0,
      'reading_status': readingStatus.name,
      'tags': jsonEncode(tags),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  factory Book.fromMap(Map<String, Object?> map) {
    return Book(
      id: map['id'] as int?,
      isbn: map['isbn'] as String?,
      title: map['title'] as String?,
      author: map['author'] as String?,
      coverUrl: map['cover_url'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      extraPhotoPaths: _decodeStringList(map['extra_photo_paths']),
      ocrLines: _decodeStringList(map['ocr_lines']),
      needsReview: (map['needs_review'] as int) == 1,
      readingStatus: ReadingStatus.fromName(map['reading_status'] as String?),
      tags: _decodeStringList(map['tags']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
