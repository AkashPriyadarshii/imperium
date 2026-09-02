import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../services/batch_parser.dart';
import '../theme/theme.dart';

/// Paste-in → review → confirm JSON envelope batch import.
/// Validates structured JSON only; never parses free prose.
class BatchScreen extends StatelessWidget {
  const BatchScreen({super.key, required this.db});

  final AppDb db;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'BATCH ENTRY',
          style: TextStyle(
            fontFamily: AppType.monument,
            fontSize: 20,
            letterSpacing: 2.4,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _BatchBody(db: db),
    );
  }
}

class _BatchBody extends StatefulWidget {
  const _BatchBody({required this.db});
  final AppDb db;
  @override
  State<_BatchBody> createState() => _BatchBodyState();
}

class _BatchBodyState extends State<_BatchBody> {
  final _controller = TextEditingController();
  final Map<String, String> _alias = {};
  List<BatchRow> _rows = const [];
  String? _preview;

  int get _validCount => _rows.where((r) => r.error == null).length;

  void _parse() {
    setState(() {
      _rows = parseEnvelope(_controller.text, alias: _alias);
    });
  }

  // Unknown category strings found on the last parse, prefer mapping controls.
  List<String> get _unknownCats =>
      _rows.map((r) => r.category).where((c) => !kCategories.contains(c)).toSet().toList();

  Future<void> _confirm() async {
    final valid = _rows.where((r) => r.error == null).toList();
    final now = DateTime.now();
    for (final r in valid) {
      await widget.db.addEntry(EntriesCompanion.insert(
        category: r.category,
        note: r.note,
        amount: Value<double?>(r.value),
        unit: Value(r.unit),
        loggedAt: r.date.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${valid.length} rows. All data stays on device.'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _validCount;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('1 · PASTE ENVELOPE', () => [
              TextField(
                controller: _controller,
                maxLines: 8,
                minLines: 4,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: AppType.ledger),
                decoration: InputDecoration(
                  hintText: '{"entries": [{"date":"2026-09-01","category":"gym","value":45,"note":"chest day"}]}',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  helperText:
                      'Paste a JSON envelope: an "entries" array with date / category / value / unit / note per row. Category must be one of the known categories.',
                  helperMaxLines: 3,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _parse,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('PARSE'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.bg,
                ),
              ),
            ]),
        const SizedBox(height: 24),
        _section('2 · ALIAS UNKNOWN CATEGORIES', _aliasControls),
        const SizedBox(height: 24),
        _section('3 · REVIEW ROWS', _rowList),
        const SizedBox(height: 24),
        _section('4 · TEMPLATES', _templateControls),
        const SizedBox(height: 24),
        const Divider(color: AppColors.hairline),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: valid == 0 ? null : _confirm,
          icon: const Icon(Icons.check, size: 18),
          label: Text('IMPORT $valid VALID ROWS'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brass,
            foregroundColor: AppColors.bg,
            disabledBackgroundColor: AppColors.surfaceRaised,
            disabledForegroundColor: AppColors.muted,
          ),
        ),
      ],
    );
  }

  // ---- alias controls ----
  List<Widget> _aliasControls() {
    final unknown = _unknownCats;
    if (unknown.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('No unknown categories.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        ),
      ];
    }
    return [
      for (final cat in unknown)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  cat,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: AppType.ledger),
                ),
                DropdownButton<String>(
                  value: _alias[cat] ?? 'keep',
                  isDense: true,
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: AppType.ledger),
                  items: [
                    DropdownMenuItem(value: 'keep', child: Text('Keep', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                    for (final k in kCategories)
                      DropdownMenuItem(value: k, child: Text(k)),
                  ],
                  onChanged: (v) => setState(() {
                    if (v == null) return;
                    if (v == 'keep') {
                      _alias.remove(cat);
                    } else {
                      _alias[cat] = v;
                    }
                    _rows = parseEnvelope(_controller.text, alias: _alias);
                  }),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  // ---- row review ----
  List<Widget> _rowList() {
    if (_rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Nothing parsed yet. Paste an envelope and hit PARSE.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ];
    }
    return [
      for (final r in _rows)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(color: r.error != null ? const Color(0xFFB3574A) : Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _rowTitle(r),
                softWrap: true,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: AppType.ledger, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                r.error ?? '${_fmtDate(r.date)}  ·  ${r.note.isEmpty ? 'no note' : r.note}',
                softWrap: true,
                style: TextStyle(
                  color: r.error != null ? const Color(0xFFB3574A) : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontFamily: AppType.ledger,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  String _rowTitle(BatchRow r) {
    final v = r.value != null ? ' · ${r.value}${r.unit ?? ''}' : '';
    return '${r.category} · $v';
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- templates ----
  List<Widget> _templateControls() => [
        for (final t in kBatchTemplates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _preview = kBatchPromptTemplate.replaceAll('{PASTE_ACTIVITY}', t.activityPrompt);
                    }),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Text(
                      t.name,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: AppType.ledger),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final prompt = kBatchPromptTemplate.replaceAll('{PASTE_ACTIVITY}', t.activityPrompt);
                    Clipboard.setData(ClipboardData(text: prompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Prompt copied. Paste it into your AI to get the envelope.'),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18, color: AppColors.brass),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  tooltip: 'Copy template prompt',
                ),
              ],
            ),
          ),
        if (_preview != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _preview!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: AppType.ledger, fontSize: 12),
            ),
          ),
      ];

  // ---- section header + body (marker pattern: returns List<Widget>) ----
  Widget _section(String title, List<Widget> Function() body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...body(),
        ],
      );
}
