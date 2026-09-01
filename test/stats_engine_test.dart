// `hide isNull, isNotNull` — drift's query builder exports these, which
// collide with matcher's; without the hide the suite won't compile.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imperium/db/database.dart';
import 'package:imperium/services/stats_engine.dart';
import 'package:imperium/services/data_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// In-memory DB so tests touch the real drift schema without touching disk.
AppDb newDb() => AppDb(executor: NativeDatabase.memory());

/// Point path_provider at a real temp dir so export/import round-trips work
/// without an Android/iOS platform channel.
class _FakePaths extends PathProviderPlatform {
  final Directory dir;
  _FakePaths(this.dir);
  @override
  Future<String> getApplicationDocumentsPath() async => dir.path;
}

Future<int> seed(AppDb db, String category, DateTime day, {double? amount, int? rating}) =>
    db.addEntry(EntriesCompanion.insert(
      category: category,
      note: 'test',
      amount: Value(amount),
      rating: Value(rating),
      loggedAt: day.millisecondsSinceEpoch,
      createdAt: day.millisecondsSinceEpoch,
    ));

DateTime d(int daysAgo) => DateTime.now().subtract(Duration(days: daysAgo));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Written files land in a system temp dir; left to OS cleanup.
  PathProviderPlatform.instance = _FakePaths(Directory.systemTemp);

  group('StatsEngine.overallStreak', () {
    test('counts consecutive logged days', () async {
      final db = newDb();
      addTearDown(db.close);
      await seed(db, 'food', d(0));
      await seed(db, 'water', d(1));
      await seed(db, 'sleep', d(2));
      final s = await StatsEngine(db).overallStreak(DateTime.now());
      expect(s.current, 3);
    });

    test('gaps break the streak', () async {
      final db = newDb();
      addTearDown(db.close);
      await seed(db, 'food', d(0));
      await seed(db, 'water', d(2)); // d(1) missing -> streak broken
      final s = await StatsEngine(db).overallStreak(DateTime.now());
      expect(s.current, 1);
    });
  });

  group('StatsEngine.correlation', () {
    test('returns null below min sample', () async {
      final db = newDb();
      addTearDown(db.close);
      await seed(db, 'study', d(0), amount: 2);
      await seed(db, 'fitness', d(0), amount: 1);
      final r = await StatsEngine(db)
          .correlation('study', 'fitness', minN: 5);
      expect(r, isNull);
    });

    test('perfectly correlated series => r = 1', () async {
      final db = newDb();
      addTearDown(db.close);
      // Same scaled values each paired day (though correlated via direct days).
      for (var i = 0; i < 6; i++) {
        await seed(db, 'study', d(i), amount: (i + 1) * 1.0);
        await seed(db, 'fitness', d(i), amount: (i + 1) * 2.0);
      }
      final r = await StatsEngine(db)
          .correlation('study', 'fitness', minN: 5, amountOrRating: true);
      expect(r, isNotNull);
      expect(r!.abs(), closeTo(1.0, 1e-6));
    });
  });

  group('DataIO round-trip', () {
    test('export produces importable JSON with matching counts', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src, 'food', d(0), amount: 3);
      await seed(src, 'sleep', d(1), amount: 8);

      // Write to a temp file representative of a user-exported backup.
      final path = await DataIO(src).exportJson();
      expect(path, contains('.json'));

      // Import into a fresh DB simulates restore on another install.
      final dst = newDb();
      addTearDown(dst.close);
      final res = await DataIO(dst).importJson(path);
      expect(res.inserted, 2);
      expect(res.skipped, 0);

      final restored = await dst.watchAllEntries().first;
      expect(restored, hasLength(2));
    });

    test('import skips duplicate ids', () async {
      final src = newDb();
      addTearDown(src.close);
      await seed(src, 'food', d(0), amount: 3);
      final path = await DataIO(src).exportJson();

      final dst = newDb();
      addTearDown(dst.close);
      await DataIO(dst).importJson(path);
      final res = await DataIO(dst).importJson(path); // same ids again
      expect(res.inserted, 0);
      expect(res.skipped, 1);
    });
  });

  test('defaultUnitFor maps domains', () {
    expect(defaultUnitFor('water'), 'ml');
    expect(defaultUnitFor('finance'), 'INR');
    expect(defaultUnitFor('sleep'), 'hours');
    expect(defaultUnitFor('freeform'), '');
  });
}
