import 'package:flutter_test/flutter_test.dart';
import 'package:bookie_bookie/models/reading_status.dart';

void main() {
  test('fromName round-trips every value by its own name', () {
    for (final status in ReadingStatus.values) {
      expect(ReadingStatus.fromName(status.name), status);
    }
  });

  test('fromName falls back to toRead for null or unknown input', () {
    expect(ReadingStatus.fromName(null), ReadingStatus.toRead);
    expect(ReadingStatus.fromName('not-a-real-status'), ReadingStatus.toRead);
  });

  test('labels are the four statuses from the product spec', () {
    expect(ReadingStatus.values.map((s) => s.label), [
      'Wishlist',
      'To Read',
      'Reading',
      'Read',
    ]);
  });
}
