import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/theme.dart';

const List<String> _quickEmoji = ['💧', '🏋️', '📖', '😌', '🍎', '💰', '😴', '✨'];
const List<int> _ratings = [1, 2, 3, 4, 5];

/// Capture-first. Light parchment form on a dark shell.
class LogScreen extends StatelessWidget {
  const LogScreen({
    super.key,
    required this.db,
    this.initialCategory,
    this.initialDate,
  });

  final AppDb db;
  final String? initialCategory;
  final DateTime? initialDate;

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text(
          'MARK IT',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.brass),
        ),
      ),
      body: _LogForm(
        db: db,
        initialCategory: initialCategory,
        initialDate: initialDate,
      ),
    );
  }
}

class _LogForm extends StatefulWidget {
  const _LogForm({
    required this.db,
    this.initialCategory,
    this.initialDate,
  });

  final AppDb db;
  final String? initialCategory;
  final DateTime? initialDate;

  @override
  State<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends State<_LogForm> {
  final _text = TextEditingController();
  final _amount = TextEditingController();
  late final TextEditingController _unitController;

  String? _category;
  String _emoji = '';
  int? _rating;
  String _unit = '';
  bool _backfill = false;
  late DateTime _loggedAt;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _loggedAt = widget.initialDate ?? DateTime.now();
    _unit = _category != null ? defaultUnitFor(_category!) : '';
    _unitController = TextEditingController(text: _unit);
    if (widget.initialDate != null) {
      final now = DateTime.now();
      final isToday = now.year == _loggedAt.year &&
          now.month == _loggedAt.month &&
          now.day == _loggedAt.day;
      if (!isToday) _backfill = true;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _selectCategory(String cat) {
    setState(() {
      _category = cat;
      final def = defaultUnitFor(cat);
      if (def.isNotEmpty) {
        _unit = def;
        _unitController.text = def;
      }
    });
  }

  void _applyQuickBackfill(DateTime time) {
    setState(() {
      _loggedAt = time;
      _backfill = true;
    });
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text the deed first')));
      return;
    }
    await widget.db.addEntry(EntriesCompanion.insert(
      category: _category ?? 'freeform',
      note: text,
      emoji: Value(_emoji.isEmpty ? null : _emoji),
      rating: Value(_rating),
      amount: Value(double.tryParse(_amount.text)),
      unit: Value(_unitController.text.trim()),
      loggedAt: _loggedAt.millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked done')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).colorScheme.surface : AppColors.lightSurface;
    final cardText = isDark ? Theme.of(context).colorScheme.onSurface : AppColors.lightInk;
    final cardMuted = isDark ? Theme.of(context).colorScheme.onSurfaceVariant : AppColors.lightMuted;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Recent entries with repeat/edit/delete.
        StreamBuilder<List<Entry>>(
          stream: widget.db.watchAllEntries(),
          builder: (context, snap) {
            final recent = (snap.data ?? const <Entry>[]).take(3).toList();
            if (recent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RECENT', style: style.labelSmall?.copyWith(color: AppColors.brass)),
                const SizedBox(height: 8),
                for (final e in recent)
                  RepaintBoundary(
                    child: _RecentRow(entry: e, db: widget.db, onRepeat: _repeat),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        // Quick backfill date presets
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('LOG TIME', style: style.labelSmall?.copyWith(color: AppColors.brass)),
                Text(
                  '${_loggedAt.year}-${LogScreen._dateKey(_loggedAt).substring(5)}  ${_loggedAt.hour.toString().padLeft(2, '0')}:${_loggedAt.minute.toString().padLeft(2, '0')} ${!_backfill ? '(TODAY)' : ''}',
                  style: style.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _PresetChip(
                  label: 'TODAY',
                  active: !_backfill,
                  onTap: () => setState(() {
                    _loggedAt = DateTime.now();
                    _backfill = false;
                  }),
                ),
                _PresetChip(
                  label: 'YESTERDAY',
                  active: _backfill &&
                      _loggedAt.day == now.subtract(const Duration(days: 1)).day &&
                      _loggedAt.month == now.subtract(const Duration(days: 1)).month,
                  onTap: () {
                    final y = now.subtract(const Duration(days: 1));
                    _applyQuickBackfill(DateTime(y.year, y.month, y.day, 20, 0));
                  },
                ),
                _PresetChip(
                  label: '-2 HOURS',
                  active: false,
                  onTap: () => _applyQuickBackfill(now.subtract(const Duration(hours: 2))),
                ),
                _PresetChip(
                  label: 'MORNING 08:00',
                  active: false,
                  onTap: () => _applyQuickBackfill(DateTime(_loggedAt.year, _loggedAt.month, _loggedAt.day, 8, 0)),
                ),
                _PresetChip(
                  label: 'CUSTOM…',
                  active: _backfill,
                  onTap: _pickTime,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),

        // Form card.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category chips.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in kCategories)
                    _CatChip(
                      label: cat,
                      selected: _category == cat,
                      onTap: () => _selectCategory(cat),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _text,
                style: TextStyle(color: cardText, fontFamily: AppType.ledger),
                decoration: InputDecoration(
                  hintText: 'Mark it done…',
                  hintStyle: TextStyle(color: cardMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldDeep)),
                ),
              ),
              const SizedBox(height: 16),

              // Emoji quick-pick.
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final em in _quickEmoji)
                    _EmojiChip(
                      emoji: em,
                      selected: _emoji == em,
                      onTap: () => setState(() => _emoji = _emoji == em ? '' : em),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Rating stars.
              Wrap(
                spacing: 2,
                children: [
                  for (final r in _ratings)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _rating = _rating == r ? null : r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        child: Icon(
                          _rating != null && r <= _rating! ? Icons.star : Icons.star_border,
                          color: AppColors.brass,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount + unit.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: cardText, fontFamily: AppType.ledger),
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        hintStyle: TextStyle(color: cardMuted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldDeep)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      style: TextStyle(color: cardText, fontFamily: AppType.ledger),
                      onChanged: (v) => _unit = v,
                      decoration: InputDecoration(
                        hintText: 'Unit',
                        hintStyle: TextStyle(color: cardMuted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldDeep)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('SAVE', style: style.labelLarge?.copyWith(color: AppColors.bg, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_loggedAt));
    if (time == null) return;
    setState(() {
      _loggedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _backfill = true;
    });
  }

  Future<void> _repeat(Entry e) async {
    await widget.db.addEntry(EntriesCompanion.insert(
      category: e.category,
      note: e.note,
      emoji: Value(e.emoji),
      rating: Value(e.rating),
      amount: Value(e.amount),
      unit: Value(e.unit ?? ''),
      loggedAt: _loggedAt.millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked done')));
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldDeep : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.goldDeep : AppColors.lightHairline),
        ),
        child: Text(
          label.replaceAll('-', ' ').toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.lightSurface : AppColors.lightBody,
              ),
        ),
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({required this.emoji, required this.selected, required this.onTap});
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldDeep : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.goldDeep : AppColors.lightHairline),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry, required this.db, required this.onRepeat});
  final Entry entry;
  final AppDb db;
  final void Function(Entry) onRepeat;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                Text(
                  '${entry.category.replaceAll('-', ' ').toUpperCase()}'
                  '${entry.amount != null ? '  ·  ${entry.amount}' : ''}',
                  style: style.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.replay, size: 18, color: Theme.of(context).colorScheme.primary),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Repeat',
            onPressed: () => onRepeat(entry),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Edit',
            onPressed: () => _edit(context),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final text = TextEditingController(text: entry.note);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        title: Text('EDIT', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(color: AppColors.brass)),
        content: TextField(
          controller: text,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration: const InputDecoration(hintText: 'Mark it done…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await db.upsertEntry(EntriesCompanion(
      id: Value(entry.id),
      category: Value(entry.category),
      note: Value(text.text.trim()),
      emoji: Value(entry.emoji),
      rating: Value(entry.rating),
      amount: Value(entry.amount),
      unit: Value(entry.unit),
      loggedAt: Value(entry.loggedAt),
    ));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        title: const Text('Delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await db.deleteEntry(entry.id);
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brass
              : (isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppColors.brass
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active
                    ? AppColors.bg
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
