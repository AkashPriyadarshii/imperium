# AGENTS.md — imperium

Anything here prepends to every agent/IDE prompt working in this repo.

## Project boundary
Offline-first Android life-tracker (Flutter/Dart, Drift SQLite). **No server, no cloud, no auth, no network.** Proprietary license, private repo.

## Hard rules
1. **Never wire network/cloud/keys.** Data is local-only, forever. A feature that needs an API or account is out unless explicitly green-lit.
2. **No fake AI.** Insight = rule/math-only (Pearson correlation, streak math, trends). Never simulate understanding. A "persona parser" is a JSON validator + mapper, never prose parsing.
3. **Armored reset only.** Reset-all: warning → typed word → auto-backup → wipe. Never a one-tap wipe.
4. **Respect DESIGN.md.** Gold is scarce der; ivory = reading type; Cinzel (monument) + Archivo (ledger); one accent hue. No re-skinning, no generic slop (no default-consistency bg, no centered purple gradients, no hero+cards+footer).
5. **Biometric is best-effort.** No sensor → skip silently, never brick the device.
6. **Notif alarms adaptive.** exact → inexact fallback via canScheduleExactAlarms(); never depend on the app process surviving.

## Standards
- Follow CLAUDE.md. Full `flutter test` locally, never CI-only.
- Immutability, small files (<800 lines), early returns, no magic numbers.
- Bind user-trust: a wrong fact or stale number is worse than not answering.
- Anti-slop prose for shipped deliverables.

## Delegation contract
If a subagent is spawned, its final message IS the deliverable — collect results before ending a turn. No fire-and-forget.

## Secrets
None exist by design (offline, no keys). If one ever appears, it goes in an env var, never source.
