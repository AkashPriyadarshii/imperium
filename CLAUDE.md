# CLAUDE.md — imperium

Offline-first Android life-tracker for Akash ("my everything": food, health, study, fitness, sleep, mood, skin-hair, finance, habits + freeform). Flutter/Dart, Drift SQLite, no server, no cloud, no auth. Proprietary license, private repo.

## Commands
- Run: `flutter run` (Android device/emulator)
- Test: `flutter test` (full suite locally, always)
- Build release (armv8a-only, ~20MB): `flutter build apk --release --target-platform android-arm64`
- DB codegen after schema change: `dart run build_runner build --delete-conflicting-outputs`

## Build lessons (learned the hard way)
- **Drift column names:** a `TextColumn get text` collides with drift's `Table.text()` builder and silently breaks codegen (empty `database.g.dart` stub → cascade of fake errors). Named the catch-all column `note`. Never name a Drift column `text`.
- **flutter_local_notifications v22+ needs core library desugaring** — `flutter build` fails `checkReleaseAarMetadata` with "requires core library desugaring" unless `android/app/build.gradle.kts` sets `isCoreLibraryDesugaringEnabled = true` + adds `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
- **`--split-per-abi` conflicts with `ndk { abiFilters }`** (EvalIssueException "Conflicting configuration"). Pick one. For an armv8a-only device, drop `--split-per-abi` and use `--target-platform android-arm64` — yields a tight 20MB APK. Keep `abiFilters arm64-v8a` in gradle as intent documentation.
- **flutter_local_notifications needs a direct `timezone` dep** (^0.11 for v22). It's only transitive otherwise → `depend_on_referenced_packages`.
- **v22 zonedSchedule API:** named params `id/title/body/scheduledDate/notificationDetails`, `initialize(settings: ..., onDidReceiveNotificationResponse: ...)`, and `requestExactAlarmsPermission()` lives on `AndroidFlutterLocalNotificationsPlugin` (via `resolvePlatformSpecificImplementation`), not the plugin root.

## Guardrails
- **No network, no telemetry, no cloud.** Data stays on device. Never wire a key/API without explicit ask.
- **No fake AI.** Rule/math-based insight only (Pearson, streaks, trends). Dishonest intelligence is a defect.
- **Armored delete only.** Reset-all: warning → type `RESET` → auto-backup → wipe.
- **Design is locked** in DESIGN.md (single source of truth). Gold scarce & semantic; ivory = reading type; liturgical Cinzel/Archivo. Don't re-skin.
- Anti-slop prose for anything shipped (README, release notes). Terse in chat.
- Docs order established: PRD / DESIGN / ARCHITECTURE / PLAN live at root (this file uses @-includes disabled — keep flat).

## Structure
See ARCHITECTURE.md. Modules: db/, theme/, screens/, services/, widgets/.

## Standing rules
- Git identity pinned: AkashPriyadarshii + noreply email.
- Private repo: never push public. "go" gates any push.
- Commit imperative-present, conventional types.
- Tests: full suite always runs locally, never CI-only.
