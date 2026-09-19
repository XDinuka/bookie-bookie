import 'package:flutter_test/flutter_test.dart';
import 'package:bookie_bookie/services/combined_text_extractor.dart';
import 'package:bookie_bookie/services/text_extraction_service.dart';

class _FakeExtractor implements TextExtractor {
  _FakeExtractor(this.lines);
  final List<String> lines;

  @override
  Future<ExtractionResult> extract(List<String> photoPaths) async {
    return ExtractionResult(lines: lines);
  }
}

void main() {
  test('merges lines from every extractor in order', () async {
    final combined = CombinedTextExtractor([
      _FakeExtractor(['Latin line one', 'Latin line two']),
      _FakeExtractor(['සිංහල පේළිය', 'Latin line two']),
    ]);

    final result = await combined.extract(['photo1.jpg']);

    expect(result.lines, ['Latin line one', 'Latin line two', 'සිංහල පේළිය']);
  });

  test('returns no lines when every extractor finds nothing', () async {
    final combined = CombinedTextExtractor([
      _FakeExtractor(const []),
      _FakeExtractor(const []),
    ]);

    final result = await combined.extract(['photo1.jpg']);

    expect(result.lines, isEmpty);
    expect(result.isEmpty, isTrue);
  });
}
