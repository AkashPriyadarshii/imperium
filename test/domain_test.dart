import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imperium/db/database.dart';
import 'package:imperium/services/quotes.dart';

AppDb newTestDb() => AppDb(executor: NativeDatabase.memory());

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

  group('DailyNotes persistence', () {
    test('sets and gets daily reflection note for a specific date', () async {
      final db = newTestDb();
      addTearDown(db.close);

      const dateKey = '2026-09-01';
      expect(await db.noteForDate(dateKey), isNull);

      await db.setNote(dateKey, 'Conquered morning workout and deep work.');
      expect(await db.noteForDate(dateKey), 'Conquered morning workout and deep work.');

      // Update same date note
      await db.setNote(dateKey, 'Updated: Conquered morning workout.');
      expect(await db.noteForDate(dateKey), 'Updated: Conquered morning workout.');
    });
  });

  group('Habit Date Checks', () {
    test('habit checks are isolated by date', () async {
      final db = newTestDb();
      addTearDown(db.close);

      final habitId = await db.addHabit('Read Marcus Aurelius');
      const yesterday = '2026-08-31';
      const today = '2026-09-01';

      expect(await db.isHabitChecked(habitId, yesterday), isFalse);
      expect(await db.isHabitChecked(habitId, today), isFalse);

      await db.setHabitCheck(habitId, yesterday, true);
      expect(await db.isHabitChecked(habitId, yesterday), isTrue);
      expect(await db.isHabitChecked(habitId, today), isFalse);

      await db.setHabitCheck(habitId, yesterday, false);
      expect(await db.isHabitChecked(habitId, yesterday), isFalse);
    });
  });

  group('Retroactive & Backfill Entry Queries', () {
    test('entriesForDate retrieves entries accurately for selected day', () async {
      final db = newTestDb();
      addTearDown(db.close);

      final day1 = DateTime(2026, 9, 1, 10, 0);
      final day2 = DateTime(2026, 9, 2, 14, 30);

      await db.addEntry(EntriesCompanion.insert(
        category: 'fitness',
        note: 'Deadlifts',
        amount: const Value(100.0),
        unit: const Value('kg'),
        loggedAt: day1.millisecondsSinceEpoch,
        createdAt: day1.millisecondsSinceEpoch,
      ));

      await db.addEntry(EntriesCompanion.insert(
        category: 'water',
        note: 'Morning hydration',
        amount: const Value(500.0),
        unit: const Value('ml'),
        loggedAt: day2.millisecondsSinceEpoch,
        createdAt: day2.millisecondsSinceEpoch,
      ));

      final day1Entries = await db.entriesForDate(DateTime(2026, 9, 1));
      expect(day1Entries, hasLength(1));
      expect(day1Entries.first.category, 'fitness');
      expect(day1Entries.first.note, 'Deadlifts');

      final day2Entries = await db.entriesForDate(DateTime(2026, 9, 2));
      expect(day2Entries, hasLength(1));
      expect(day2Entries.first.category, 'water');
    });
  });
}

