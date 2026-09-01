import 'package:flutter_test/flutter_test.dart';
import 'package:imperium/services/batch_parser.dart';

void main() {
  group('parseEnvelope', () {
    test('parses a valid envelope', () {
      final rows = parseEnvelope(
        '{"entries":[{"date":"2026-09-01","category":"fitness","value":45,"note":"chest day"}]}',
      );
      expect(rows, hasLength(1));
      expect(rows.first.error, isNull);
      expect(rows.first.category, 'fitness');
      expect(rows.first.value, 45);
      expect(rows.first.note, 'chest day');
    });

    test('rejects non-JSON', () {
      final rows = parseEnvelope('not json at all');
      expect(rows, hasLength(1));
      expect(rows.first.error, isNotNull);
    });

    test('rejects missing entries array', () {
      final rows = parseEnvelope('{"foo": 1}');
      expect(rows.first.error, isNotNull);
    });

    test('marks unknown category (mappable)', () {
      final rows = parseEnvelope(
        '{"entries":[{"date":"2026-09-01","category":"swimming"}]}',
      );
      expect(rows.first.error, contains('Unknown category'));
    });

    test('alias maps an unknown category to a known one', () {
      final rows = parseEnvelope(
        '{"entries":[{"date":"2026-09-01","category":"swimming"}]}',
        alias: {'swimming': 'fitness'},
      );
      expect(rows.first.error, isNull);
      expect(rows.first.category, 'fitness');
    });

    test('rejects a bad date', () {
      final rows = parseEnvelope(
        '{"entries":[{"date":"2026-99-99","category":"food"}]}',
      );
      expect(rows.first.error, contains('Bad date'));
    });

    test('defaults missing fields to freeform/now', () {
      final rows = parseEnvelope('{"entries":[{}]}');
      expect(rows.first.category, 'freeform');
      expect(rows.first.date, isA<DateTime>());
    });
  });

  test('prompt template contains the envelope shape and category list', () {
    expect(kBatchPromptTemplate, contains('"entries"'));
    expect(kBatchPromptTemplate, contains('food'));
    expect(kBatchPromptTemplate, contains('{PASTE_ACTIVITY}'));
  });

  test('bundled templates substitute into the prompt', () {
    final prompt = kBatchPromptTemplate.replaceAll(
        '{PASTE_ACTIVITY}', kBatchTemplates.first.activityPrompt);
    expect(prompt, isNot(contains('{PASTE_ACTIVITY}')));
    expect(prompt, contains('workout'));
  });
}
