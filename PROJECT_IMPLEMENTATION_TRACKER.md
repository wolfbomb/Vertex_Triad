# PROJECT_IMPLEMENTATION_TRACKER.md — VERTEX_Triad

**Living document.** Update at the end of every working session, not retroactively. If a session ends without a tracker update, the next session starts blind.

---

## Project header

| Field | Value |
|---|---|
| Project | VERTEX_Triad |
| Owner | Nimrod |
| Started | _TBD_ |
| Magic number | `2026072001` _(confirm at Phase 0)_ |
| Platform | MQL5 / MetaTrader 5 |
| Symbols | XAUUSD, BTCUSD |
| Brokers | VT Markets, Pepperstone Razor ECN |
| Repo | _TBD_ |
| Current phase | **1 — SwingDetector + FibZone** |
| Status | 🔨 In progress |
| Live capital | ❌ NO — demo only |

**Status legend:** 🔲 Not started · 🔨 In progress · 🔍 In verification · ✅ Complete · ⛔ Blocked · ⚠️ Complete with caveats

---

## Phase status

| # | Phase | Status | Started | Completed | Commit | Notes |
|---|---|:---:|---|---|---|---|
| 0 | Scaffold | 🔲 | | | | |
| 1 | SwingDetector + FibZone | ⚠️ | 2026-07-21 | 2026-07-22 | _pending_ | Complete with caveats — see session log. Math verified at scale; visual native-tool gate only 1/5 legs done; full-retrace path likely unreachable |
| 2 | VolumeProfile | 🔲 | | | | TradingView cross-check is the gate |
| 3 | EngulfDetector | 🔲 | | | | |
| 4 | ConfluenceScorer | 🔲 | | | | |
| 5 | RiskManager + TradeExecutor | 🔲 | | | | 5 forced-fail gate tests |
| 6 | PositionManager | 🔲 | | | | |
| 7 | Notifier + Dashboard | 🔲 | | | | |
| 8 | Telegram | 🔲 | | | | Whitelist step is manual |
| 9 | Backtest + Optimization | 🔲 | | | | Ablation controls mandatory |
| 10 | Demo Forward Test | 🔲 | | | | 30 days minimum |
| — | Pre-live gate | 🔲 | | | | Separate decision |

---

## Module status

| Module | Status | Phase | LOC | Last touched | Notes |
|---|:---:|:---:|---:|---|---|
| `VERTEX_Triad.mq5` | ⚠️ | 1 | | 2026-07-22 | Phase 1 wiring added in OnTick; invalidated-leg exclusion state added |
| `SwingDetector.mqh` | ⚠️ | 1 | | 2026-07-22 | Fractal swings + leg qualification filters implemented; invalidated-leg exclusion added (single-slot memory) |
| `FibZone.mqh` | ⚠️ | 1 | | 2026-07-21 | Zone build + invalidation checks implemented; full-retrace path likely unreachable given check ordering (see open issues) |
| `VolumeProfile.mqh` | 🔲 | 2 | | | |
| `EngulfDetector.mqh` | 🔲 | 3 | | | |
| `ConfluenceScorer.mqh` | 🔲 | 4 | | | |
| `RiskManager.mqh` | 🔲 | 5 | | | |
| `TradeExecutor.mqh` | 🔲 | 5 | | | |
| `PositionManager.mqh` | 🔲 | 6 | | | |
| `Journal.mqh` | 🔲 | 4 | | | |
| `Visualizer.mqh` | ✅ | 1 | | 2026-07-21 | Prefix-scoped phase-1 fib visualization implemented; OnDeinit cleanup confirmed prefix-scoped only |
| `Notifier.mqh` | 🔲 | 7 | | | Router — no direct coupling |
| `Dashboard.mqh` | 🔲 | 7 | | | |
| `Telegram.mqh` | 🔲 | 8 | | | |

---

## Session log

Newest first. One entry per working session.

### Template
```
### YYYY-MM-DD — Phase N
**Goal:** what this session set out to do
**Done:** what actually shipped
**Evidence:** what was verified and how
**Blocked / open:** what stopped or remains
**Next:** the single next action
**Commit:** hash
```

---

### 2026-07-21 — Phase 1
**Goal:** begin Phase 1 implementation of swing detection and Golden Zone logic.
**Done:** implemented fractal swing scan, leg qualification filters (size/momentum/recency/cleanliness), fib zone construction, invalidation checks, and phase-1 chart visualization; wired flow into main EA new-bar path.
**Evidence:** code-level implementation completed and tracker updated; compile/test evidence not yet captured in docs/phase1.
**Blocked / open:** Manual chart validation (5 legs, >=2 bearish visual comparison vs MT5 Fib tool) still pending — requires MetaTrader 5 chart session.
**Next:** attach EA to XAUUSD M15 in VT Markets MT5, screenshot Experts tab log + 5 zone comparisons, save to docs/phase1.
**Commit:** _pending until checklist verified_

### 2026-07-21 — Phase 1 continued (compile fix)
**Goal:** achieve zero-error, zero-warning compile on VT Markets MetaEditor64.
**Done:** diagnosed MQL5 vs MQL4 array scoping difference (High[]/Low[] etc. are not global in MQL5); rewrote SwingDetector, FibZone, Visualizer to accept price arrays as const-ref parameters; added G_CopyPriceSeries() in EA to copy and pass series arrays on each new bar; fixed version string warning; recompiled — **Result: 0 errors, 0 warnings, 444 ms**.
**Evidence:** `docs/phase1/compile_readable.txt` — final line confirms 0 errors 0 warnings.
**Blocked / open:** manual chart validation still needed.
**Next:** attach to XAUUSD M15 in VT Markets MT5 visual mode.
**Commit:** _pending_

### 2026-07-21 — Phase 1 continued (automated zone math gate)

**Goal:** generate and verify Phase 1 zone math against an independent recomputation, per SPEC §2.2.
**Done:** ran a headless Strategy Tester pass (`VERTEX_Triad`, `XAUUSD-VIP`, M15, 2025.10.01–2025.12.31, Model=Every tick based on real ticks, `MaxLegAgeBars=150`) via `terminal64.exe /config`. EA wrote `phase1_zones.csv` (5345 rows / 85 distinct legs: 56 bullish, 29 bearish). Ran `tests/verify_phase1_zones.py` against it — fixed a bug in the script (a `✓` character crashed with `UnicodeEncodeError` under Windows cp1252 console, turning a real PASS into a false exit-code failure). Re-ran clean.
**Evidence:** `docs/phase1/phase1_zones.csv` (raw tester output), `docs/phase1/phase1_zones_verification.txt` — **5345/5345 rows PASS, 0 FAIL, exit code 0**.
**Blocked / open:** This confirms the fib050/0618/zoneUpper/zoneLower/invalidationLevel arithmetic is internally self-consistent — it does **not** replace the required manual comparison against MT5's native Fib tool (SPEC's actual Phase 1 gate), which checks that swing detection picks the _right_ legs, not just that the math on a chosen leg is correct. That step still needs a human on the visual-mode tester or a live chart.
**Next:** in MT5 visual-mode Strategy Tester or a live XAUUSD-VIP M15 chart, draw the native Fib retracement tool over 5 of these legs (≥2 bearish) and compare 0.5/0.618 levels against the EA's zone. Good bearish candidates from this run: leg ending 2025.10.21 17:45 (high 4272.44 / low 4081.64) and leg ending 2025.10.14 16:00 (high 4144.27 / low 4097.78). Bullish candidates: 2025.10.06 08:00 (high 3945.06 / low 3882.89), 2025.10.08 08:30 (high 4037.03 / low 3984.42), 2025.10.01 11:15 (high 3895.26 / low 3853.33).
**Commit:** _pending until manual visual gate also passes_

### 2026-07-22 — Phase 1 closeout (invalidation-churn fix + partial visual gate)

**Goal:** fix a design gap found while doing the manual visual comparison, and complete as much of the 5-leg native-tool gate as practical.
**Done:**

1. Found via live visual-mode walkthrough that an invalidated leg was silently re-qualifying every bar (same dead swing accept→invalidate loop for hours), because `Swing_FindLatestQualifiedLeg` had no memory of what it just killed. Fixed: added `startBarTime` to `SwingImpulseLeg`, threaded an exclusion identity (direction + start/end time) through `Swing_QualifyLeg`/`Swing_FindLatestQualifiedLeg`, and the EA now remembers the most recently invalidated leg and excludes it from re-qualification. User approved this direction explicitly (option: "Bar the invalidated leg"). Single-slot memory only — matches existing single-active-leg architecture, does not track a full invalidation history.
2. Recompiled clean: **0 errors, 0 warnings** (`docs/phase1/compile_readable.txt`, `docs/phase1/compile.log`).
3. Manual native-tool comparison: walked through MT5's Fibonacci Retracement tool live with the user (mobile/remote session, no GUI automation reliable — see below). Confirmed **1 bullish leg exact match** (high=3945.06/low=3882.89 → fib050=3913.975, fib0618=3906.63894, both matching the EA log to 5 decimal places), including working out that MT5 anchors 0%/100% by time-order (not high/low), so the EA's `fib0618` always maps to MT5's `38.2` level, not `61.8`, when the leg follows natural chronological order (low-before-high for bullish, high-before-low for bearish, verified algebraically both ways).
4. Pulled 2 bearish leg candidates with full computed values from the CSV evidence for future use: leg 2025.10.14 16:00 (high 4144.27/low 4097.78 → fib050=4121.025, fib0618=4126.51082) and leg 2025.09.30 12:45 (high 3871.62/low 3793.14 → fib050=3832.38, fib0618=3841.64064).

**Evidence:** `docs/phase1/phase1_zones.csv`, `docs/phase1/phase1_zones_verification.txt` (5345/5345 automated math pass, unchanged), `docs/phase1/compile_readable.txt` (post-fix recompile), this log entry (native-tool cross-check numbers).

**Blocked / open — real gaps, not swept under the rug:**

- **Only 1 of the required 5 legs got the actual native-Fib-tool visual comparison** (CHECKLIST.md Phase 1 requires ≥5, including ≥2 bearish). The 2 bearish candidates above have verified math but were never actually drawn/compared on-chart — GUI automation attempts to drive this remotely caused a real incident (see below) and were abandoned.
- **GUI automation incident:** while attempting to drive MT5 via simulated window-focus/clicks (user was on a mobile remote session and couldn't interact directly), a stale/misdirected window focus call landed on the user's separate Claude desktop app instead of MT5, and a prompt ("explain Elliott Wave Theory...") got submitted there, which then created and attempted to compile an unrelated `ELLIOT~1.MQ5` file (8 compile errors, later fixed by the user/other session to 0 errors). Confirmed **zero impact on VERTEX_Triad** — different terminal data folder, different EA, untouched repo. Automation was stopped once this was discovered. **Lesson: do not attempt simulated mouse/window automation on this machine again without a much more reliable window-targeting method than `SetForegroundWindow`/coordinate clicks** — focus silently resolved to the wrong top-level window more than once.
- **Invalidation path coverage is incomplete.** Grepped all available tester/agent logs: `0.786 breach` fires constantly (3164+ occurrences), but **`full retrace` and `age expiry` have never fired, in any run.** Root cause for full-retrace: `Fib_CheckInvalidation` checks 0.786 breach first and returns immediately — since the 0.786 level always sits between legHigh and legLow (closer to legLow), price cannot reach `legLow` (full retrace) without already having breached 0.786 on an earlier bar. **This makes the full-retrace check likely unreachable dead code as currently ordered**, not just untested. Age-expiry not firing is more benign (legs get invalidated or superseded well before 50–150 bars). Not fixed — flagged for a decision, since changing gate/invalidation behavior needs explicit sign-off per CLAUDE.md.

**Next:** (a) decide whether to restructure `Fib_CheckInvalidation`'s check order/logic so full-retrace is actually reachable, or accept 0.786-breach as the practical invalidation trigger and drop/relabel the full-retrace check; (b) finish the remaining 4 legs of the native-tool visual gate next time a normal (non-mobile) session is available; (c) then commit Phase 1.
**Commit:** _pending — see open items above_

---

## Open issues

| # | Raised | Severity | Issue | Owner | Status |
| --- | --- | :---: | --- | --- | :---: |
| 1 | 2026-07-22 | 🟡 | `Fib_CheckInvalidation`'s full-retrace path appears unreachable — 0.786 breach always fires first given check ordering and thresholds. Zero occurrences in any test run. | Nimrod | Open |
| 2 | 2026-07-22 | 🔵 | Phase 1's 5-leg native-Fib-tool visual gate only 1/5 complete (1 bullish exact match). 2 bearish + 2 bullish candidates identified with verified math, not yet drawn/compared on-chart. | Nimrod | Open |

**Severity:** 🔴 Blocker · 🟡 Needs decision · 🔵 Nice to have

---

## Decision log

Record decisions that deviate from SPEC, or resolve ambiguity in it. Include the reasoning — future-you will not remember why.

| Date | Decision | Rationale | SPEC impact |
|---|---|---|---|
| | | | |

---

## Parameter change log

Any default changed from SPEC §8 / §9.6 / §10.6. Undocumented parameter drift is how strategies quietly stop being the strategy that was tested.

| Date | Parameter | From | To | Reason | Re-tested? |
|---|---|---|---|---|:---:|
| | | | | | |

---

## Validation evidence index

Where the proof lives for each phase gate.

| Phase | Evidence required | Location | Verified |
|---|---|---|:---:|
| 1 | Fib zone vs. manual tool, 5 legs (2 bearish) | `docs/phase1/` | ⚠️ 1/5 (see open issue #2) |
| 1 | Zone math independent recomputation, all legs | `docs/phase1/phase1_zones_verification.txt` | ✅ 5345/5345 |
| 2 | EA profile vs. TradingView side-by-side | `docs/phase2/` | 🔲 |
| 2 | Recompute call-count log | `docs/phase2/` | 🔲 |
| 3 | 100-bar annotated pattern review | `docs/phase3/` | 🔲 |
| 4 | 10-sample manual score recomputation | `docs/phase4/` | 🔲 |
| 5 | Five forced-fail gate logs | `docs/phase5/` | 🔲 |
| 5 | Lot sizing hand-check, both symbols | `docs/phase5/` | 🔲 |
| 6 | Visual-mode 10-trade management | `docs/phase6/` | 🔲 |
| 7 | Panel states + tester speed delta | `docs/phase7/` | 🔲 |
| 8 | Network-disabled execution test | `docs/phase8/` | 🔲 |
| 9 | Full tester reports incl. ablations | `docs/phase9/` | 🔲 |
| 10 | 30-day journal + live vs. backtest | `docs/phase10/` | 🔲 |

---

## Backtest results

Record every run. Do not delete unfavourable ones — the pattern across runs is the information.

| Date | Symbol | Period | Model | Trades | PF | Net R | Max DD% | Expectancy | Notes |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| | | | | | | | | | |

**Model** must state `RealTicks` or the run is not valid evidence.

### Ablation comparison

The honest test of the three-pillar premise. Fill this before Phase 9 closes.

| Configuration | Trades | PF | Net R | Max DD% | Expectancy |
|---|---:|---:|---:|---:|---:|
| All three pillars | | | | | |
| Pillar 2 disabled (no Volume Profile) | | | | | |
| Pillar 3 disabled (no Engulfing) | | | | | |
| Fib only | | | | | |

**If the three-pillar configuration does not beat both ablations, record that finding here plainly.** It is a legitimate result, not a tuning problem. Complexity that does not earn its keep should be removed, not optimized around.

---

## Sensitivity sweep

| Parameter | Baseline | −20% result | +20% result | Stable? |
|---|---|---|---|:---:|
| `MinConfluenceScore` | 85 | | | |
| `HVNThreshold` | 0.70 | | | |
| `MinEngulfBodyRatio` | 1.10 | | | |

Collapse under small perturbation indicates curve-fitting rather than edge.

---

## Demo forward test

| Field | Value |
|---|---|
| Start date | |
| End date | |
| Broker(s) | |
| Trades taken | |
| Net R | |
| Expectancy | |
| Max DD% | |
| Backtest expectancy | |
| **Divergence** | |
| Divergence explained? | |
| Object/memory leak observed? | |
| Unhandled errors? | |

---

## Known caveats carried forward

Things true about this build that must not be forgotten when reading its results.

- Tick volume is used as a proxy for real traded volume on FX/CFD symbols. Pillar 2 measures participation approximately, not exchange volume.
- Telegram domain whitelisting is a manual per-terminal step and does not travel with the code.
- Invalidated-leg exclusion (SwingDetector) remembers only the single most-recently-invalidated leg, not a full history. An older leg invalidated before the current one became active could theoretically re-qualify. Matches the existing single-active-leg architecture; would need a real design change (not just a bug fix) to track more.
- `Fib_CheckInvalidation`'s full-retrace path has never fired in any test run and is likely unreachable given current check ordering (0.786 breach always fires first) — see Open issue #1.
- Backtest performance is not a prediction of live performance. The demo forward test is the real gate.
- _(add as discovered)_

---

## Live deployment

⛔ **Not authorized.** Requires the pre-live gate in `CHECKLIST.md` plus explicit sign-off.

| Field | Value |
|---|---|
| Authorized by | — |
| Date | — |
| Starting risk % | — |
| Kill procedure tested | ❌ |
