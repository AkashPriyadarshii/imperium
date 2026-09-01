import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database.dart';
import 'screens/automation_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/biometric.dart';
import 'services/notifications.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDb();
  final notif = NotificationService();
  try {
    await notif.init();
  } catch (_) {
    // Best-effort: a failed notification init must not block the app.
  }
  runApp(ImperiumApp(db: db, notif: notif));
}

class ImperiumApp extends StatelessWidget {
  const ImperiumApp({super.key, required this.db, required this.notif});

  final AppDb db;
  final NotificationService notif;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'imperium',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.dark),
      home: Gate(db: db, notif: notif),
    );
  }
}

/// Onboarding (first run: ask a name) then optional biometric lock.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.db, required this.notif});
  final AppDb db;
  final NotificationService notif;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  SharedPreferences? _prefs;
  bool _nameSet = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final p = await SharedPreferences.getInstance();
    final hasName = (p.getString('name') ?? '').trim().isNotEmpty;
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _nameSet = hasName;
      _locked = hasName && (p.getBool('biometric') ?? false);
    });
  }

  Future<void> _saveName(String name) async {
    await _prefs?.setString('name', name.trim());
    if (!mounted) return;
    setState(() => _nameSet = true);
  }

  Future<void> _unlock() async {
    final ok = await BiometricGate().gate();
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_prefs == null) {
      return const Scaffold(backgroundColor: AppColors.bg);
    }
    if (!_nameSet) return _Onboarding(onDone: _saveName);
    if (_locked) return _BiometricLock(onUnlock: _unlock, onSkip: () => setState(() => _locked = false));
    return Shell(db: widget.db, notif: widget.notif);
  }
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.onDone});
  final ValueChanged<String> onDone;
  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('IMPERIUM', textAlign: TextAlign.center,
                  style: style.displaySmall?.copyWith(color: AppColors.brass, fontFamily: AppType.monument)),
              const SizedBox(height: 8),
              Text('Your ledger. For you alone.', textAlign: TextAlign.center,
                  style: style.bodyMedium?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 32),
              TextField(
                controller: _c,
                autofocus: true,
                style: const TextStyle(color: AppColors.ivory, fontFamily: AppType.ledger),
                decoration: InputDecoration(
                  labelText: 'What shall we call you?',
                  labelStyle: const TextStyle(color: AppColors.muted),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.hairline)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldDeep)),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.goldDeep),
                onPressed: () {
                  if (_c.text.trim().isNotEmpty) widget.onDone(_c.text);
                },
                child: const Text('BEGIN', style: TextStyle(fontFamily: AppType.monument)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricLock extends StatelessWidget {
  const _BiometricLock({required this.onUnlock, required this.onSkip});
  final Future<void> Function() onUnlock;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('IMPERIUM', textAlign: TextAlign.center,
                  style: style.displaySmall?.copyWith(color: AppColors.brass, fontFamily: AppType.monument)),
              const SizedBox(height: 16),
              Text('Verify to continue', textAlign: TextAlign.center,
                  style: style.bodyMedium?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.goldDeep),
                onPressed: onUnlock,
                child: const Text('UNLOCK', style: TextStyle(fontFamily: AppType.monument)),
              ),
              TextButton(onPressed: onSkip, child: const Text('Skip', style: TextStyle(color: AppColors.muted))),
            ],
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.db, required this.notif});
  final AppDb db;
  final NotificationService notif;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(db: widget.db),
          StatsScreen(db: widget.db),
          AutomationScreen(db: widget.db, notif: widget.notif),
          SettingsScreen(db: widget.db, notif: widget.notif),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.goldDeep,
        foregroundColor: AppColors.bg,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LogScreen(db: widget.db)),
        ),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brass,
        unselectedItemColor: AppColors.muted,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Ledger'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Auto'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
