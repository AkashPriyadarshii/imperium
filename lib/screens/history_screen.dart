import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/theme.dart';

/// All entries, newest first, grouped by day.
/// Category filter chips, search, day summaries, and full edit capabilities.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.db});
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'HISTORY',
          style: TextStyle(fontFamily: AppType.monument, letterSpacing: 2),
        ),
      ),
      body: _HistoryBody(db: db),
    );
  }
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody({required this.db});
  final AppDb db;
  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  final _search = TextEditingController();
  String _q = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            style: const TextStyle(fontFamily: AppType.ledger),
            decoration: InputDecoration(
              hintText: 'Search notes, emojis, categories…',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _search.clear();
                        _q = '';
                      }),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('ALL', _selectedCategory == null, () => setState(() => _selectedCategory = null)),
              const SizedBox(width: 6),
              for (final cat in kCategories) ...[
                _filterChip(
                  cat.toUpperCase().replaceAll('-', ' '),
                  _selectedCategory == cat,
                  () => setState(() => _selectedCategory = _selectedCategory == cat ? null : cat),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: StreamBuilder<List<Entry>>(
            stream: widget.db.watchAllEntries(),
            builder: (context, snap) {
              final all = snap.data ?? const <Entry>[];
              final filtered = all.where((e) {
                final matchCat = _selectedCategory == null || e.category == _selectedCategory;
                if (!matchCat) return false;
                if (_q.isEmpty) return true;
                return e.note.toLowerCase().contains(_q) ||
                    (e.emoji ?? '').toLowerCase().contains(_q) ||
                    e.category.toLowerCase().contains(_q);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No entries match your search.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return _grouped(filtered);
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brass
              : (isDark ? Theme.of(context).colorScheme.surface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? AppColors.brass : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? AppColors.bg : Theme.of(context).colorScheme.onSurface,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _grouped(List<Entry> entries) {
    final groups = <String, List<Entry>>{};
    final order = <String>[];
    for (final e in entries) {
      final day = DateTime.fromMillisecondsSinceEpoch(e.loggedAt).subtract(const Duration(hours: 4));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(e);
    }

    final list = <Widget>[];
    for (final key in order) {
      final dayList = groups[key]!;
      var spendTotal = 0.0;
      var sleepHours = 0.0;
      for (final e in dayList) {
        if (e.category == 'finance') spendTotal += e.amount ?? 0;
        if (e.category == 'sleep') sleepHours += e.amount ?? 0;
      }

      list.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Text(
                key.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brass,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                '${dayList.length} LOGS'
                '${sleepHours > 0 ? ' · ${sleepHours.toStringAsFixed(1)}H SLEEP' : ''}'
                '${spendTotal > 0 ? ' · ₹${spendTotal.toStringAsFixed(0)}' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 9.5,
                    ),
              ),
            ],
          ),
        ),
      );

      for (final e in dayList) {
        list.add(_EntryCard(entry: e, db: widget.db));
      }
    }
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: list);
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.db});
  final Entry entry;
  final AppDb db;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final logTime = DateTime.fromMillisecondsSinceEpoch(entry.loggedAt);
    final timeStr = '${logTime.hour.toString().padLeft(2, '0')}:${logTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.emoji != null && entry.emoji!.isNotEmpty) ...[
                        Text(entry.emoji!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          entry.note,
                          style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        entry.category.replaceAll('-', ' ').toUpperCase(),
                        style: t.textTheme.labelSmall?.copyWith(
                          color: AppColors.brass,
                          fontSize: 9.5,
                        ),
                      ),
                      if (entry.amount != null) ...[
                        Text(
                          '  ·  ${entry.amount}${entry.unit != null && entry.unit!.isNotEmpty ? ' ${entry.unit}' : ''}',
                          style: t.textTheme.labelSmall?.copyWith(fontSize: 9.5),
                        ),
                      ],
                      if (entry.rating != null) ...[
                        const SizedBox(width: 4),
                        Text(' ★' * entry.rating!, style: const TextStyle(color: AppColors.brass, fontSize: 10)),
                      ],
                      const Spacer(),
                      Text(
                        timeStr,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              color: t.colorScheme.onSurfaceVariant,
              onPressed: () => _editFull(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              color: t.colorScheme.onSurfaceVariant,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    title: const Text('Delete this entry?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await db.deleteEntry(entry.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editFull(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditEntrySheet(entry: entry, db: db),
    );
  }
}

class _EditEntrySheet extends StatefulWidget {
  const _EditEntrySheet({required this.entry, required this.db});
  final Entry entry;
  final AppDb db;

  @override
  State<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<_EditEntrySheet> {
  late final TextEditingController _noteCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _unitCtrl;
  late String _category;
  late String _emoji;
  late int? _rating;
  late DateTime _loggedAt;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.entry.note);
    _amountCtrl = TextEditingController(text: widget.entry.amount != null ? widget.entry.amount.toString() : '');
    _unitCtrl = TextEditingController(text: widget.entry.unit ?? '');
    _category = widget.entry.category;
    _emoji = widget.entry.emoji ?? '';
    _rating = widget.entry.rating;
    _loggedAt = DateTime.fromMillisecondsSinceEpoch(widget.entry.loggedAt);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;

    await widget.db.upsertEntry(EntriesCompanion(
      id: Value(widget.entry.id),
      category: Value(_category),
      note: Value(note),
      emoji: Value(_emoji.isEmpty ? null : _emoji),
      rating: Value(_rating),
      amount: Value(double.tryParse(_amountCtrl.text)),
      unit: Value(_unitCtrl.text.trim()),
      loggedAt: Value(_loggedAt.millisecondsSinceEpoch),
      createdAt: Value(widget.entry.createdAt),
    ));

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'EDIT ENTRY',
                  style: style.labelLarge?.copyWith(color: AppColors.brass, letterSpacing: 1.5),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in kCategories)
                  GestureDetector(
                    onTap: () => setState(() {
                      _category = cat;
                      if (_unitCtrl.text.isEmpty) {
                        _unitCtrl.text = defaultUnitFor(cat);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _category == cat ? AppColors.brass : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.toUpperCase().replaceAll('-', ' '),
                        style: style.labelSmall?.copyWith(
                          color: _category == cat ? AppColors.bg : cs.onSurface,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _noteCtrl,
              style: TextStyle(color: cs.onSurface, fontFamily: AppType.ledger),
              decoration: InputDecoration(
                labelText: 'Note',
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brass)),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: cs.onSurface, fontFamily: AppType.ledger),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brass)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    style: TextStyle(color: cs.onSurface, fontFamily: AppType.ledger),
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brass)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Rating Stars
            Row(
              children: [
                Text('Rating: ', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                for (var r = 1; r <= 5; r++)
                  GestureDetector(
                    onTap: () => setState(() => _rating = _rating == r ? null : r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        _rating != null && r <= _rating! ? Icons.star : Icons.star_border,
                        color: AppColors.brass,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Date & Time Picker button
            TextButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.schedule, size: 18, color: AppColors.brass),
              label: Text(
                '${_loggedAt.year}-${_loggedAt.month.toString().padLeft(2, '0')}-${_loggedAt.day.toString().padLeft(2, '0')}  ${_loggedAt.hour.toString().padLeft(2, '0')}:${_loggedAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: cs.onSurface),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.bg,
                ),
                child: const Text('SAVE CHANGES', style: TextStyle(fontFamily: AppType.monument)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

