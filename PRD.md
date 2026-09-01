# imperium — Product Requirements (v0.1)

**Proprietary · private repo · single user: Akash.**
A personal "my everything" life-tracker for Android. 100% offline, no auth, no cloud, no server. Every byte of data stays on the device.

## Problem
Existing trackers force a category, need an account, or upload data. imperium refuses nothing, never calls home, and is fast enough that logging becomes a reflex.

## Goals for v0.1
- Capture anything, fast: 9 categories + a freeform catch-all (nothing is refused).
- Command-able daily dashboard: one glance reads what's done vs pending.
- Real offline insight: math-based (correlation, streaks, trends), not fake AI.
- Dishonest AI = never: no fake "intelligence," no overstated claims.

## Non-goals (v0.1)
- No photos, no cloud sync, no account, no web, no iOS.
- No on-device LLM; no natural-language persona parsing (needs a model — v0.2).
- No custom categories, no custom reminders, no home widgets, no charts beyond basic stats.

## Users & roles
Single user, single mode. Onboarding asks name + habits once; everything is editable in Settings.

## Features

### 1. Capture
- Categories: food, water, health, study, fitness, sleep, mood, skin-hair, finance + **freeform** catch-all.
- Entry fields: category (any), text (only required), optional emoji, rating 1-5, amount + unit.
- Per-category amount units so stats sum correctly: water=ml, finance=INR, study=hours, fitness=reps/weight, food=portion.
- **Backfill**: log at any past timestamp, not just now.
- **Edit / delete** on every entry. Delete is reversible understanding (confirm).
- **One-tap Repeat**: re-add last entry to a chosen day.

### 2. Dashboard (home)
- Date + streak in Cinzel; quote-of-day as the monument.
- TODAY'S DISCIPLINE ledger: gold dot done / hollow ring pending / half partial.
- Scoreboard strip: sleep avg, spend total, streak.
- Habit check row (tap to mark). Big +FAB.

### 3. Stats
- This-month auto-summary (rule-based text).
- By-category totals, per-category 7/30-day means + deltas + trend direction.
- **Correlation probe**: user picks 2 categories; Pearson r over last 14-30 days of paired logs; plain-text readout. **Min-N=5 guard** (no noise).
- Streak math: best / at-risk / to-tie.
- Global search across all entries.

### 4. Automation
- Recurring pending templates (e.g. gym Mon/Wed/Fri) → hollow gold-dot; one tap materializes. Confirm-required, never fakes data.
- Weekly-target rules ("read 5x/week") with on-pace projection.

### 5. Batch entry
- Json envelope import: paste an LLM's structured output; app validates schema, maps to categories, one-tap review-confirm, writes rows.
- 3 bundled templates ("workout", "morning routine", "meeting log"). Labeled batch entry, never "persona" (overpromises).

### 6. Reminders
- 2 daily nudges (afternoon, 20:00) via flutter_local_notifications.
- Adaptive exact→inexact via canScheduleExactAlarms(); manifest receivers; zonedSchedule + matchDateTimeComponents.time. Respects already-logged state. Tappable → opens log.

### 7. Settings
- Name, habits, reminders (time + permission), biometric lock, theme, data (export/import/backup/**armored reset**), templates, about.
- Export/import JSON (merge-by-id, no dupes). Reset-only-after-auto-backup.

## Onboarding
Welcome → name → pick habits → reminders toggle → biometric (best-effort, skip if no sensor) → empty ledger. Under 60 seconds. Never repeats.

## Success metrics (v0.1)
- Log ≤ 5 taps for 80% of entries; 1 tap with Repeat.
- Zero data loss on export/import.
- No jank at 120Hz on dashboard/ledger/log/settings interactions.

## Risks
- OEM battery-kill of notifications (real-device testing only).
- Correlation noise (mitigated by min-N=5).
- Scope creep into AI features (parked at v0.2).

## v0.2 (6 months out)
Photos, on-device AI (food-icon classifier, NL persona parsing, narrative reports), custom categories/reminders, home widgets, heatmap charts, cloud backup (optional/private), multi-factor insights.
