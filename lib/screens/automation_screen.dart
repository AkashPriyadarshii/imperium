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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: const Text('Automation', style: TextStyle(fontFamily: AppType.monument)),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
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
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
          onPressed: _saveReminders,
          child: const Text('Save reminders'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () async {
            final granted = await widget.notif.requestPermission();
            if (mounted) setState(() => _permMsg = granted == true ? 'Permission granted.' : 'Permission not granted.');
          },
          child: const Text('Request permission'),
        ),
        if (_permMsg != null) ...[
          const SizedBox(height: 8),
          Text(_permMsg!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        Text('Reminders nudge you to log the day. Current times restore on launch.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _rowToggle(String label, bool value, ValueChanged<bool> onChanged,
      {required VoidCallback onTap, required TimeOfDay time}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                '$label  ${time.format(context)}',
                style: TextStyle(color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        Text('WEEKLY TARGET', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1.6)),
        const SizedBox(height: 8),
        _weeklyTarget(),
        const SizedBox(height: 24),
        Text('HABITS', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1.6)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'New habit',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  h.name.toUpperCase(),
                  style: TextStyle(color: cs.onSurface, fontFamily: AppType.ledger, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant, size: 20),
                onPressed: () async {
                  await widget.db.removeHabit(h.id);
                  _reloadHabits();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          _HabitWeekStrip(db: widget.db, habitId: h.id),
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
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<int>(
              value: sel == null ? null : _targetHabitId,
              hint: Text('Target habit', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: _habs.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) async {
                setState(() => _targetHabitId = v ?? -1);
                final p = await SharedPreferences.getInstance();
                await p.setInt('${_kPref}targetHabitId', v ?? -1);
              },
            ),
            DropdownButton<int>(
              value: _targetCount,
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

/// 7-day consistency strip showing current week's completion for a habit.
class _HabitWeekStrip extends StatelessWidget {
  const _HabitWeekStrip({required this.db, required this.habitId});
  final AppDb db;
  final int habitId;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Future<List<bool>> _fetchWeek() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final results = <bool>[];
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      results.add(await db.isHabitChecked(habitId, k));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<bool>>(
      future: _fetchWeek(),
      builder: (context, snap) {
        final checks = snap.data ?? List.filled(7, false);
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 7; i++) ...[
                Column(
                  children: [
                    Text(
                      _days[i],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: checks[i] ? AppColors.brass : Colors.transparent,
                        border: Border.all(
                          color: checks[i] ? AppColors.brass : Theme.of(context).colorScheme.outlineVariant,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < 6) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Honest weekly pace: counts completions of the specific habit.
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
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (await db.isHabitChecked(habitId, k)) days++;
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (habitId <= 0) {
      return Text('Pick a habit to track pace.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    return FutureBuilder<int>(
      future: _daysLogged(),
      builder: (context, snap) {
        final days = snap.data ?? 0;
        final onPace = days >= target;
        final txt = onPace
            ? 'On pace: $days / $target target days completed this week.'
            : 'Short of target: $days / $target target days completed this week.';
        return Text(txt,
            style: TextStyle(
                color: onPace ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13));
      },
    );
  }
}

