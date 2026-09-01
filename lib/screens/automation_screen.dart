import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../services/notifications.dart';
import '../theme/theme.dart';

/// Automation: daily reminders + habit ledger.
class AutomationScreen extends StatefulWidget {
  final AppDb db;
  final NotificationService notif;
  const AutomationScreen({super.key, required this.db, required this.notif});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen>
    with SingleTickerProviderStateMixin {
  static const _kPref = 'reminders.';
  late final TabController _tab;
  int _cur = 0;

  // Reminders
  late bool _afternoonOn;
  late bool _nightOn;
  late TimeOfDay _afternoon;
  late TimeOfDay _night;
  String? _permMsg;

  // Habits
  final _addCtrl = TextEditingController();
  List<Habit> _habs = const [];

  // Weekly target
  late int _targetHabitId;
  late int _targetCount;
  bool _targetLoaded = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(() {
      if (_cur != _tab.index) setState(() => _cur = _tab.index);
    });
    _afternoonOn = true;
    _nightOn = true;
    _afternoon = const TimeOfDay(hour: 17, minute: 0);
    _night = const TimeOfDay(hour: 21, minute: 0);
    _loadPrefs();
    _reloadHabits();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _afternoonOn = p.getBool('${_kPref}afternoonOn') ?? true;
      _nightOn = p.getBool('${_kPref}nightOn') ?? true;
      _afternoon = _t(p.getInt('${_kPref}afternoonMinute'), const TimeOfDay(hour: 17, minute: 0));
      _night = _t(p.getInt('${_kPref}nightMinute'), const TimeOfDay(hour: 21, minute: 0));
      _targetHabitId = p.getInt('${_kPref}targetHabitId') ?? -1;
      _targetCount = p.getInt('${_kPref}targetCount') ?? 7;
      _targetLoaded = true;
    });
  }

  TimeOfDay _t(int? m, TimeOfDay def) =>
      m == null ? def : TimeOfDay(hour: m ~/ 60, minute: m % 60);

  void _reloadHabits() {
    widget.db.allHabits().then((h) {
      if (mounted) setState(() => _habs = h);
    });
  }

  Future<void> _saveReminders() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('${_kPref}afternoonOn', _afternoonOn);
    await p.setBool('${_kPref}nightOn', _nightOn);
    await p.setInt('${_kPref}afternoonMinute', _afternoon.hour * 60 + _afternoon.minute);
    await p.setInt('${_kPref}nightMinute', _night.hour * 60 + _night.minute);
    await widget.notif.scheduleReminders(
      afternoonOn: _afternoonOn,
      nightOn: _nightOn,
      afternoonHour: _afternoon.hour,
      afternoonMinute: _afternoon.minute,
      nightHour: _night.hour,
      nightMinute: _night.minute,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminders saved.')),
      );
    }
  }

  Future<void> _pickTime(bool afternoon) async {
    final t = await showTimePicker(
      context: context,
      initialTime: afternoon ? _afternoon : _night,
    );
    if (t == null) return;
    setState(() => afternoon ? _afternoon = t : _night = t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ivory,
        title: const Text('Automation', style: TextStyle(fontFamily: AppType.monument)),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            indicatorColor: AppColors.brass,
            labelColor: AppColors.brass,
            unselectedLabelColor: AppColors.muted,
            tabs: const [
              Tab(text: 'Reminders'),
              Tab(text: 'Habits'),
            ],
          ),
          Expanded(child: _cur == 0 ? _reminders() : _habitsTab()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Widget _reminders() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _rowToggle('Afternoon', _afternoonOn, (v) => setState(() => _afternoonOn = v),
            onTap: () => _pickTime(true), time: _afternoon),
        const SizedBox(height: 4),
        _rowToggle('Night', _nightOn, (v) => setState(() => _nightOn = v),
            onTap: () => _pickTime(false), time: _night),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brass, foregroundColor: AppColors.bg),
          onPressed: _saveReminders,
          child: const Text('Save reminders'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.muted),
          onPressed: () async {
            final granted = await widget.notif.requestPermission();
            if (mounted) setState(() => _permMsg = granted == true ? 'Permission granted.' : 'Permission not granted.');
          },
          child: const Text('Request permission'),
        ),
        if (_permMsg != null) ...[
          const SizedBox(height: 8),
          Text(_permMsg!, style: const TextStyle(color: AppColors.muted)),
        ],
        const SizedBox(height: 16),
        const Text('Reminders nudge you to log the day. Current times restore on launch.',
            style: TextStyle(color: AppColors.muted)),
      ],
    );
  }

  Widget _rowToggle(String label, bool value, ValueChanged<bool> onChanged,
      {required VoidCallback onTap, required TimeOfDay time}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text('$label  ${time.format(context)}',
                  style: const TextStyle(color: AppColors.ivory)),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.brass,
          ),
        ],
      ),
    );
  }

  Widget _habitsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('WEEKLY TARGET', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.6)),
        const SizedBox(height: 8),
        _weeklyTarget(),
        const SizedBox(height: 24),
        const Text('HABITS', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.6)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                style: const TextStyle(color: AppColors.ivory),
                decoration: const InputDecoration(
                  hintText: 'New habit',
                  hintStyle: TextStyle(color: AppColors.muted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.hairline)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brass, foregroundColor: AppColors.bg),
              onPressed: _addHabit,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._habs.map((h) => _habitRow(h)),
      ],
    );
  }

  Future<void> _addHabit() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    _addCtrl.clear();
    await widget.db.addHabit(name);
    _reloadHabits();
  }

  Widget _habitRow(Habit h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(child: Text(h.name, style: const TextStyle(color: AppColors.ivory))),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
            onPressed: () async {
              await widget.db.removeHabit(h.id);
              _reloadHabits();
            },
          ),
        ],
      ),
    );
  }

  Widget _weeklyTarget() {
    if (!_targetLoaded) return const SizedBox.shrink();
    final sel = _habs.where((h) => h.id == _targetHabitId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DropdownButton<int>(
              value: sel == null ? null : _targetHabitId,
              hint: const Text('Target habit', style: TextStyle(color: AppColors.muted)),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.ivory),
              items: _habs.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))).toList(),
              onChanged: (v) async {
                setState(() => _targetHabitId = v ?? -1);
                final p = await SharedPreferences.getInstance();
                await p.setInt('${_kPref}targetHabitId', v ?? -1);
              },
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _targetCount,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.ivory),
              items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}/week'))),
              onChanged: (v) async {
                setState(() => _targetCount = v ?? 7);
                final p = await SharedPreferences.getInstance();
                await p.setInt('${_kPref}targetCount', _targetCount);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _TargetStatus(db: widget.db, habitId: _targetHabitId, target: _targetCount),
      ],
    );
  }
}

/// Honest weekly pace: how many days this week have any entry at all.
class _TargetStatus extends StatelessWidget {
  final AppDb db;
  final int habitId;
  final int target;
  const _TargetStatus({required this.db, required this.habitId, required this.target});

  Future<int> _daysLogged() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    var days = 0;
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      if ((await db.entriesForDate(d)).isNotEmpty) days++;
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (habitId <= 0) {
      return const Text('Pick a habit to track pace.',
          style: TextStyle(color: AppColors.muted));
    }
    return FutureBuilder<int>(
      future: _daysLogged(),
      builder: (context, snap) {
        final days = snap.data ?? 0;
        final onPace = days >= target;
        final txt = onPace
            ? 'On pace: $days / $target days logged this week.'
            : 'Short of target: $days / $target days logged this week.';
        return Text(txt,
            style: TextStyle(
                color: onPace ? AppColors.brass : AppColors.muted, fontSize: 13));
      },
    );
  }
}
