import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/theme.dart';

/// All entries, newest first, grouped by day. Search filters across every
/// entry's note/emoji/category — the "see everything I wrote" view.
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
        title: const Text('HISTORY',
            style: TextStyle(fontFamily: AppType.monument, letterSpacing: 2)),
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            style: const TextStyle(fontFamily: AppType.ledger),
            decoration: InputDecoration(
              hintText: 'Search everything you wrote…',
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
        Expanded(
          child: StreamBuilder<List<Entry>>(
            stream: widget.db.watchAllEntries(),
            builder: (context, snap) {
              final all = snap.data ?? const <Entry>[];
              final filtered = _q.isEmpty
                  ? all
                  : all
                      .where((e) =>
                          e.note.toLowerCase().contains(_q) ||
                          (e.emoji ?? '').toLowerCase().contains(_q) ||
                          e.category.toLowerCase().contains(_q))
                      .toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Nothing here yet.',
                      style: TextStyle(color: AppColors.muted)),
                );
              }
              return _grouped(filtered);
            },
          ),
        ),
      ],
    );
  }

  Widget _grouped(List<Entry> entries) {
    // Group by local day, preserving newest-first order.
    final groups = <String, List<Entry>>{};
    final order = <String>[];
    for (final e in entries) {
      final day = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(e);
    }
    final list = <Widget>[];
    for (final key in order) {
      list.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(key.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.brass, letterSpacing: 2)),
      ));
      for (final e in groups[key]!) {
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
                  if (entry.emoji != null)
                    Text(entry.emoji!, style: const TextStyle(fontSize: 16)),
                  Text(entry.note, style: t.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.category.replaceAll('-', ' ').toUpperCase()}'
                    '${entry.amount != null ? '  ·  ${entry.amount}' : ''}',
                    style: t.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit',
              onPressed: () => _edit(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this entry?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
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

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: entry.note);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('EDIT'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    await db.upsertEntry(EntriesCompanion(
      id: Value(entry.id),
      category: Value(entry.category),
      note: Value(ctrl.text.trim()),
      loggedAt: Value(entry.loggedAt),
    ));
  }
}
