import 'package:flutter_test/flutter_test.dart';
import 'package:imperium/db/database.dart';
import 'package:imperium/services/quotes.dart';

void main() {
  group('defaultUnitFor', () {
    test('maps measured categories to their unit', () {
      expect(defaultUnitFor('water'), 'ml');
      expect(defaultUnitFor('finance'), 'INR');
      expect(defaultUnitFor('fitness'), 'hours');
      expect(defaultUnitFor('sleep'), 'hours');
    });

    test('returns empty for arbitrary categories', () {
      expect(defaultUnitFor('freeform'), '');
      expect(defaultUnitFor('mood'), '');
    });
  });

  group('dailyQuote', () {
    test('rotates deterministically by day', () {
      final d1 = DateTime(2026, 9, 1);
      final d2 = DateTime(2026, 9, 2);
      expect(dailyQuote(d1).text, dailyQuote(d1).text);
      // Two different days never both index out of range; corpus is non-empty.
      expect(dailyQuote(d1).author, isNotEmpty);
      expect(dailyQuote(d2).author, isNotEmpty);
    });

    test('mood tag changes the rotation', () {
      final d = DateTime(2026, 9, 1);
      expect(dailyQuote(d, moodTag: 'good').text,
          isNot(dailyQuote(d, moodTag: 'bad').text));
    });
  });
}
