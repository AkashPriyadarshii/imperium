# imperium — Design System

**Hybrid spec.** Lane A (design-genius, imperial-ledger) supplied the soul; Lane B (independent, restraint) supplied the foundations. Built to a masculine-stoic, offline-first Android life-tracker. One rule over everything: **gold is scarce and semantic; ivory is reading type; nothing flashy moves.**

Version: v0.1 · Status: locked · License: proprietary

---

## North star

Black granite slab, one inlay of gold, engraved type. Spartan. The Roman-ness lives in the geometry and the type, never in decoration. One accent hue (gold) is the entire game; a second hue breaks it.

---

## Color tokens

One accent hue. Everything else is warm near-black + warm ivory. No pure black, no casino gold, no olive mud.

### Dark — home field

| Token | Hex | Use |
|---|---|---|
| bg base | `#141312` | app field (warm near-black, lifted off pure `#000`) |
| surface | `#1C1A18` | cards, ledgers, sheets |
| surface raised | `#232120` | pressed / active |
| hairline | `#2E2A24` | dividers, borders |
| brass / gold | `#C9A25F` | accent, status, streak, primary CTA — **scarce** |
| gold deep | `#8A6D1F` | hairline rules, border gold |
| ivory | `#EAE3D0` | headlines + body |
| muted | `#A79E88` | secondary text, timestamps |
| done surface | `#1A1710` | whispered fill behind a completed row |

### Light — parchment / capture field

| Token | Hex |
|---|---|
| bg | `#F1EBDF` |
| surface | `#FAF6EC` |
| ink | `#201B13` |
| body | `#3A3429` |
| muted | `#6E6652` |
| brass (accent) | `#8A6D1F` (deep — see rule) |
| hairline | `#D8CDB4` |

### Rules

1. **Gold is structural, ivory is reading type.** Never set body text in gold — it shimmers on black and contrast collapses. Gold is for numerals, wordmark, status dots, hairlines. Ivory for everything read.
2. **On light, gold drops to deep `#8A6D1F`.** Never bright gold on parchment — unreadable.
3. **Scarcity.** Gold appears where it means "done / today / milestone" and nowhere else. If it's wallpaper, it's wrong.
4. Elevation by lightness (`#141312` → `#1C1A18` → `#232120`), never shadow.

---

## Type scale

**Cinzel** (Roman inscription serif) for everything monumental. **Archivo** (geometric grotesque) for the ledger and UI. Both bundled as assets — offline, no runtime fetch. `tnum` (tabular numerals) on ALL data — columns align like a ledger.

| Role | Font | Spec |
|---|---|---|
| Wordmark | Cinzel, caps, +6% track | 20sp |
| Quote of the day | Cinzel | 28–32sp, lh 1.35 |
| Monument numeral (streak/score) | Cinzel | 48–64sp, brass |
| Section/domain labels | Archivo caps +8% | 10–11sp, uppercase, wide — the "engraved label" |
| Body / metric values | Archivo Reg/Med | 14–15sp |
| Small / timestamps | Archivo | 11–12sp, muted |
| Data-row numerals | Archivo `tnum` | ledger-aligned |

Engraved-label treatment (10–11sp uppercase wide-tracked) sells "inscription" with zero ornament. Body text is never all-caps.

---

## Spacing / geometry

- **4dp grid.** Everything on multiples of 4.
- **Concentric radius:** 12 outer, 12→4 nested (cards 12, buttons 8, chip/dot 4).
- **Buttons:** 8dp radius, height 48dp — **not** pill.
- **Targets:** 48dp minimum hit area.
- **1px hairlines** for rules/borders — no soft shadows anywhere.

---

## Signature mechanic: the golden ledger spine

The read-state of the whole app. A vertical list of domain rows; each carries a status dot:

- **Filled gold dot** = done today
- **Hollow ivory ring** = pending
- **Half / thin gold** = partial

The dashboard is this ledger: one glance reads the mass of lit gold (conquered) against open rings (pending). That mass-of-gold-vs-empty is the commanding signal.

- **Day complete** = a single slow "PERACTA" seal in brass at the column head (Latin: *completed*). Quiet gravitas, no confetti. Subject to reduced-motion.
- Ledger always renders within a `RepaintBoundary`; per-row dot fills repaint in isolation.

**Navigation: dashboard-first.**

---

## Screens

1. **Dashboard (home)** — date + streak in Cinzel, quote-of-day as the monument, TODAY'S DISCIPLINE ledger (gold dot / hollow ring / partial), scoreboard strip (sleep avg, spend total, streak), big +FAB.
2. **Log** — capture-first. Category → text (only required) → optional emoji/rating/amount. Backfill (any past time), one-tap **Repeat**. **Light-first** for readability on data entry.
3. **Stats** — month auto-summary (rule-based), by-category totals, **correlation probe** (Pearson, min-N=5 guard), streak math (best/at-risk/to-tie), per-category numbers/trends, global search.
4. **Automation** — recurring pending templates (confirm-required, never fakes data), weekly-target rules/nudges.
5. **Batch** — JSON envelope import + templates + validation/mapping. Sits beside Log in the top bar (not a 5th tab).
6. **Settings** — name, habits, reminders (times + permission), biometric lock, theme, data (export/import/backup/reset), templates, about. **Reset-all is armored**: warning → type `RESET` → final barrier → auto-backup before wipe.

---

## Motion / haptics

Nothing decorative moves. The budget is the premium signal.

- **Log-save (stamp):** gold dot fills, scale 1.0→1.08→1.0 overshoot (~250ms easeOutBack) + firm short tap haptic.
- **Streak increment:** Day-N numeral rise+fade swap, one-frame brass flash (~300ms).
- **Row → sub-log:** quiet crossfade (~200ms easeOut).
- **Day won:** one slow gold "PERACTA" pulse (~400ms) + deeper single thud haptic.
- **Reduced-motion** OS setting honored: kill non-essential transforms.
- Haptics: stamp = firm short click; day-won = deeper thud. Consistent.

---

## Perf target

120Hz display; **the bar is zero jank on interactions**, not raw fps. Build for it from the start: Impeller renderer on (Vulkan), `const` widgets, list virtualization (render only visible ledger rows), Drift DB off the main isolate, `RepaintBoundary` per led-per-row. A static ledger frame is cheap enough to hit the refresh ceiling; complex stat frames trade depth for smoothness.

---

## Avoid — the cheap-gym-app list

1. **Bad icons** — no Material default set, no emoji glyphs, no raster packs. One coherent 2px-stroke set in muted brass, or tracked-caps type.
2. **Red/black/barbed-wire cliches** — no crimson, skulls, stencil, RGB-gamer edge. One accent ever. Pending reads as hollow ivory/brass, never red.
3. **Cliché fonts** — military stencil, grunge, faux-blackletter, tribal, default Times. Cinzel is clean.
4. **Muddy/pure-black themes** — `#000` + 8%-gray is cheap. Warm near-black, stacked surfaces, ivory text.
5. **Over-decoration** — at most one motif (a bare laurel/eagle at 4–6% behind the quote), or nothing. No marble, no chrome `#FFD700`, no glossy coin. Gold is thin and matte: flat fills + 1px hairlines.
6. **Warlord copy** — "CRUSH THE DAY." Register is quiet confidence: "Mark it done," "Discipline." Stoic, not aggressive.

---

## Copy register

Quiet confidence. Verb-led. "Mark it done." "Discipline." Never shouted, never sycophantic. Error states state cause + fix, matter-of-fact.

---

*palette + type + ledger locked for v0.1. This file is the single source of truth for the build.*
