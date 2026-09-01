# imperium

A private, offline-first "my everything" life-tracker for Android. Food, water, health, study, fitness, sleep, mood, skin-hair, finance, habits — plus a freeform lane that refuses nothing.

**Private · proprietary · single user (Akash).** All data stays on this device. No account, no cloud, no server, no telemetry.

## Why
Trackers force a category, demand an account, or upload your life. imperium captures anything fast, shows one commanding daily ledger, and draws honest offline insight from math — not fake AI.

## Features (v0.1)
- **Capture anything** — 9 categories + freeform. Only one field required (the note). Optional emoji, rating, amount. Backfill to any past time. Edit / delete / one-tap Repeat.
- **Dashboard** — imperial ledger: gold dot = done, hollow ring = pending. Quote of the day. Streak. Scoreboard.
- **Stats** — month auto-summary, by-category totals, **correlation probe** (e.g. sleep vs mood, min-N=5 guard), streak math, trends, global search.
- **Automation** — recurring pending templates (gym Mon/Wed/Fri), weekly targets.
- **Batch entry** — paste an LLM's structured JSON, validate, review, one-tap import.
- **Reminders** — afternoon + 8pm nudges, adaptive to your device.
- **Biometric lock** — optional, best-effort.
- **Armored reset** — staged, typed-word confirm, auto-backup before wipe.

## Build
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --split-per-abi
```
Requires Flutter + Android SDK; targets Android 16 (SDK 36), armv8a.

## Docs
- `PRD.md` — product requirements
- `DESIGN.md` — design system (single source of truth)
- `ARCHITECTURE.md` — structure, data model, insight engine
- `PLAN.md` — build plan + status
- `SECURITY.md` — offline threat model, armored protections

## License
Proprietary. All rights reserved. See `LICENSE`.
