import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Categories. `freeform` is the catch-all: nothing is refused.
const List<String> kCategories = [
  'food', 'water', 'health', 'study', 'fitness', 'sleep',
  'mood', 'skin-hair', 'finance', 'freeform',
];

/// Per-category default amount units so stats sum correctly by domain.
String defaultUnitFor(String category) {
  switch (category) {
    case 'water':
      return 'ml';
    case 'finance':
      return 'INR';
    case 'study':
    case 'fitness':
    case 'sleep':
      return 'hours';
    case 'food':
      return 'portion';
    default:
      return '';
  }
}

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  // `note` (not `text`) — `text` collides with drift's Table.text() column builder.
  TextColumn get note => text()();
  TextColumn get emoji => text().nullable()();
  IntColumn get rating => integer().nullable()();
  RealColumn get amount => real().nullable()();
  TextColumn get unit => text().nullable()();
  /// User-meaningful timestamp (backfill: any past time). epoch ms.
  IntColumn get loggedAt => integer()();
  IntColumn get createdAt => integer()();
}

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class HabitChecks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  /// YYYY-MM-DD, local rollover handled by caller.
  TextColumn get date => text()();
  @override
  List<Set<Column>> get uniqueKeys => [ {habitId, date} ];
}

class DailyNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();
  TextColumn get note => text()();
}

@DriftDatabase(tables: [Entries, Habits, HabitChecks, DailyNotes])
class AppDb extends _$AppDb {
  AppDb({QueryExecutor? executor})
      : super(executor ?? driftDatabase(name: 'imperium'));

  @override
  int get schemaVersion => 1;

  // ---- Entries ----
  Stream<List<Entry>> watchAllEntries() => (select(entries)..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])).watch();

  Future<Entry?> entryById(int id) =>
      (select(entries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> addEntry(EntriesCompanion e) => into(entries).insert(e);

  /// Logs or updates an entry.
  Future<void> upsertEntry(EntriesCompanion e) => into(entries).insertOnConflictUpdate(e);

  Future<void> deleteEntry(int id) => (delete(entries)..where((t) => t.id.equals(id))).go();

  /// Whether an entry logically belongs to a target calendar day.
  /// For standard categories: matched by calendar day (00:00 - 23:59 local time).
  /// For sleep: night sleep rolling window (sleep logged before 04:00 belongs to prior day).
  static bool entryBelongsToDay(Entry e, DateTime targetDate) {
    final entryDt = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
    if (e.category == 'sleep') {
      final sleepLogical = entryDt.subtract(const Duration(hours: 4));
      return sleepLogical.year == targetDate.year &&
          sleepLogical.month == targetDate.month &&
          sleepLogical.day == targetDate.day;
    }
    return entryDt.year == targetDate.year &&
        entryDt.month == targetDate.month &&
        entryDt.day == targetDate.day;
  }

  /// Logical date key for an entry (YYYY-MM-DD).
  static String entryLogicalDateKey(Entry e) {
    final entryDt = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
    final dt = e.category == 'sleep' ? entryDt.subtract(const Duration(hours: 4)) : entryDt;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  /// Entries for one local date; sleep rolls at 04:00, others at 00:00.
  Future<List<Entry>> entriesForDate(DateTime date, {bool sleep = false}) async {
    final day = DateTime(date.year, date.month, date.day);
    final dayStart = day.millisecondsSinceEpoch;
    final sleepLateEnd = day.add(const Duration(days: 1, hours: 4)).millisecondsSinceEpoch;

    final q = select(entries)
      ..where((t) => t.loggedAt.isBiggerOrEqualValue(dayStart)
          & t.loggedAt.isSmallerThanValue(sleepLateEnd))
      ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]);
    final list = await q.get();
    return list.where((e) => entryBelongsToDay(e, date)).toList();
  }

  Stream<List<Entry>> entriesBetween(int from, int to) => (select(entries)
        ..where((t) => t.loggedAt.isBiggerOrEqualValue(from) & t.loggedAt.isSmallerThanValue(to))
        ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
      .watch();

  Future<int> countOnDate(DateTime date) async =>
      (await entriesForDate(date)).length;

  /// Local-day stamps (days since local epoch) that have >=1 logged entry.
  Future<Set<int>> allLoggedDates() async {
    final all = await select(entries).get();
    return all.map((e) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
      final logical = e.category == 'sleep' ? dt.subtract(const Duration(hours: 4)) : dt;
      return DateTime(logical.year, logical.month, logical.day).millisecondsSinceEpoch ~/ 86400000;
    }).toSet();
  }

  /// All entries for a category between from/to (ms) — for stats.
  Future<List<Entry>> entriesByCategory(String category, int from, int to) =>
      (select(entries)
            ..where((t) => t.category.equals(category)
                & t.loggedAt.isBiggerOrEqualValue(from)
                & t.loggedAt.isSmallerThanValue(to)))
          .get();

  // ---- Habits ----
  Future<int> addHabit(String name) => into(habits).insert(HabitsCompanion.insert(name: name));

  Future<List<Habit>> allHabits() => select(habits).get();

  Future<void> removeHabit(int id) => (delete(habits)..where((t) => t.id.equals(id))).go();

  Future<bool> isHabitChecked(int habitId, String date) async {
    final h = await (select(habitChecks)
          ..where((t) => t.habitId.equals(habitId) & t.date.equals(date)))
        .getSingleOrNull();
    return h != null;
  }

  Future<void> setHabitCheck(int habitId, String date, bool checked) async {
    if (checked) {
      await into(habitChecks).insert(HabitChecksCompanion.insert(habitId: habitId, date: date),
          mode: InsertMode.insertOrIgnore);
    } else {
      await (delete(habitChecks)
            ..where((t) => t.habitId.equals(habitId) & t.date.equals(date)))
          .go();
    }
  }

  // ---- Daily notes ----
  Future<String?> noteForDate(String date) async {
    final n = await (select(dailyNotes)..where((t) => t.date.equals(date))).getSingleOrNull();
    return n?.note;
  }

  Future<void> setNote(String date, String note) async {
    final existing = await (select(dailyNotes)..where((t) => t.date.equals(date))).getSingleOrNull();
    if (existing != null) {
      await (update(dailyNotes)..where((t) => t.id.equals(existing.id)))
          .write(DailyNotesCompanion(note: Value(note)));
    } else {
      await into(dailyNotes).insert(DailyNotesCompanion.insert(date: date, note: note));
    }
  }
}

