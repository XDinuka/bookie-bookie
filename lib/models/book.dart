import 'dart:convert';

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

  /// True while this entry hasn't been confirmed by the user yet: either
  /// background extraction hasn't finished, or it has and produced only a
  /// best guess that still needs a human look.
  final bool needsReview;

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
    this.needsReview = false,
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
    bool? needsReview,
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
      needsReview: needsReview ?? this.needsReview,
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
      'needs_review': needsReview ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, Object?> map) {
    final rawPhotos = map['extra_photo_paths'] as String?;
    final decodedPhotos = (rawPhotos == null || rawPhotos.isEmpty)
        ? const <String>[]
        : List<String>.from(jsonDecode(rawPhotos) as List);
    return Book(
      id: map['id'] as int?,
      isbn: map['isbn'] as String?,
      title: map['title'] as String?,
      author: map['author'] as String?,
      coverUrl: map['cover_url'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      extraPhotoPaths: decodedPhotos,
      needsReview: (map['needs_review'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
