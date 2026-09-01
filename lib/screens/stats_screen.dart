import 'package:flutter/material.dart';

import '../db/database.dart';
import '../services/stats_engine.dart';
import '../theme/theme.dart';

/// Stats ledger: auto-summary, by-category totals, correlation probe,
/// streak math, trend, search. Imperial dark-first.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.db});

  final AppDb db;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsEngine _stats;
  DateTime? _now;

  // Correlation probe.
  String _catA = kCategories[0];
  String _catB = kCategories.length > 1 ? kCategories[1] : kCategories[0];
  String? _readout;
  bool _probing = false;

  // Trend probe.
  String _trendCat = 'fitness';
  ({double mean7, double mean30, double deltaPct, String trend})? _trend;

  // Search.
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _stats = StatsEngine(widget.db);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Current-month window (ms).
  ({int from, int to}) get _monthWindow => _monthWindowOf(_now!);

  ({int from, int to}) _monthWindowOf(DateTime now) {
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    return (from: from.millisecondsSinceEpoch, to: to.millisecondsSinceEpoch);
  }

  static String _friendly(String cat) => cat.replaceAll('-', ' ');

  /// Monthly auto-summary sentence.
  String _summary(int count, String? topCat, double spend, int streak) {
    final buf = StringBuffer('This month: $count entries.');
    if (topCat != null) buf.write(' Most logged: ${_friendly(topCat)}.');
    if (spend > 0) buf.write(' Spent ₹${spend.toStringAsFixed(0)}.');
    buf.write(' Streak: $streak days.');
    return buf.toString();
  }

  Future<void> _runProbe() async {
    setState(() {
      _probing = true;
      _readout = null;
    });
    final r = await _stats.correlationReadout(_catA, _catB);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _readout = r;
    });
  }

  Future<void> _runTrend() async {
    final t = await _stats.categoryTrend(_trendCat);
    if (!mounted) return;
    setState(() => _trend = t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<Entry>>(
          stream: widget.db.watchAllEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <Entry>[];
            return FutureBuilder<
                ({int current, int best, int toTie})>(
              future: _stats.overallStreak(_now!),
              builder: (context, streakSnap) {
                final streak = streakSnap.data;
                final t = Theme.of(context);
                final w = _monthWindow;
                // This month's entries + finance spend + category tally.
                final monthEntries =
                    entries.where((e) =>
                        e.loggedAt >= w.from && e.loggedAt < w.to).toList();
                final spend = monthEntries
                    .where((e) => e.category == 'finance' && e.amount != null)
                    .fold<double>(0.0, (s, e) => s + (e.amount ?? 0));
                final byCat = <String, ({int n, double amt})>{};
                String? topCat;
                var topN = 0;
                for (final e in monthEntries) {
                  final cur = byCat[e.category] ?? (n: 0, amt: 0.0);
                  byCat[e.category] = (n: cur.n + 1, amt: cur.amt + (e.amount ?? 0));
                  if (cur.n + 1 > topN) {
                    topN = cur.n + 1;
                    topCat = e.category;
                  }
                }
                // Search filter (all-time).
                final q = _query.trim().toLowerCase();
                final searchHits = q.isEmpty
                    ? const <Entry>[]
                    : entries
                        .where((e) =>
                            e.note.toLowerCase().contains(q) ||
                            (e.emoji ?? '').toLowerCase().contains(q))
                        .take(50)
                        .toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text('STATS', style: t.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_summary(monthEntries.length, topCat, spend,
                        streak?.current ?? 0),
                        style: t.textTheme.bodyMedium),
                    const Divider(height: 32),

                    // --- Streak math ---
                    Text('STREAK', style: t.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    if (streak == null)
                      const LinearProgressIndicator()
                    else
                      Row(
                        children: [
                          _streakTile(t, 'CURRENT', streak.current),
                          _streakTile(t, 'BEST', streak.best),
                          _streakTile(t, 'TO TIE', streak.toTie),
                        ],
                      ),
                    const Divider(height: 32),

                    // --- Trends ---
                    Text('TREND', style: t.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _trendCat,
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      style: t.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: InputBorder.none,
                      ),
                      items: [for (final c in kCategories)
                        DropdownMenuItem(value: c, child: Text(_friendly(c)))],
                      onChanged: (v) {
                        if (v != null) setState(() => _trendCat = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: _runTrend,
                      icon: const Icon(Icons.trending_up, size: 18),
                      label: const Text('Compute trend'),
                    ),
                    const SizedBox(height: 8),
                    if (_trend != null)
                      _trendTile(t, _trend!),
                    const Divider(height: 32),

                    // --- Correlation probe ---
                    Text('CORRELATION PROBE', style: t.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _catA,
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      style: t.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Category A',
                        border: InputBorder.none,
                      ),
                      items: [for (final c in kCategories)
                        DropdownMenuItem(value: c, child: Text(_friendly(c)))],
                      onChanged: (v) =>
                          {if (v != null) setState(() => _catA = v)},
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _catB,
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      style: t.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Category B',
                        border: InputBorder.none,
                      ),
                      items: [for (final c in kCategories)
                        DropdownMenuItem(value: c, child: Text(_friendly(c)))],
                      onChanged: (v) =>
                          {if (v != null) setState(() => _catB = v)},
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: _probing ? null : _runProbe,
                        child: Text(_probing ? 'Probing…' : 'Run probe'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _readout ??
                          'Need at least 5 paired days of both categories.',
                      style: t.textTheme.bodySmall,
                    ),
                    const Divider(height: 32),

                    // --- By-category totals ---
                    Text('BY CATEGORY', style: t.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    for (final c in kCategories)
                      _categoryRow(t, c, byCat[c]),
                    const Divider(height: 32),

                    // --- Search ---
                    Text('SEARCH', style: t.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchCtrl,
                      style: t.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Find an entry…',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    for (final e in searchHits)
                      _searchRow(t, e),
                    if (q.isNotEmpty && searchHits.isEmpty)
                      Text('No matches.', style: t.textTheme.bodySmall),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _streakTile(ThemeData t, String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: t.textTheme.displaySmall?.copyWith(fontSize: 34)),
          Text(label, style: t.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _trendTile(
      ThemeData t, ({double mean7, double mean30, double deltaPct, String trend}) tr) {
    final icon = tr.trend == 'up'
        ? Icons.arrow_upward
        : tr.trend == 'down'
            ? Icons.arrow_downward
            : Icons.remove;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brass),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '7d ${tr.mean7.toStringAsFixed(1)} · 30d ${tr.mean30.toStringAsFixed(1)} · '
            '${tr.deltaPct >= 0 ? '+' : ''}${tr.deltaPct.toStringAsFixed(0)}% · ${tr.trend}',
            style: t.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _categoryRow(ThemeData t, String cat, ({int n, double amt})? data) {
    final d = data ?? (n: 0, amt: 0.0);
    final amt = d.amt == 0 ? '' : d.amt.toStringAsFixed(d.amt == d.amt.roundToDouble() ? 0 : 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_friendly(cat), style: t.textTheme.bodyMedium),
          Text('${d.n}${amt.isEmpty ? '' : ' · $amt'}',
              style: t.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _searchRow(ThemeData t, Entry e) {
    final day = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(date, style: t.textTheme.bodySmall),
          const SizedBox(width: 12),
          Text(e.emoji ?? '', style: t.textTheme.bodyMedium),
          const SizedBox(width: 4),
          Expanded(
            child: Text(e.note, style: t.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(_friendly(e.category), style: t.textTheme.labelSmall),
        ],
      ),
    );
  }
}
