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
| 1 | SwingDetector + FibZone | 🔨 | 2026-07-21 | | | Core detection + zone logic implemented; verification pending |
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
| `VERTEX_Triad.mq5` | 🔨 | 1 | | 2026-07-21 | Phase 1 wiring added in OnTick |
| `SwingDetector.mqh` | 🔨 | 1 | | 2026-07-21 | Fractal swings + leg qualification filters implemented |
| `FibZone.mqh` | 🔨 | 1 | | 2026-07-21 | Zone build + invalidation checks implemented |
| `VolumeProfile.mqh` | 🔲 | 2 | | | |
| `EngulfDetector.mqh` | 🔲 | 3 | | | |
| `ConfluenceScorer.mqh` | 🔲 | 4 | | | |
| `RiskManager.mqh` | 🔲 | 5 | | | |
| `TradeExecutor.mqh` | 🔲 | 5 | | | |
| `PositionManager.mqh` | 🔲 | 6 | | | |
| `Journal.mqh` | 🔲 | 4 | | | |
| `Visualizer.mqh` | 🔨 | 1 | | 2026-07-21 | Prefix-scoped phase-1 fib visualization implemented |
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

---

## Open issues

| # | Raised | Severity | Issue | Owner | Status |
|---|---|:---:|---|---|:---:|
| | | | | | |

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
| 1 | Fib zone vs. manual tool, 5 legs (2 bearish) | `docs/phase1/` | 🔲 |
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
