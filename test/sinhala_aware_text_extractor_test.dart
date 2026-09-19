import 'package:flutter_test/flutter_test.dart';
import 'package:bookie_bookie/services/sinhala_aware_text_extractor.dart';
import 'package:bookie_bookie/services/text_extraction_service.dart';

class _RecordingExtractor implements TextExtractor {
  _RecordingExtractor(this.lines);
  final List<String> lines;
  int callCount = 0;

  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    callCount++;
    return ExtractionResult(lines: lines);
  }
}

void main() {
  test('skips the Sinhala pass when nothing looks like an ISBN', () async {
    final primary = _RecordingExtractor([
      'The Great Gatsby',
      'F. Scott Fitzgerald',
    ]);
    final sinhala = _RecordingExtractor(['should not appear']);
    final extractor = SinhalaAwareTextExtractor(
      primary: primary,
      sinhala: sinhala,
    );

    final result = await extractor.extract(['photo.jpg']);

    expect(result.lines, ['The Great Gatsby', 'F. Scott Fitzgerald']);
    expect(sinhala.callCount, 0);
  });

  test('skips the Sinhala pass for a non-Sri-Lankan ISBN', () async {
    final primary = _RecordingExtractor(['ISBN 978-0-14-143951-8']);
    final sinhala = _RecordingExtractor(['should not appear']);
    final extractor = SinhalaAwareTextExtractor(
      primary: primary,
      sinhala: sinhala,
    );

    final result = await extractor.extract(['photo.jpg']);

    expect(result.lines, ['ISBN 978-0-14-143951-8']);
    expect(sinhala.callCount, 0);
  });

  test(
    'runs and merges the Sinhala pass for a Sri Lankan (955) ISBN',
    () async {
      final primary = _RecordingExtractor(['ISBN 978-955-20-1234-5']);
      final sinhala = _RecordingExtractor([
        'සිංහල මාතෘකාව',
        'ISBN 978-955-20-1234-5',
      ]);
      final extractor = SinhalaAwareTextExtractor(
        primary: primary,
        sinhala: sinhala,
      );

      final result = await extractor.extract(['photo.jpg']);

      expect(sinhala.callCount, 1);
      // Merged, with the duplicate line from the Sinhala pass removed.
      expect(result.lines, ['ISBN 978-955-20-1234-5', 'සිංහල මාතෘකාව']);
    },
  );
}
