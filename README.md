# Imperium

Private, offline-first life tracker and daily discipline ledger for Android. Built with Flutter, Drift (SQLite), and local math analytics. Zero accounts, zero cloud dependencies, zero network requests, zero telemetry.

Designed and engineered by **Akash Priyadarshi** ([@AkashPriyadarshii](https://github.com/AkashPriyadarshii)).

---

## Overview

Most tracking applications require third-party servers, harvest personal behavioral data, or rely on LLM wrappers. Imperium takes the opposite approach: your phone is the sole system of record. Every log entry, streak calculation, habit check, and statistical correlation runs completely on-device in a dedicated background SQLite isolate.

```
+-----------------------------------------------------------------------+
|                           IMPERIUM RUNTIME                            |
+-----------------------------------------------------------------------+
| UI Layer          Material 3 / Cinzel + Archivo / Impeller (Vulkan)   |
| State             Provider (Reactive UI state, zero-jank frame flow)  |
| Services          LocalAuth (Biometrics) / Notification Scheduler     |
| Analytics         Local Math Engine (Pearson r, Streak & Trend Math)  |
| Database          Drift ORM + sqlite3_flutter_libs (Background Isolate)|
| Storage           App-Private Sandbox + Storage Access Framework (SAF)|
+-----------------------------------------------------------------------+
| TARGET: Android 16 (API 36) | Min SDK: 28 | Arch: arm64-v8a           |
+-----------------------------------------------------------------------+
```

---

## Technical Highlights

### 1. Offline-First Architecture & Storage
- **Drift SQLite Engine**: Strongly-typed Dart ORM running on SQLite via `sqlite3_flutter_libs` in a background isolate. Prevents UI thread blocking during high-volume queries.
- **Strict Data Sandbox**: All tables live in app-private storage. No internet permissions (`android.permission.INTERNET` is not included in the manifest).
- **Storage Access Framework (SAF) Backup**: Full JSON export and merge-based import with duplicate prevention. Armored reset protocol requires typing confirmation and produces an automated local backup file before wiping data.

### 2. High-Performance Mobile UI
- **Hardware-Accelerated Rendering**: Impeller Vulkan backend configured for 120Hz refresh displays.
- **Stoic Imperial Design System**: Minimal dual-accent theme (Dark: `#141312` granite base with `#C9A25F` brass gold accents; Light: `#F1EBDF` parchment base).
- **Embedded Typography**: Bundled offline assets including Cinzel (Roman inscription serif) and Archivo (grotesque with tabular numerals `tnum` for ledger alignment).
- **Isolated Repaint Boundaries**: Each ledger row updates inside independent boundaries to eliminate unnecessary widget tree repaints.

### 3. Local Quantified-Self & Correlation Engine
- **Deterministic Math Analytics**: Zero external API calls. Computes true statistical indicators entirely on CPU.
- **Pearson Correlation Probe**: Analyzes paired time-series entries across categories (e.g. sleep duration vs. subjective mood rating) with a strict minimum paired sample guard ($N \ge 5$).
- **Multi-Category Tracking**: Food, water, health, study, fitness, sleep, mood, skin/hair, personal finance, and freeform logs.
- **Asymmetric Rollover Engine**: Standard categories reset at `00:00`, while sleep logs roll over at `04:00` to preserve cross-midnight cycles.
- **Streak & Momentum Tracking**: Evaluates overall active days, individual habit streaks, at-risk warnings, and target milestones.

### 4. Privacy & System Security
- **Biometric Authentication Gate**: Integrated via `local_auth` using Android BiometricPrompt (fingerprint and face unlock) with graceful fallback for devices without biometric hardware.
- **Adaptive Local Notifications**: Uses `flutter_local_notifications` with `zonedSchedule` and exact alarm fallback (`SCHEDULE_EXACT_ALARM`) for automated morning and evening ledger nudges.
- **Structured Batch Parser**: Ingests structured JSON datasets offline with validation and schema mapping.

---

## Schema Architecture

```
+------------------+       +------------------+       +------------------+
|     Entries      |       |      Habits      |       |   HabitChecks    |
+------------------+       +------------------+       +------------------+
| id (PK AutoInc)  |       | id (PK AutoInc)  |       | id (PK AutoInc)  |
| category (TEXT)  |       | name (TEXT Unique|       | habitId (FK)     |
| note (TEXT)      |       +------------------+       | date (TEXT YMD)  |
| emoji (TEXT)     |                |                 +------------------+
| rating (INT 1-5) |                |                          |
| amount (REAL)    |                +--------------------------+
| unit (TEXT)      |
| loggedAt (INT)   |       +------------------+       +------------------+
| createdAt (INT)  |       |    DailyNotes    |       |     Settings     |
+------------------+       +------------------+       +------------------+
                           | id (PK AutoInc)  |       | Key-Value store  |
                           | date (TEXT Unique|       | via SharedPreferences
                           | note (TEXT)      |       +------------------+
                           +------------------+
```

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.12.2`
- Android SDK 36 (Android 16 readiness)
- Java 17+ with core library desugaring support

### Build & Run

1. Clone repository:
   ```bash
   git clone https://github.com/AkashPriyadarshii/imperium.git
   cd imperium
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate Drift SQLite code:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Execute local test suite:
   ```bash
   flutter test
   ```

5. Build optimized release APK (arm64-v8a):
   ```bash
   flutter build apk --release --target-platform android-arm64
   ```

---

## Repository Documentation

- `ARCHITECTURE.md`: Data flow, database isolate design, and statistical algorithms.
- `DESIGN.md`: Visual tokens, typographic scale, and motion constraints.
- `PRD.md`: Feature specifications and functional requirements.
- `SECURITY.md`: Offline data boundary and local threat model.
- `PLAN.md`: Roadmap and milestone definitions.

---

## Author

**Akash Priyadarshi**
- **GitHub**: [@AkashPriyadarshii](https://github.com/AkashPriyadarshii)
- **Portfolio**: [akashpriyadarshi.vercel.app](https://akashpriyadarshi.vercel.app)
- **Resume**: [akashpriyadarshii.github.io/Resume](https://akashpriyadarshii.github.io/Resume/)
- **X / Twitter**: [@Akash__ydv001](https://twitter.com/Akash__ydv001)
- **LinkedIn**: [akash-priyadarshi](https://linkedin.com/in/akash-priyadarshi-1aa51b37a)

---

## License

Proprietary. All rights reserved. See `LICENSE`.
