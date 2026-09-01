import 'dart:convert';

import '../db/database.dart';

/// JSON envelope batch import. Validates schema, maps strings to categories,
/// returns a review list. NOT prose parsing — the pasted thing must already
/// be structured (an LLM's output). Labeled "batch entry", never "persona".
///
/// Accepted envelope:
/// ```json
/// {"entries": [{"date":"2026-09-01","category":"gym","value":45,"note":"chest day"}, ...]}
/// ```

class BatchRow {
  final String category;
  final DateTime date;
  final double? value;
  final String? unit;
  final String note;
  final String? error; // non-null => row rejected
  BatchRow(this.category, this.date, this.value, this.unit, this.note, this.error);
}

class BatchParseResult {
  final List<BatchRow> rows;
  BatchParseResult(this.rows);
}

/// Merges unknown category keys into known ones; marks invalid rows.
List<BatchRow> parseEnvelope(String raw, {Map<String, String>? alias}) {
  final result = <BatchRow>[];
  Object? data;
  try {
    data = jsonDecode(raw);
  } catch (_) {
    return [BatchRow('freeform', DateTime.now(), null, null, '', 'Not valid JSON')];
  }
  if (data is! Map<String, dynamic>) {
    return [BatchRow('freeform', DateTime.now(), null, null, '', 'Envelope must be a JSON object')];
  }
  final entries = data['entries'] as List?;
  if (entries == null) {
    return [BatchRow('freeform', DateTime.now(), null, null, '', 'Missing "entries" array')];
  }
  for (final e in entries) {
    if (e is! Map<String, dynamic>) {
      result.add(BatchRow('freeform', DateTime.now(), null, null, '', 'Row is not an object'));
      continue;
    }
    final rawCat = (e['category'] as String? ?? 'freeform').trim().toLowerCase();
    final cat = alias?[rawCat] ?? rawCat;
    final known = kCategories.contains(cat);

    final dateStr = e['date'] as String?;
    DateTime? date;
    if (dateStr != null) {
      date = _parseDate(dateStr);
    }
    final value = e['value'] is num ? (e['value'] as num).toDouble() : null;

    final note = (e['note'] as String? ?? '').trim();
    result.add(BatchRow(
      cat,
      date ?? DateTime.now(),
      value,
      e['unit'] as String?,
      note,
      !known ? 'Unknown category "$rawCat" (map it or fix)' : (dateStr != null && date == null ? 'Bad date "$dateStr"' : null),
    ));
  }
  return result;
}

/// Strict date parse: Dart's `DateTime.tryParse` silently rolls out-of-range
/// fields over (2026-02-30 → 2026-03-02). Reject any value that doesn't
/// round-trip to the same YYYY-MM-DD. `ponytail:` full ISO/datetime normalization
/// is v0.2; the envelope is specified as YYYY-MM-DD.
DateTime? _parseDate(String s) {
  final d = DateTime.tryParse(s);
  if (d == null) return null;
  final short = s.length >= 10 ? s.substring(0, 10) : s;
  final norm = '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
  return short == norm ? d : null;
}

/// Fill-in-blank prompt a user can paste into an LLM so it emits the envelope.
const String kBatchPromptTemplate = '''
You are a structured data extractor. Output ONLY a JSON object, no prose, matching this exact shape:
{
  "entries": [
    {"date": "YYYY-MM-DD", "category": "<one of: food, water, health, study, fitness, sleep, mood, skin-hair, finance, freeform>", "value": <number or omit>, "unit": "<optional>", "note": "<short note>"}
  ]
}
Here is the activity to record: {PASTE_ACTIVITY}
''';

/// Bundled quick templates.
class BatchTemplate {
  final String name;
  final String activityPrompt;
  const BatchTemplate(this.name, this.activityPrompt);
}

const List<BatchTemplate> kBatchTemplates = [
  BatchTemplate('Workout', 'Log my workout session — exercises, sets, weights, duration.'),
  BatchTemplate('Morning routine', 'Log my morning: sleep hours, water, meditation, breakfast, mood on waking.'),
  BatchTemplate('Day summary', 'Log a full day: meals, study, fitness, mood, finances spent, notes.'),
];
