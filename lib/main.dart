import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database.dart';
import 'screens/automation_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/biometric.dart';
import 'services/notifications.dart';
import 'theme/theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge (Android 15/16): keep the status bar away from app content.
  // `ponytail:` ceiling — no per-screen inset wiring; AnnotatedRegion alone
  // forces our control, and mobile (not persistent) mode keeps the nav tray
  // from overlaying the ledger.*/
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS only
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  final db = AppDb();
  final notif = NotificationService();
  try {
    await notif.init();
  } catch (_) {
    // Best-effort: a failed notification init must not block the app.
  }

  // Ask for notification permission + remember the theme choice up front.
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = prefs.getString('theme') ?? 'dark';
  try {
    await notif.requestPermission();
  } catch (_) {
    // Best-effort.
  }

  runApp(ImperiumApp(db: db, notif: notif));
}

final ValueNotifier<String> themeNotifier = ValueNotifier<String>('dark');

class ImperiumApp extends StatelessWidget {
  const ImperiumApp({super.key, required this.db, required this.notif});

  final AppDb db;
  final NotificationService notif;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        final mode = switch (currentTheme) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        };
        return MaterialApp(
          title: 'imperium',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: mode,
          home: Gate(db: db, notif: notif),
        );
      },
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
    final bioPref = p.getBool('biometric') ?? false;
    final bioAvailable = bioPref ? await BiometricGate().isAvailable() : false;
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _nameSet = hasName;
      _locked = hasName && bioPref && bioAvailable;
    });
    if (hasName && bioPref && bioAvailable) {
      _unlock();
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  style: style.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              TextField(
                controller: _c,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface, fontFamily: AppType.ledger),
                decoration: InputDecoration(
                  labelText: 'What shall we call you?',
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldDeep)),


                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  style: style.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: onUnlock,
                child: const Text('UNLOCK', style: TextStyle(fontFamily: AppType.monument)),
              ),
              TextButton(onPressed: onSkip, child: Text('Skip', style: TextStyle(color: colorScheme.onSurfaceVariant))),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            DashboardScreen(db: widget.db),
            HistoryScreen(db: widget.db),
            StatsScreen(db: widget.db),
            AutomationScreen(db: widget.db, notif: widget.notif),
            SettingsScreen(db: widget.db, notif: widget.notif),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LogScreen(db: widget.db)),
        ),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: colorScheme.surface,
        selectedItemColor: AppColors.brass,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Ledger'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Auto'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

