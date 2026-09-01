# imperium — Build Plan (v0.1)

**Status: BUILDING. Ordered so each step leaves a runnable app.**

## Phase 1 — Skeleton (docs + scaffold)
- [x] Hybrid DESIGN.md (written; old specs deleted)
- [ ] PRD / ARCHITECTURE / CLAUDE / README / AGENTS / SECURITY / CONTRIBUTING / LICENSE (this pass)
- [ ] `flutter create` scaffold; Impeller on; deps in; fonts bundled
- **Done when:** `flutter build apk --debug` compiles.

## Phase 2 — Data + theme
- [ ] Drift schema (Entry, Habit, HabitCheck, DailyNote) + DAOs; seed categories/units
- [ ] Imperial theme tokens (dark+light), type, spacing
- **Done when:** DB round-trip verified in a self-check.

## Phase 3 — Core screens
- [ ] Dashboard: date+streak, quote, ledger (dots), scoreboard, habit row, FAB
- [ ] Log: category → text → optional fields; backfill; Repeat; edit/delete
- [ ] Settings: name, habits, reminders, biometric, theme, data (export/import/**armored reset**), templates
- **Done when:** log → appears on dashboard → edit → delete round-trip works.

## Phase 4 — Stats + automation + batch
- [ ] Stats: month summary, by-cat totals, correlation probe (min-N=5), streak math, trends, search
- [ ] Automation: recurring pending templates, weekly targets
- [ ] Batch: JSON envelope import + validation/mapping + 3 templates
- **Done when:** correlation probe returns a readout on seed data; batch import writes rows.

## Phase 5 — Notifications + biometrics + onboarding
- [ ] 2 daily nudges, adaptive exact/inexact, manifest receivers, tap→log
- [ ] Biometric gate (best-effort), onboarding flow
- **Done when:** builds; needs real-device test for alarms + biometric.

## Phase 6 — Release
- [ ] `flutter build apk --release --split-per-abi` (armv8a)
- [ ] Install on Akash's Android 16 device; verify log→dashboard→export→import; device-test alarms + biometric
- [ ] Private repo push after explicit "go"

## Out of scope (v0.2, 6 months)
Photos, on-device AI, custom categories/reminders, widgets, heatmap, cloud backup, multi-factor insights.
