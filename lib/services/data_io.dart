import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:drift/drift.dart';

import '../db/database.dart';

/// Export/import the whole dataset as JSON. Merge-by-id on import (no dupes).
/// Backup path: Downloads via MediaStore is complex; exports land in the app
/// documents dir and can be shared. `ponytail:` ceiling — full file picker /
/// proper Android Downloads directory is v0.2.

class DataIO {
  final AppDb db;
  DataIO(this.db);

  /// Serialize the whole dataset to a JSON string (off-device backup payload).
  Future<String> buildJson() async {
    final entries = await db.watchAllEntries().first;
    final habits = await db.allHabits();
    final notes = await (db.select(db.dailyNotes)).get();
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries.map(_entryToJson).toList(),
      'habits': habits.map((h) => {'id': h.id, 'name': h.name}).toList(),
      'notes': notes.map((n) => {'date': n.date, 'note': n.note}).toList(),
    });
  }

  /// Write a backup into the app documents dir. Used by armored reset.
  /// `ponytail:` ceiling — not user-navigable on Android 13+; the UI surface
  /// uses the SAF picker (buildJson + saveFile) instead. Kept for reset + tests.
  Future<String> exportJson() async {
    final json = await buildJson();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/imperium-backup-${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file.path;
  }

  Map<String, Object?> _entryToJson(Entry e) => {
        'id': e.id,
        'category': e.category,
        'note': e.note,
        'emoji': e.emoji,
        'rating': e.rating,
        'amount': e.amount,
        'unit': e.unit,
        'loggedAt': e.loggedAt,
      };

  /// Merge-by-id from raw JSON text (picker bytes or a file). Returns counts.
  Future<({int inserted, int skipped})> importJsonString(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (data['entries'] as List? ?? []).cast<Map<String, dynamic>>();

    var inserted = 0, skipped = 0;
    await db.transaction(() async {
      for (final m in entries) {
        final id = m['id'] as int?;
        final existing = id == null ? null : await db.entryById(id);
        if (existing != null) continue; // skip dupes
        await db.addEntry(EntriesCompanion.insert(
          category: m['category'] as String? ?? 'freeform',
          note: m['note'] as String? ?? '',
          emoji: Value(m['emoji'] as String?),
          rating: Value<int?>(m['rating'] as int?),
          amount: Value<double?>(m['amount'] is num ? (m['amount'] as num).toDouble() : null),
          unit: Value(m['unit'] as String?),
          loggedAt: (m['loggedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
        inserted++;
      }
    });
    skipped += entries.length - inserted;
    return (inserted: inserted, skipped: skipped);
  }

  /// Merge-by-id from a file path. Thin wrapper over [importJsonString].
  Future<({int inserted, int skipped})> importJson(String path) async {
    final raw = await File(path).readAsString();
    return importJsonString(raw);
  }
}
