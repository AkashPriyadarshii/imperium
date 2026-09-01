import 'package:flutter/material.dart';

import '../db/database.dart';
import '../services/quotes.dart';
import '../services/stats_engine.dart';
import '../theme/theme.dart';
import 'log_screen.dart';

const List<String> _months = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];
const List<String> _weekdays = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];

/// Dashboard-first home. Dark imperial field.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.db});

  final AppDb db;

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final style = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<List<Entry>>(
        stream: db.watchAllEntries(),
        builder: (context, snap) {
          final entries = snap.data ?? const <Entry>[];
          final today = entries.where((e) => _sameDay(DateTime.fromMillisecondsSinceEpoch(e.loggedAt), now)).toList();
          final todayCats = today.map((e) => e.category).toSet();

          final doneCount = kCategories.where(todayCats.contains).length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _header(context, now),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _quoteCard(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text('TODAY\'S DISCIPLINE', style: style.labelSmall?.copyWith(color: AppColors.brass)),
                      const Spacer(),
                      Text('$doneCount / ${kCategories.length}', style: style.labelSmall?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: kCategories.length,
                  itemBuilder: (context, i) => RepaintBoundary(
                    child: _LedgerRow(label: kCategories[i], entries: today.where((e) => e.category == kCategories[i]).toList()),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(height: 1, color: AppColors.goldDeep, margin: const EdgeInsets.fromLTRB(20, 20, 20, 4)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                sliver: SliverToBoxAdapter(
                  child: _scoreboard(context, entries),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: _habits(context),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _AddFab(db: db),
    );
  }

  Widget _header(BuildContext context, DateTime now) {
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_months[now.month - 1].toUpperCase()} ${now.day}', style: style.headlineSmall?.copyWith(color: AppColors.ivory)),
                  const SizedBox(height: 4),
                  Text(_weekdays[now.weekday - 1].toUpperCase(), style: style.labelSmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            FutureBuilder(
              future: StatsEngine(db).overallStreak(now),
              builder: (context, snap) {
                final streak = snap.data?.current ?? 0;
                return Text('DAY ${streak + 1}', style: style.displaySmall?.copyWith(fontSize: 24, color: AppColors.brass));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _quoteCard(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final quote = dailyQuote(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.brass, margin: const EdgeInsets.only(bottom: 16)),
        Text(
          quote.text,
          style: style.headlineMedium?.copyWith(fontSize: 24, color: AppColors.ivory, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(quote.author.toUpperCase(), style: style.labelSmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }

  Widget _scoreboard(BuildContext context, List<Entry> entries) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    double sum(String cat) {
      var total = 0.0;
      for (final e in entries) {
        if (e.category == cat &&
            e.loggedAt >= weekStart.millisecondsSinceEpoch) {
          total += e.amount ?? 0;
        }
      }
      return total;
    }

    var sleepCount = 0;
    var sleepTotal = 0.0;
    for (final e in entries) {
      if (e.category == 'sleep' && e.loggedAt >= weekStart.millisecondsSinceEpoch) {
        sleepCount++;
        sleepTotal += e.amount ?? 0;
      }
    }
    final sleepAvg = sleepCount == 0 ? 0.0 : sleepTotal / sleepCount;

    return Row(
      children: [
        _stat('SLEEP AVG', '${sleepAvg.toStringAsFixed(1)}h', context),
        _stat('SPEND 7D', '₹${sum('finance').toStringAsFixed(0)}', context),
        FutureBuilder(
          future: StatsEngine(db).overallStreak(now),
          builder: (context, snap) =>
              _stat('STREAK', '${snap.data?.current ?? 0}', context),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: style.displaySmall?.copyWith(fontSize: 20, color: AppColors.brass)),
          const SizedBox(height: 2),
          Text(label, style: style.labelSmall?.copyWith(color: AppColors.muted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _habits(BuildContext context) {
    return FutureBuilder<List<Habit>>(
      future: db.allHabits(),
      builder: (context, snap) {
        final habits = snap.data ?? const <Habit>[];
        if (habits.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final h in habits) _HabitChip(habit: h, date: _dateKey(DateTime.now()), db: db)],
        );
      },
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogScreen(db: db))),
      backgroundColor: AppColors.brass,
      foregroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.add),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.label, required this.entries});
  final String label;
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final has = entries.isNotEmpty;
    var amount = 0.0;
    for (final e in entries) {
      amount += e.amount ?? 0;
    }
    final metric = amount > 0 ? amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label.toUpperCase().replaceAll('-', ' '), style: style.labelSmall?.copyWith(color: AppColors.muted)),
          const SizedBox(width: 10),
          _StatusDot(has: has),
          const Spacer(),
          if (metric.isNotEmpty)
            Text(metric, style: style.labelSmall?.copyWith(color: AppColors.brass)),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.has});
  final bool has;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: has ? 1 : 0.15,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: has ? AppColors.brass : AppColors.muted,
        ),
      ),
    );
  }
}

class _HabitChip extends StatefulWidget {
  const _HabitChip({required this.habit, required this.date, required this.db});
  final Habit habit;
  final String date;
  final AppDb db;

  @override
  State<_HabitChip> createState() => _HabitChipState();
}

class _HabitChipState extends State<_HabitChip> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.db.isHabitChecked(widget.habit.id, widget.date);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        final checked = snap.data ?? false;
        return GestureDetector(
          onTap: () async {
            await widget.db.setHabitCheck(widget.habit.id, widget.date, !checked);
            setState(() => _future = widget.db.isHabitChecked(widget.habit.id, widget.date));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: checked ? AppColors.doneSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: checked ? AppColors.brass : AppColors.hairline),
            ),
            child: Text(
              widget.habit.name.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: checked ? AppColors.brass : AppColors.muted,
                  ),
            ),
          ),
        );
      },
    );
  }
}
