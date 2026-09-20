/// Where a book stands in the user's reading life. Deliberately just these
/// four — no custom statuses, matching the app's "no collections/tags
/// beyond what's asked for" scope discipline.
enum ReadingStatus {
  wishlist,
  toRead,
  reading,
  read;

  String get label => switch (this) {
    ReadingStatus.wishlist => 'Wishlist',
    ReadingStatus.toRead => 'To Read',
    ReadingStatus.reading => 'Reading',
    ReadingStatus.read => 'Read',
  };

  static ReadingStatus fromName(String? name) {
    return ReadingStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ReadingStatus.toRead,
    );
  }
}
