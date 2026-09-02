import 'package:flutter/material.dart';

import '../db/database.dart';
import '../services/stats_engine.dart';
import '../theme/theme.dart';

const List<String> _months = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];

/// Stats ledger: auto-summary, by-category totals, correlation probe,
/// streak math, trend, and monthly navigation. Imperial dark-first.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.db});

  final AppDb db;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsEngine _stats;
  DateTime _currentViewDate = DateTime.now();

  // Correlation probe.
  String _catA = kCategories[0];
  String _catB = kCategories.length > 1 ? kCategories[1] : kCategories[0];
  String? _readout;
  bool _probing = false;

  // Trend probe.
  String _trendCat = 'fitness';
  ({double mean7, double mean30, double deltaPct, String trend})? _trend;

  @override
  void initState() {
    super.initState();
    _stats = StatsEngine(widget.db);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentViewDate.year == now.year && _currentViewDate.month == now.month;
  }

  void _prevMonth() {
    setState(() {
      _currentViewDate = DateTime(_currentViewDate.year, _currentViewDate.month - 1, 1);
    });
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      _currentViewDate = DateTime(_currentViewDate.year, _currentViewDate.month + 1, 1);
    });
  }

  // Month window (ms).
  ({int from, int to}) get _monthWindow {
    final from = DateTime(_currentViewDate.year, _currentViewDate.month, 1);
    final to = DateTime(_currentViewDate.year, _currentViewDate.month + 1, 1);
    return (from: from.millisecondsSinceEpoch, to: to.millisecondsSinceEpoch);
  }

  static String _friendly(String cat) => cat.replaceAll('-', ' ');

  /// Monthly auto-summary sentence.
  String _summary(int count, String? topCat, double spend, int streak) {
    final monthName = _months[_currentViewDate.month - 1];
    final buf = StringBuffer('${monthName[0].toUpperCase()}${monthName.substring(1)}: $count entries.');
    if (topCat != null) buf.write(' Most logged: ${_friendly(topCat)}.');
    if (spend > 0) buf.write(' Spent ₹${spend.toStringAsFixed(0)}.');
    if (_isCurrentMonth) buf.write(' Current streak: $streak days.');
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
    final t = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<Entry>>(
          stream: widget.db.watchAllEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <Entry>[];
            return FutureBuilder<({int current, int best, int toTie, bool atRisk})>(
              future: _stats.overallStreak(now),
              builder: (context, streakSnap) {
                final streak = streakSnap.data;
                final w = _monthWindow;
                // This month's entries + finance spend + category tally.
                final monthEntries = entries
                    .where((e) => e.loggedAt >= w.from && e.loggedAt < w.to)
                    .toList();
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

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Header with Month Selector
                    Row(
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.chevron_left, size: 22),
                          color: t.colorScheme.onSurfaceVariant,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        Text(
                          '${_months[_currentViewDate.month - 1].toUpperCase()} ${_currentViewDate.year}',
                          style: t.textTheme.headlineSmall?.copyWith(fontSize: 18),
                        ),
                        IconButton(
                          onPressed: !_isCurrentMonth ? _nextMonth : null,
                          icon: const Icon(Icons.chevron_right, size: 22),
                          color: !_isCurrentMonth
                              ? t.colorScheme.onSurfaceVariant
                              : t.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        const Spacer(),
                        if (!_isCurrentMonth)
                          GestureDetector(
                            onTap: () => setState(() => _currentViewDate = DateTime.now()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.brass.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CURRENT MONTH',
                                style: t.textTheme.labelSmall?.copyWith(color: AppColors.brass, fontSize: 8.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _summary(monthEntries.length, topCat, spend, streak?.current ?? 0),
                      style: t.textTheme.bodyMedium,
                    ),
                    const Divider(height: 28),

                    // --- Streak math ---
                    Text('STREAK MATH', style: t.textTheme.labelSmall?.copyWith(color: AppColors.brass)),
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
                    const Divider(height: 28),

                    // --- Trends ---
                    Text('CATEGORY TREND', style: t.textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _trendCat,
                          isExpanded: true,
                          dropdownColor: t.colorScheme.surfaceContainerHighest,
                          style: t.textTheme.bodyMedium,
                          items: [
                            for (final c in kCategories)
                              DropdownMenuItem(value: c, child: Text(_friendly(c).toUpperCase())),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _trendCat = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: t.colorScheme.primary,
                        foregroundColor: t.colorScheme.onPrimary,
                      ),
                      onPressed: _runTrend,
                      icon: const Icon(Icons.trending_up, size: 18),
                      label: const Text('Compute 7d vs 30d Trend'),
                    ),
                    if (_trend != null) ...[
                      const SizedBox(height: 8),
                      _trendTile(t, _trend!),
                    ],
                    const Divider(height: 28),

                    // --- Correlation probe ---
                    Text('CORRELATION PROBE (PEARSON R)', style: t.textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                    const SizedBox(height: 4),
                    Text(
                      'Discipline correlation over paired active days.',
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: t.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _catA,
                                isExpanded: true,
                                dropdownColor: t.colorScheme.surfaceContainerHighest,
                                style: t.textTheme.bodyMedium,
                                items: [
                                  for (final c in kCategories)
                                    DropdownMenuItem(value: c, child: Text(_friendly(c).toUpperCase())),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _catA = v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: t.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _catB,
                                isExpanded: true,
                                dropdownColor: t.colorScheme.surfaceContainerHighest,
                                style: t.textTheme.bodyMedium,
                                items: [
                                  for (final c in kCategories)
                                    DropdownMenuItem(value: c, child: Text(_friendly(c).toUpperCase())),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _catB = v);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.colorScheme.primary,
                          foregroundColor: t.colorScheme.onPrimary,
                        ),
                        onPressed: _probing ? null : _runProbe,
                        child: Text(_probing ? 'Calculating…' : 'Run Correlation Probe'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _readout ?? 'Requires min 5 paired days of logs between both categories (guard against noise).',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: _readout != null ? t.colorScheme.onSurface : t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Divider(height: 28),

                    // --- By-category totals ---
                    Text('CATEGORY TOTALS (MONTH)', style: t.textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                    const SizedBox(height: 8),
                    for (final c in kCategories)
                      _categoryRow(t, c, byCat[c]),
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
          Text('$value', style: t.textTheme.displaySmall?.copyWith(fontSize: 34, color: AppColors.brass)),
          const SizedBox(height: 2),
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
    final color = tr.trend == 'up' ? AppColors.brass : (tr.trend == 'down' ? t.colorScheme.error : t.colorScheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '7d ${tr.mean7.toStringAsFixed(1)} · 30d ${tr.mean30.toStringAsFixed(1)} · '
              '${tr.deltaPct >= 0 ? '+' : ''}${tr.deltaPct.toStringAsFixed(0)}% · ${tr.trend.toUpperCase()}',
              style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(ThemeData t, String cat, ({int n, double amt})? data) {
    final d = data ?? (n: 0, amt: 0.0);
    final unit = defaultUnitFor(cat);
    final amt = d.amt == 0
        ? ''
        : '${d.amt.toStringAsFixed(d.amt == d.amt.roundToDouble() ? 0 : 1)}${unit.isNotEmpty ? ' $unit' : ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _friendly(cat).toUpperCase(),
            style: t.textTheme.labelSmall?.copyWith(
              color: d.n > 0 ? t.colorScheme.onSurface : t.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          Text(
            '${d.n} logs${amt.isEmpty ? '' : '  ·  $amt'}',
            style: t.textTheme.bodySmall?.copyWith(
              color: d.n > 0 ? AppColors.brass : t.colorScheme.onSurfaceVariant,
              fontWeight: d.n > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

