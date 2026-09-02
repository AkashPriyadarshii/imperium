import 'package:flutter/material.dart';

import '../db/database.dart';
import '../services/quotes.dart';
import '../services/stats_engine.dart';
import '../theme/theme.dart';
import 'batch_screen.dart';
import 'log_screen.dart';

const List<String> _months = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];
const List<String> _weekdays = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];

/// Dashboard-first home. Dark imperial field with date navigation and reflection journal.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.db});

  final AppDb db;

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday {
    final now = DateTime.now();
    return _sameDay(_selectedDate, now);
  }

  void _prevDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    final now = DateTime.now();
    if (_sameDay(_selectedDate, now)) return;
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<Entry>>(
        stream: widget.db.watchAllEntries(),
        builder: (context, snap) {
          final entries = snap.data ?? const <Entry>[];
          final dayEntries = entries
              .where((e) => AppDb.entryBelongsToDay(e, _selectedDate))
              .toList();
          final dayCats = dayEntries.map((e) => e.category).toSet();
          final doneCount = kCategories.where(dayCats.contains).length;
          final allDone = doneCount == kCategories.length;

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _header(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _quoteCard(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          _isToday ? 'TODAY\'S DISCIPLINE' : 'DISCIPLINE LEDGER',
                          style: style.labelSmall?.copyWith(color: AppColors.brass),
                        ),
                        if (allDone) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.goldDeep.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.brass, width: 0.8),
                            ),
                            child: const Text(
                              'PERACTA',
                              style: TextStyle(
                                fontFamily: AppType.monument,
                                fontSize: 9,
                                letterSpacing: 1.5,
                                color: AppColors.brass,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '$doneCount / ${kCategories.length}',
                          style: style.labelSmall?.copyWith(
                            color: allDone ? AppColors.brass : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: allDone ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: kCategories.length,
                    itemBuilder: (context, i) {
                      final cat = kCategories[i];
                      final catEntries = dayEntries.where((e) => e.category == cat).toList();
                      return RepaintBoundary(
                        child: _LedgerRow(
                          label: cat,
                          entries: catEntries,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LogScreen(
                                db: widget.db,
                                initialCategory: cat,
                                initialDate: _selectedDate,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1,
                    color: AppColors.goldDeep,
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  sliver: SliverToBoxAdapter(
                    child: _scoreboard(context, entries),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: _habits(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverToBoxAdapter(
                    child: _DailyReflectionCard(
                      db: widget.db,
                      dateKey: DashboardScreen._dateKey(_selectedDate),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final now = DateTime.now();
    final canGoNext = !_sameDay(_selectedDate, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Date navigation controls
            IconButton(
              onPressed: _prevDay,
              icon: const Icon(Icons.chevron_left, size: 22),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              tooltip: 'Previous day',
            ),
            GestureDetector(
              onTap: _pickDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_months[_selectedDate.month - 1].toUpperCase()} ${_selectedDate.day}',
                    style: style.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            IconButton(
              onPressed: canGoNext ? _nextDay : null,
              icon: const Icon(Icons.chevron_right, size: 22),
              color: canGoNext
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              tooltip: 'Next day',
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BatchScreen(db: widget.db)),
              ),
              icon: const Icon(Icons.content_paste, size: 18),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Batch Import',
            ),
            const SizedBox(width: 6),
            FutureBuilder<({int current, int best, int toTie, bool atRisk})>(
              future: StatsEngine(widget.db).overallStreak(_selectedDate),
              builder: (context, snap) {
                final streak = snap.data?.current ?? 1;
                final display = streak > 0 ? streak : 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brass.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.brass.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(
                    'DAY $display',
                    style: style.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: (snap.data?.atRisk ?? false) ? Theme.of(context).colorScheme.error : AppColors.brass,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Row(
            children: [
              Text(
                _weekdays[_selectedDate.weekday - 1].toUpperCase(),
                style: style.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              if (!_isToday) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _selectedDate = DateTime.now()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brass.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'JUMP TO TODAY',
                      style: style.labelSmall?.copyWith(color: AppColors.brass, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }


  Widget _quoteCard(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final quote = dailyQuote(_selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.brass, margin: const EdgeInsets.only(bottom: 14)),
        Text(
          quote.text,
          style: style.headlineMedium?.copyWith(fontSize: 22, color: Theme.of(context).colorScheme.onSurface, height: 1.35),
        ),
        const SizedBox(height: 10),
        Text(quote.author.toUpperCase(), style: style.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _scoreboard(BuildContext context, List<Entry> entries) {
    final windowEnd = _selectedDate;
    final weekStart = DateTime(windowEnd.year, windowEnd.month, windowEnd.day).subtract(const Duration(days: 6));

    double sum(String cat) {
      var total = 0.0;
      for (final e in entries) {
        if (e.category == cat &&
            e.loggedAt >= weekStart.millisecondsSinceEpoch &&
            e.loggedAt <= windowEnd.millisecondsSinceEpoch + 86400000) {
          total += e.amount ?? 0;
        }
      }
      return total;
    }

    var sleepCount = 0;
    var sleepTotal = 0.0;
    for (final e in entries) {
      if (e.category == 'sleep' &&
          e.loggedAt >= weekStart.millisecondsSinceEpoch &&
          e.loggedAt <= windowEnd.millisecondsSinceEpoch + 86400000) {
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
          future: StatsEngine(widget.db).overallStreak(_selectedDate),
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
          Text(value, style: style.displaySmall?.copyWith(fontSize: 20, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 2),
          Text(label, style: style.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _habits(BuildContext context) {
    return FutureBuilder<List<Habit>>(
      future: widget.db.allHabits(),
      builder: (context, snap) {
        final habits = snap.data ?? const <Habit>[];
        if (habits.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in habits)
              _HabitChip(
                habit: h,
                date: DashboardScreen._dateKey(_selectedDate),
                db: widget.db,
              ),
          ],
        );
      },
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.entries,
    required this.onTap,
  });

  final String label;
  final List<Entry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final has = entries.isNotEmpty;
    var amount = 0.0;
    for (final e in entries) {
      amount += e.amount ?? 0;
    }
    final metric = amount > 0 ? amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1) : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Text(
              label.toUpperCase().replaceAll('-', ' '),
              style: style.labelSmall?.copyWith(
                color: has ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            _StatusDot(has: has),
            const Spacer(),
            if (metric.isNotEmpty)
              Text(metric, style: style.labelSmall?.copyWith(color: AppColors.brass)),
            const SizedBox(width: 4),
            Icon(
              has ? Icons.check : Icons.add,
              size: 14,
              color: has ? AppColors.brass : Theme.of(context).colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.has});
  final bool has;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: has ? AppColors.brass : Colors.transparent,
        border: Border.all(
          color: has ? AppColors.brass : Theme.of(context).colorScheme.outlineVariant,
          width: 1.2,
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
  void didUpdateWidget(covariant _HabitChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.habit.id != widget.habit.id) {
      _future = widget.db.isHabitChecked(widget.habit.id, widget.date);
    }
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
              color: checked
                  ? AppColors.goldDeep.withValues(alpha: 0.25)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checked ? AppColors.brass : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  checked ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: checked ? AppColors.brass : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.habit.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: checked ? AppColors.brass : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: checked ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Daily reflection / stoic journal editor connected to Drift DailyNotes.
class _DailyReflectionCard extends StatefulWidget {
  const _DailyReflectionCard({required this.db, required this.dateKey});
  final AppDb db;
  final String dateKey;

  @override
  State<_DailyReflectionCard> createState() => _DailyReflectionCardState();
}

class _DailyReflectionCardState extends State<_DailyReflectionCard> {
  final _ctrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DailyReflectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateKey != widget.dateKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final note = await widget.db.noteForDate(widget.dateKey);
    if (mounted) {
      setState(() {
        _ctrl.text = note ?? '';
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.db.setNote(widget.dateKey, _ctrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reflection saved')),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (!_loaded) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'DAILY REFLECTION',
                style: style.labelSmall?.copyWith(color: AppColors.brass),
              ),
              const Spacer(),
              if (_saving)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.brass),
                )
              else
                GestureDetector(
                  onTap: _save,
                  child: Text(
                    'SAVE',
                    style: style.labelSmall?.copyWith(
                      color: AppColors.brass,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            minLines: 2,
            style: style.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Record thoughts, lessons, or evening reflection…',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

