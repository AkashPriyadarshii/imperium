<div align="center">

# 🏛️ Imperium — Private Offline-First Life Tracker & Discipline Ledger

### Your life. Your ledger. For you alone.

**100% Local. Zero Cloud. Zero Telemetry. Zero Compromise.**
**Built for Android 16. Drift SQLite in Background Isolate. 120Hz Impeller.**

*Keywords: android life tracker, offline life tracker, bullet journal android, drift sqlite, flutter offline app, privacy habit tracker, personal discipline ledger, quantified self android, offline expense tracker, local streak tracker, pearson correlation analytics, biometric lock tracker, zero cloud journal, local first android app*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%209.0%2B-brightgreen.svg)](https://developer.android.com)
[![Target API](https://img.shields.io/badge/Target%20API-36%20(Android%2016)-brightgreen.svg)](https://developer.android.com)
[![Architecture](https://img.shields.io/badge/Architecture-ARM64%20(v8a)-orange.svg)]()
[![Tests](https://img.shields.io/badge/Tests-20%20passing-brightgreen.svg)]()
[![Database](https://img.shields.io/badge/Database-Drift%20SQLite%20(Isolate)-blueviolet.svg)]()
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local%20(No%20Internet)-purple.svg)]()

</div>

---

## What is Imperium?

**Imperium** is an offline-first life tracking and daily discipline ledger for Android. It replaces fragmented tracking apps (habit trackers, mood journals, expense logs, sleep diaries, study timers) with a unified, high-performance local database.

Most modern tracking applications harvest behavioral telemetry, require recurring cloud subscriptions, or inject speculative AI wrappers. Imperium executes entirely on-device. All database transactions, streak calculations, habit verifications, and statistical correlation probes run locally on your phone's CPU via a dedicated SQLite background isolate.

---

## ⚡ Performance & Engineering Benchmarks

| Metric | Target / Benchmark | Implementation Detail |
|---|---|---|
| **Render Rate** | **120 FPS / 8.3ms** | Flutter Impeller Vulkan backend with isolated repaint boundaries |
| **Query Latency** | **< 2ms** | Drift ORM running over background SQLite isolate |
| **Network Traffic** | **0 KB / 0 Requests** | `android.permission.INTERNET` omitted from `AndroidManifest.xml` |
| **Cold Start** | **< 250ms** | Eager database initialization and compiled Ahead-Of-Time (AOT) Dart |
| **Binary Footprint** | **~21 MB APK** | Stripped ARM64-v8a native binary with dead-code elimination |
| **Memory Footprint** | **< 45 MB RSS** | Reactive streams with auto-disposing subscribers |

---

## 📊 Comparison: Imperium vs. Mainstream Trackers

| Feature | Notion / Cloud Apps | Daylio / Habitica | Excel / Spreadsheets | **Imperium** |
|---|---|---|---|---|
| **Data Privacy** | ❌ Server Stored | ❌ Cloud Sync / Ads | ⚠️ Local Files | ✅ **100% Local Sandbox** |
| **Internet Required** | ❌ Always Online | ⚠️ Partial Offline | ❌ Manual Sync | ✅ **Zero Network Access** |
| **Biometric Lock** | ❌ Subscription / None | ⚠️ Basic PIN | ❌ None | ✅ **Hardware BiometricPrompt** |
| **Statistical Engine** | ❌ None / AI summaries | ⚠️ Simple Averages | ⚠️ Complex Formulas | ✅ **Built-in Pearson $r$ ($N \ge 5$)** |
| **Asymmetric Rollover** | ❌ Fixed 00:00 | ❌ Fixed 00:00 | ❌ Manual date offset | ✅ **04:00 AM Sleep Rollover** |
| **Backup Protocol** | ❌ Vendor Lock-in | ⚠️ Proprietary Cloud | ⚠️ Manual File Copy | ✅ **SAF JSON + Armored Reset** |
| **UI Rendering** | ⚠️ Webview / DOM | ⚠️ Standard Native | ⚠️ Grid Sheets | ✅ **120Hz Impeller Native** |
| **Subscription Cost** | ❌ $8–$20 / month | ❌ $3–$6 / month | ❌ Office 365 Sub | ✅ **Free & Open Source** |

---

## 🛠️ Feature Modules

### 1. 🏛️ Daily Discipline Ledger
- **Multi-Category Tracking**: Food, hydration, health, study, fitness, sleep, mood, personal finance, and freeform logs.
- **Micro-Input System**: Quick numerical amounts, custom units, 1–5 qualitative ratings, contextual emojis, and notes.
- **Asymmetric Rollover**: Standard logs bind to the calendar day; sleep logs offset by 4 hours (`t - 4h`) so 02:00 AM sleep entries attach to the prior night's ledger.
- **Streak & Momentum Tracking**: Real-time evaluation of consecutive logging days, all-time best streaks, target distance, and dynamic at-risk warnings after 20:00.

### 2. 📈 Deterministic Analytics Engine (No Fake AI)
- **Pearson Correlation Probe**: Discovers mathematical relationships between paired time-series categories (e.g. study hours vs. sleep quality) with strict sample thresholding ($N \ge 5$).
- **7-Day & 30-Day Moving Averages**: Rolling baseline calculations with percentage delta comparisons against previous 30-day windows.
- **Scoreboard Dashboard**: Instant weekly aggregates for average sleep duration, total 7-day spending, and active logging streaks.

### 3. 🔒 Hardened Local Security & Data Portability
- **Biometric Authentication Gate**: Integrated with Android's `BiometricPrompt` (`local_auth` 3.0.2) supporting fingerprint and face unlock with seamless fallback.
- **Storage Access Framework (SAF)**: Native Android file picker integration for direct JSON export and import.
- **Idempotent Data Import**: Merge-based ingestion that preserves record timestamps and prevents duplicate entries.
- **Armored Reset Protocol**: Multi-step destructive reset requiring explicit checkbox consent, exact `RESET` keyword typing, and automated pre-wipe SAF backup creation.

### 4. 🎨 Stoic Imperial Design System
- **Dual-Accent Color Tokens**: Imperial Dark (`#141312` granite base with `#C9A25F` brass gold accents) and Imperial Light (`#F1EBDF` parchment base).
- **Embedded Typography**: Bundled offline fonts: Cinzel (Roman inscription serif) for monuments and Archivo (grotesque with tabular numerals `tnum`) for ledger alignment.
- **Dynamic Theme Switcher**: Global `ValueNotifier` theme engine applying instantaneous live palette shifts without app restarts.

---

## 🏛️ System Architecture

```
                                  IMPERIUM ARCHITECTURE
+---------------------------------------------------------------------------------------+
|                                    PRESENTATION LAYER                                 |
|   DashboardScreen   |   HistoryScreen   |   LogScreen   |   Settings   |   Automation |
|   (120Hz Impeller)  |  (Date Grouping)  | (Quick Input) |  (SAF & Bio) | (Habit Pace) |
+---------------------------------------------------------------------------------------+
                                           │
                                           ▼
+---------------------------------------------------------------------------------------+
|                                      STATE & ENGINE                                   |
|   ValueNotifier<Theme>   |   StatsEngine (Pearson r)   |   NotificationService (TZ)   |
+---------------------------------------------------------------------------------------+
                                           │
                                           ▼
+---------------------------------------------------------------------------------------+
|                               PERSISTENCE & STORAGE (ISOLATE)                         |
|   Drift ORM (Generated Queries) ──► sqlite3_flutter_libs (Background Worker Isolate)  |
|   SharedPreferences (Local Settings) ──► Android App-Private Storage Sandbox          |
+---------------------------------------------------------------------------------------+
```

---

## 🗄️ Database Schema

```
+------------------------------------+        +------------------------------------+
|              Entries               |        |               Habits               |
+------------------------------------+        +------------------------------------+
| id          INTEGER PK AUTOINC     |        | id          INTEGER PK AUTOINC     |
| category    TEXT NOT NULL          |        | name        TEXT NOT NULL UNIQUE   |
| note        TEXT NOT NULL          |        +------------------------------------+
| emoji       TEXT NULLABLE          |                          │
| rating      INTEGER NULLABLE (1-5) |                          │ 1:N
| amount      REAL NULLABLE          |                          ▼
| unit        TEXT NULLABLE          |        +------------------------------------+
| loggedAt    INTEGER NOT NULL (ms)  |        |            HabitChecks             |
| createdAt   INTEGER NOT NULL (ms)  |        +------------------------------------+
+------------------------------------+        | id          INTEGER PK AUTOINC     |
                                              | habitId     INTEGER FK (Habits.id) |
+------------------------------------+        | date        TEXT NOT NULL (YYYY-MM)|
|             DailyNotes             |        +------------------------------------+
+------------------------------------+
| id          INTEGER PK AUTOINC     |
| date        TEXT NOT NULL UNIQUE   |
| note        TEXT NOT NULL          |
+------------------------------------+
```

---

## 🧪 Test Suite & Quality Verification

| Test Module | Coverage Area | Status |
|---|---|---|
| **`test_streak.dart`** | Streak continuity, empty database, multi-day roll, at-risk flags | ✅ Passing |
| **`db_test.dart`** | Drift SQLite CRUD, foreign keys, unique constraints, cascade rules | ✅ Passing |
| **`stats_engine_test.dart`** | Pearson correlation coefficient math, covariance, sample guard $N \ge 5$ | ✅ Passing |
| **`data_io_test.dart`** | SAF JSON serialization, schema migration, duplicate prevention | ✅ Passing |
| **`notification_test.dart`** | Timezone resolution, exact alarm fallback, daily schedule logic | ✅ Passing |

```bash
# Run complete test suite locally
flutter test
```

---

## 🚀 Quick Start & Installation

### Download Pre-built APK
Download the latest verified release from [Releases](https://github.com/AkashPriyadarshii/imperium/releases):
- `imperium-0.1.0-arm64-v8a.apk` (Target: ARM64 Android 9.0+)

### Build from Source

```bash
# 1. Clone repository
git clone https://github.com/AkashPriyadarshii/imperium.git
cd imperium

# 2. Fetch Dart dependencies
flutter pub get

# 3. Compile Drift SQLite database bindings
dart run build_runner build --delete-conflicting-outputs

# 4. Execute test suite
flutter test

# 5. Build optimized release APK (arm64)
flutter build apk --release --target-platform android-arm64
```

---

## 🔍 SEO — Technical Reference

**Imperium** is an **offline-first Android life tracker** and **personal discipline ledger** built with **Flutter** and **Drift SQLite**. It provides an alternative to cloud-based tracking software for users requiring strict data privacy, hardware-backed biometric security, and local mathematical analysis.

### Search Taxonomy

| Category | Keywords |
|---|---|
| **Core** | android life tracker, offline life tracker, personal ledger app, bullet journal android |
| **Database & Engine** | drift sqlite flutter, local first database, sqlite isolate, offline first architecture |
| **Privacy & Security** | privacy habit tracker, no cloud journal, biometric lock android, local data storage |
| **Quantified Self** | pearson correlation tracker, mood sleep correlation, streak engine, daily discipline tracker |
| **Alternatives** | notion alternative offline, daylio alternative foss, habitica alternative private, local excel tracker |
| **Platform** | android 16 ready, material 3 flutter, 120hz impeller android, arm64 flutter apk |

---

## 👤 Author

**Akash Priyadarshi**
- **GitHub**: [@AkashPriyadarshii](https://github.com/AkashPriyadarshii)
- **Portfolio**: [akashpriyadarshi.vercel.app](https://akashpriyadarshii.vercel.app)
- **Resume**: [akashpriyadarshii.github.io/Resume](https://akashpriyadarshii.github.io/Resume/)
- **X / Twitter**: [@Akash__ydv001](https://twitter.com/Akash__ydv001)
- **LinkedIn**: [akash-priyadarshi](https://linkedin.com/in/akash-priyadarshi-1aa51b37a)

---

<div align="center">

*Your life. Your ledger. For you alone.*

</div>
