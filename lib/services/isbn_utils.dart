/// ISBN normalization and Sri Lankan (group 955) detection.
class IsbnUtils {
  IsbnUtils._();

  /// Strips hyphens/spaces so barcode scans and typed input compare equal.
  static String normalize(String raw) {
    return raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  }

  /// A plausible ISBN-10 or ISBN-13: right length, digits only (ISBN-10
  /// allows a trailing check character of 'X'). This is a shape check, not
  /// a checksum validation — good enough to gate "is this worth looking up"
  /// without rejecting a barcode the camera read correctly.
  static bool isValid(String raw) {
    final isbn = normalize(raw);
    if (isbn.length == 10) {
      return RegExp(r'^\d{9}[\dX]$').hasMatch(isbn);
    }
    if (isbn.length == 13) {
      return RegExp(r'^\d{13}$').hasMatch(isbn);
    }
    return false;
  }

  /// Sri Lanka's ISBN registration group is 955, which per the README shows
  /// up at digits 4-6 of an ISBN-13, or the first 3 digits of an ISBN-10.
  /// Open Library and Google Books have essentially no coverage for it, so
  /// callers should skip the online lookup entirely for these.
  static bool isSriLankan(String raw) {
    final isbn = normalize(raw);
    if (isbn.length == 13) {
      return isbn.substring(3, 6) == '955';
    }
    if (isbn.length == 10) {
      return isbn.substring(0, 3) == '955';
    }
    return false;
  }

  /// Matches a run of digits (with optional internal hyphens/spaces, and an
  /// optional trailing X/x check digit) long enough to plausibly be an
  /// ISBN-10 or ISBN-13 — barcode text commonly comes out as "978-955-20-
  /// 1234-5" or "9 780141 439518", not a bare 10/13-digit string.
  static final RegExp _candidatePattern = RegExp(
    r'[0-9][0-9Xx\- ]{8,16}[0-9Xx]',
  );

  /// Pulls out substrings of [text] that are shaped like an ISBN, in order
  /// of appearance, normalized and deduplicated. An ISBN barcode is
  /// unambiguous enough in a scanned line to find with a regex — unlike
  /// title/author, there's no need to make the user hunt for it by hand.
  /// This is a shape check (same caveat as [isValid]), so a stray 10 or
  /// 13-digit number elsewhere on the cover can still slip through; the
  /// caller should treat these as suggestions, not a confirmed ISBN.
  static List<String> extractCandidates(String text) {
    final candidates = <String>[];
    for (final match in _candidatePattern.allMatches(text)) {
      final normalized = normalize(match.group(0)!);
      if (isValid(normalized) && !candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }
    return candidates;
  }
}
