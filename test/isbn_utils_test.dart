import 'package:flutter_test/flutter_test.dart';
import 'package:bookie_bookie/services/isbn_utils.dart';

void main() {
  group('normalize', () {
    test('strips hyphens and spaces', () {
      expect(IsbnUtils.normalize('978-0-14-143951-8'), '9780141439518');
      expect(IsbnUtils.normalize('978 0 14 143951 8'), '9780141439518');
    });

    test('uppercases a trailing X check digit', () {
      expect(IsbnUtils.normalize('080442957x'), '080442957X');
    });
  });

  group('isValid', () {
    test('accepts a well-formed ISBN-13', () {
      expect(IsbnUtils.isValid('9780141439518'), isTrue);
    });

    test('accepts a well-formed ISBN-10 including an X check digit', () {
      expect(IsbnUtils.isValid('080442957X'), isTrue);
    });

    test('rejects the wrong length', () {
      expect(IsbnUtils.isValid('12345'), isFalse);
    });

    test('rejects non-digit characters other than a trailing X', () {
      expect(IsbnUtils.isValid('97801414395AB'), isFalse);
    });
  });

  group('isSriLankan', () {
    test('detects group 955 in an ISBN-13 at digits 4-6', () {
      expect(IsbnUtils.isSriLankan('978-955-20-1234-5'), isTrue);
    });

    test('detects group 955 as the first three digits of an ISBN-10', () {
      expect(IsbnUtils.isSriLankan('9552012345'), isTrue);
    });

    test('does not flag a non-Sri Lankan ISBN-13', () {
      expect(IsbnUtils.isSriLankan('9780141439518'), isFalse);
    });

    test('does not flag a non-Sri Lankan ISBN-10', () {
      expect(IsbnUtils.isSriLankan('080442957X'), isFalse);
    });
  });

  group('extractCandidates', () {
    test('finds a bare ISBN-13 embedded in surrounding text', () {
      expect(IsbnUtils.extractCandidates('ISBN 9780141439518'), [
        '9780141439518',
      ]);
    });

    test('finds a hyphenated ISBN-13', () {
      expect(IsbnUtils.extractCandidates('ISBN 978-0-14-143951-8'), [
        '9780141439518',
      ]);
    });

    test('finds a barcode-style spaced ISBN-13', () {
      expect(IsbnUtils.extractCandidates('9 780141 439518'), ['9780141439518']);
    });

    test('finds a hyphenated ISBN-10 with an X check digit', () {
      expect(IsbnUtils.extractCandidates('ISBN 0-8044-2957-X'), ['080442957X']);
    });

    test('returns nothing for a line with no ISBN-shaped text', () {
      expect(IsbnUtils.extractCandidates('The Great Gatsby'), isEmpty);
    });

    test('dedupes repeated occurrences within the same line', () {
      expect(IsbnUtils.extractCandidates('9780141439518 / 9780141439518'), [
        '9780141439518',
      ]);
    });
  });
}
