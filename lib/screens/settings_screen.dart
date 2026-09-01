import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../services/data_io.dart';
import '../services/notifications.dart';
import '../theme/theme.dart';
import 'batch_screen.dart';

/// Settings: data, armored reset, name, biometric, theme, about.
class SettingsScreen extends StatefulWidget {
  final AppDb db;
  final NotificationService notif;
  const SettingsScreen({super.key, required this.db, required this.notif});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _importCtrl = TextEditingController();

  // Armored reset staging
  bool _resetWarnAccepted = false;
  String _resetTyped = '';

  bool _biometric = false;
  String _theme = 'dark';
  String? _exportMsg;
  String? _importMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = p.getString('name') ?? '';
      _biometric = p.getBool('biometric') ?? false;
      _theme = p.getString('theme') ?? 'dark';
    });
  }

  Future<void> _setPref(String k, Object v) async {
    final p = await SharedPreferences.getInstance();
    if (v is bool) { await p.setBool(k, v); }
    else if (v is int) { await p.setInt(k, v); }
    else { await p.setString(k, v as String); }
  }

  Future<void> _export() async {
    try {
      final path = await DataIO(widget.db).exportJson();
      if (mounted) setState(() => _exportMsg = 'Exported to:\n$path');
    } catch (e) {
      if (mounted) setState(() => _exportMsg = 'Export failed: $e');
    }
  }

  Future<void> _import() async {
    final path = _importCtrl.text.trim();
    if (path.isEmpty) return;
    try {
      final r = await DataIO(widget.db).importJson(path);
      if (mounted) setState(() => _importMsg = 'Inserted ${r.inserted}, skipped ${r.skipped}.');
    } catch (e) {
      if (mounted) setState(() => _importMsg = 'Import failed: $e');
    }
  }

  /// Armored reset: backup first, then wipe everything.
  Future<void> _wipeAll() async {
    final backup = await DataIO(widget.db).exportJson();
    final entries = await widget.db.watchAllEntries().first;
    for (final e in entries) {
      await widget.db.deleteEntry(e.id);
    }
    final habits = await widget.db.allHabits();
    for (final h in habits) {
      await widget.db.removeHabit(h.id);
    }
    await widget.db.delete(widget.db.dailyNotes).go();
    final p = await SharedPreferences.getInstance();
    await p.remove('name');
    await p.remove('biometric');
    await p.remove('theme');
    await p.remove('reminders.afternoonOn');
    await p.remove('reminders.nightOn');
    await p.remove('reminders.afternoonMinute');
    await p.remove('reminders.nightMinute');
    await p.remove('reminders.targetHabitId');
    await p.remove('reminders.targetCount');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All data erased. Backup saved to:\n$backup')),
      );
      setState(() {
        _resetWarnAccepted = false;
        _resetTyped = '';
        _biometric = false;
        _theme = 'dark';
        _nameCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ivory,
        title: const Text('Settings', style: TextStyle(fontFamily: AppType.monument)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('DATA'),
          _card([
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brass, foregroundColor: AppColors.bg),
              onPressed: _export,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Export JSON'),
            ),
            if (_exportMsg != null) ...[
              const SizedBox(height: 8),
              Text(_exportMsg!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _importCtrl,
              style: const TextStyle(color: AppColors.ivory),
              decoration: const InputDecoration(
                hintText: 'Path to exported .json',
                hintStyle: TextStyle(color: AppColors.muted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.hairline)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.muted),
                onPressed: _import,
                child: const Text('Import JSON'),
              ),
            ),
            if (_importMsg != null) ...[
              const SizedBox(height: 8),
              Text(_importMsg!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            const Text(
              'Backup reminder: export regularly. Keep the file somewhere safe.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.brass),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BatchScreen(db: widget.db)),
              ),
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Batch paste (LLM output)'),
            ),
          ]),
          const SizedBox(height: 24),

          _section('ARMORED RESET'),
          _card([
            Text(
              'This permanently deletes ALL data on this device: every entry, habit, note, and setting. This cannot be undone.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _resetWarnAccepted,
              onChanged: (v) => setState(() => _resetWarnAccepted = v ?? false),
              title: const Text('I understand everything will be deleted forever.',
                  style: TextStyle(color: AppColors.ivory)),
              activeColor: AppColors.brass,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: AppColors.ivory),
              onChanged: (v) => setState(() => _resetTyped = v),
              decoration: const InputDecoration(
                labelText: 'Type RESET to confirm',
                labelStyle: TextStyle(color: AppColors.muted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.hairline)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: AppColors.lightSurface,
              ),
              onPressed:
                  (_resetWarnAccepted && _resetTyped == 'RESET') ? _onResetPressed : null,
              child: const Text('Reset everything'),
            ),
          ]),
          const SizedBox(height: 24),

          _section('NAME'),
          _card([
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.ivory),
              decoration: const InputDecoration(
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.hairline)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brass, foregroundColor: AppColors.bg),
                onPressed: () => _setPref('name', _nameCtrl.text.trim()),
                child: const Text('Save'),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          _section('BIOMETRIC LOCK'),
          _card([
            SwitchListTile(
              value: _biometric,
              onChanged: (v) {
                setState(() => _biometric = v);
                _setPref('biometric', v);
              },
              title: const Text('Gate with biometrics', style: TextStyle(color: AppColors.ivory)),
              activeTrackColor: AppColors.brass,
              contentPadding: EdgeInsets.zero,
            ),
            const Text(
              'When enabled, the next launch is gated behind biometrics. Best-effort: no effect on devices without a sensor.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 24),

          _section('THEME'),
          _card([
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'dark', label: Text('Dark')),
                ButtonSegment(value: 'light', label: Text('Light')),
                ButtonSegment(value: 'system', label: Text('System')),
              ],
              selected: {_theme},
              onSelectionChanged: (s) {
                setState(() => _theme = s.first);
                _setPref('theme', _theme);
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? AppColors.bg : AppColors.muted),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? AppColors.brass : AppColors.surface),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          _section('ABOUT'),
          _card([
            const Text('imperium', style: TextStyle(fontFamily: AppType.monument, fontSize: 20, color: AppColors.brass)),
            const SizedBox(height: 4),
            const Text('v0.1', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            const Text(
              'All data stays on this device. No account, no cloud, no telemetry.',
              style: TextStyle(color: AppColors.muted),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _onResetPressed() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Final confirmation', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        content: const Text(
          'A backup will be written first, then every entry, habit, note and setting is permanently deleted.',
          style: TextStyle(color: AppColors.ivory),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: AppColors.lightSurface),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, delete everything'),
          ),
        ],
      ),
    );
    if (ok == true) await _wipeAll();
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.6)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
