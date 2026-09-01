# imperium — Architecture

**Offline-first Android Flutter app. Local DB is the system of record; there is no server.**

## Stack
- Flutter (Dart) — Android, armv8a, SDK 36, minSdk compatible.
- **Drift** (+ drift_flutter, sqlite3_flutter_libs) — SQLite ORM, async, off main isolate.
- **local_auth** — biometric lock (best-effort, never hard-block).
- **flutter_local_notifications** — 2 daily nudges.
- **provider** — lightweight state.
- **intl** — dates/stats. **shared_preferences** — settings. **path_provider** — file paths.
- Fonts: **Cinzel** + **Archivo** bundled (offline).
- Renderer: **Impeller** (Vulkan) forced on Android for smoothness.

## Data model (Drift)

```
Entry
  id INTEGER PK AUTOINCREMENT
  category TEXT        // food|water|health|study|fitness|sleep|mood|skin-hair|finance|freeform
  text TEXT            // required
  emoji TEXT NULL
  rating INT NULL      // 1-5
  amount REAL NULL
  unit TEXT NULL
  loggedAt INT         // epoch ms (backfill: user-set)
  createdAt INT

Habit
  id, name TEXT, UNIQUE(name)

HabitCheck
  id, habitId FK, date TEXT(YYYY-MM-DD), UNIQUE(habitId,date)

DailyNote
  id, date TEXT UNIQUE, note TEXT

Setting (key/value via shared_preferences)
  name, habits, reminder after/8pm on+times, biometric, theme, notifyOn
```

Rollover: general categories roll at **00:00**; **sleep rolls at 04:00** (crosses midnight). Streak = "logged any entry that day" + per-habit streaks; stated, not vague.

## Modules

- `lib/db/` — Drift tables + DAOs (entries, habits, notes, queries).
- `lib/theme/` — imperial tokens (dark+light), type, spacing.
- `lib/screens/` — dashboard, log, stats, automation, batch, settings, onboarding.
- `lib/services/` — notifications, biometrics, export/import, batch parser, stats engine (Pearson, streak math, trends), quote corpus.
- `lib/widgets/` — ledger row, dot, quote card, FAB, sections.

## Data flow
UI → provider → DAO → Drift (async isolate). No work on the UI thread. Ledger rows render virtualized (visible only). `RepaintBoundary` per row.

## State
- Auth: none (offline). Optional biometric gate at launch: best-effort; no sensor → skip silently; never brick the device.
- Notifications: adaptive exact→inexact (`canScheduleExactAlarms()`); `zonedSchedule` + `matchDateTimeComponents.time`; boot receiver re-registers.

## Insight engine (rule/math-based, no LLM)
- Correlation probe: Pearson r over paired (both-logged) days, last N days; min paired N=5 before reporting.
- Streak: best / at-risk / to-tie.
- Trends: 7/30-day mean, delta vs prior, linear-slope direction.

## Export / import
JSON envelope, merge-by-id (no dupes), validate before write, review-confirm on batch import. **Armored reset**: warning → type `RESET` → auto-backup to Downloads → wipe.

## Perf contract
120Hz display; zero-jank bar on interactions. Impeller + const + virtualization + isolate-safe DB. Static ledger frames hit the refresh ceiling; heavy stat frames trade depth for smoothness.

## v0.2 hooks (designed now, not built)
- Photo column (nullable, local path) reserved in Entry.
- On-device model seam behind an `InsightProvider` interface so a future LLM can replace rule-based narrative without touching callers.
- `AIRequest`/`AIResult` sealed types stubbed — never faked in v0.1.

## Security (offline)
No network calls, no telemetry, no cloud. Data in app-private storage via path_provider (below 28 no WRITE_EXTERNAL permission; Downloads export via MediaStore). Biometric optional. See SECURITY.md.
