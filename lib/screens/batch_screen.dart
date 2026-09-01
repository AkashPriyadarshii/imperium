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
        backgroundColor: AppColors.bg,
        title: const Text(
          'BATCH ENTRY',
          style: TextStyle(
            fontFamily: AppType.monument,
            fontSize: 20,
            letterSpacing: 2.4,
            color: AppColors.ivory,
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
        backgroundColor: AppColors.surfaceRaised,
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
                style: const TextStyle(color: AppColors.ivory, fontFamily: AppType.ledger),
                decoration: const InputDecoration(
                  hintText: '{"entries": [{"date":"2026-09-01","category":"gym","value":45,"note":"chest day"}]}',
                  hintStyle: TextStyle(color: AppColors.muted),
                  helperText:
                      'Paste a JSON envelope: an "entries" array with date / category / value / unit / note per row. Category must be one of the known categories.',
                  helperMaxLines: 3,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.hairline),
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
      return const [
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('No unknown categories.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ];
    }
    return [
      for (final cat in unknown)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(cat, style: const TextStyle(color: AppColors.ivory, fontFamily: AppType.ledger)),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _alias[cat] ?? 'keep',
                dropdownColor: AppColors.surfaceRaised,
                style: const TextStyle(color: AppColors.ivory, fontFamily: AppType.ledger),
                items: [
                  const DropdownMenuItem(value: 'keep', child: Text('Keep', style: TextStyle(color: AppColors.muted))),
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
            color: AppColors.surface,
            border: Border.all(color: r.error != null ? const Color(0xFFB3574A) : AppColors.hairline),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _rowTitle(r),
                style: const TextStyle(color: AppColors.ivory, fontFamily: AppType.ledger, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                r.error ?? '${_fmtDate(r.date)}  ·  ${r.note.isEmpty ? 'no note' : r.note}',
                style: TextStyle(
                  color: r.error != null ? const Color(0xFFB3574A) : AppColors.muted,
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
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                    child: Text(t.name, style: const TextStyle(color: AppColors.ivory, fontFamily: AppType.ledger)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final prompt = kBatchPromptTemplate.replaceAll('{PASTE_ACTIVITY}', t.activityPrompt);
                    Clipboard.setData(ClipboardData(text: prompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Prompt copied. Paste it into your AI to get the envelope.'),
                        backgroundColor: AppColors.surfaceRaised,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18, color: AppColors.brass),
                ),
              ],
            ),
          ),
        if (_preview != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _preview!,
              style: const TextStyle(color: AppColors.muted, fontFamily: AppType.ledger, fontSize: 12),
            ),
          ),
      ];

  // ---- section header + body (marker pattern: returns List<Widget>) ----
  Widget _section(String title, List<Widget> Function() body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 10.5, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...body(),
        ],
      );
}
