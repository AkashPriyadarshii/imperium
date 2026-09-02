import 'dart:math' as math;

import '../db/database.dart';

/// Rule/math-based insight engine. No LLM, no fake intelligence.
///
/// Correlation probe guards against noise with a min-N before reporting.
class StatsEngine {
  final AppDb db;

  StatsEngine(this.db);

  static T _def<T>(T? v, T d) => v ?? d;

  /// Pearson correlation between two category amounts over the last [days]
  /// of paired (both-logged) days. Returns null below minN paired samples.
  Future<double?> correlation(
    String catA,
    String catB, {
    int days = 30,
    int minN = 5,
    bool amountOrRating = false,
  }) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final a = await db.entriesByCategory(catA, from.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    final b = await db.entriesByCategory(catB, from.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

    // Aggregate per-day value (mean of amount or rating if none).
    double val(Entry e) {
      if (amountOrRating) {
        if (e.amount != null) return e.amount!;
        if (e.rating != null) return e.rating!.toDouble();
      }
      return _def(e.rating?.toDouble(), 0);
    }

    final byDayA = <int, double>{};
    for (final e in a) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
      final day = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;
      byDayA[day] = byDayA.containsKey(day) ? (byDayA[day]! + val(e)) / 2 : val(e);
    }
    final byDayB = <int, double>{};
    for (final e in b) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
      final day = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;
      byDayB[day] = byDayB.containsKey(day) ? (byDayB[day]! + val(e)) / 2 : val(e);
    }

    final xs = <double>[];
    final ys = <double>[];
    byDayA.forEach((day, x) {
      final y = byDayB[day];
      if (y != null) {
        xs.add(x);
        ys.add(y);
      }
    });
    final n = xs.length;
    if (n < minN) return null;

    final mx = xs.reduce((s, v) => s + v) / n;
    final my = ys.reduce((s, v) => s + v) / n;
    double cov = 0, vx = 0, vy = 0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - mx, dy = ys[i] - my;
      cov += dx * dy;
      vx += dx * dx;
      vy += dy * dy;
    }
    if (vx == 0 || vy == 0) return null;
    return cov / (math.sqrt(vx) * math.sqrt(vy));
  }

  /// Plain-text readout of a correlation, or null if under minN.
  Future<String?> correlationReadout(String catA, String catB,
      {int days = 30, int minN = 5}) async {
    final r = await correlation(catA, catB, days: days, minN: minN);
    if (r == null) return null;
    final strength = r.abs() >= 0.7
        ? 'strong'
        : r.abs() >= 0.4
            ? 'moderate'
            : 'weak';
    final dir = r > 0 ? 'rises with' : 'falls with';
    return 'Over the last $days days of paired logs, ${catA.replaceAll('-', ' ')} '
        '${r > 0 ? 'tends to rise' : 'tends to drop'} as ${catB.replaceAll('-', ' ')} rises '
        '($dir, $strength correlation, r=${r.toStringAsFixed(2)}).';
  }

  /// Streak math for "any entry that day" across all categories.
  Future<({int current, int best, int toTie, bool atRisk})> overallStreak(DateTime now) async {
    final day = DateTime(now.year, now.month, now.day);
    var streak = 0;
    var cursor = day;
    // Walk back from today; missing = broken.
    for (var i = 0; i < 3650; i++) {
      final n = await db.countOnDate(cursor);
      if (n == 0 && i != 0) break; // today being empty doesn't break, but walk stops
      if (n > 0) streak++;
      if (i != 0 && n == 0) break;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final todayCount = await db.countOnDate(day);
    // Guard: if today empty, streak counts consecutive logged days ending yesterday.
    if (todayCount == 0) {
      streak = 0;
      cursor = day.subtract(const Duration(days: 1));
      while ((await db.countOnDate(cursor)) > 0) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }
    // best + toTie: scan all logged days.
    final dates = await db.allLoggedDates();
    final best = _longestRun(dates);
    final toTie = best > streak ? best - streak : 0;

    final atRisk = todayCount == 0 && now.hour >= 20 && streak > 0;

    final displayStreak = todayCount == 0 ? streak + 1 : (streak == 0 ? 1 : streak);

    return (current: displayStreak, best: best, toTie: toTie, atRisk: atRisk);
  }

  static int _longestRun(Set<int> dayStamps) {
    var best = 0, run = 0, prev = -999999;
    final sorted = dayStamps.toList()..sort();
    for (final d in sorted) {
      run = (d == prev + 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// 7/30-day mean + delta vs prior period + slope direction for a category amount.
  Future<({double mean7, double mean30, double deltaPct, String trend})>
      categoryTrend(String category) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day7 = today.subtract(const Duration(days: 7));
    final day30 = today.subtract(const Duration(days: 30));
    final day60 = today.subtract(const Duration(days: 60));

    final recent = await db.entriesBetween(day7.millisecondsSinceEpoch, today.millisecondsSinceEpoch).first;
    final last30 = await db.entriesBetween(day30.millisecondsSinceEpoch, today.millisecondsSinceEpoch).first;
    final pri30 = await db.entriesBetween(day60.millisecondsSinceEpoch, day30.millisecondsSinceEpoch).first;

    double sum(List<Entry> es) =>
        es.fold(0.0, (s, e) => s + _def(e.amount, e.rating?.toDouble() ?? 0));
    final avg7 = recent.isEmpty ? 0.0 : sum(recent) / recent.length;
    final m30 = last30.isEmpty ? 0.0 : sum(last30) / last30.length;
    final m30p = pri30.isEmpty ? 0.0 : sum(pri30) / pri30.length;

    final deltaPct = m30p == 0 ? 0.0 : ((m30 - m30p) / m30p) * 100;
    final trend = deltaPct.abs() < 5
        ? 'flat'
        : deltaPct > 0
            ? 'up'
            : 'down';
    return (mean7: avg7, mean30: m30, deltaPct: deltaPct, trend: trend);
  }
}
