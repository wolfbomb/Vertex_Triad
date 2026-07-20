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
| Current phase | **0 — Scaffold** |
| Status | 🔲 Not started |
| Live capital | ❌ NO — demo only |

**Status legend:** 🔲 Not started · 🔨 In progress · 🔍 In verification · ✅ Complete · ⛔ Blocked · ⚠️ Complete with caveats

---

## Phase status

| # | Phase | Status | Started | Completed | Commit | Notes |
|---|---|:---:|---|---|---|---|
| 0 | Scaffold | 🔲 | | | | |
| 1 | SwingDetector + FibZone | 🔲 | | | | |
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
| `VERTEX_Triad.mq5` | 🔲 | 0 | | | |
| `SwingDetector.mqh` | 🔲 | 1 | | | |
| `FibZone.mqh` | 🔲 | 1 | | | |
| `VolumeProfile.mqh` | 🔲 | 2 | | | |
| `EngulfDetector.mqh` | 🔲 | 3 | | | |
| `ConfluenceScorer.mqh` | 🔲 | 4 | | | |
| `RiskManager.mqh` | 🔲 | 5 | | | |
| `TradeExecutor.mqh` | 🔲 | 5 | | | |
| `PositionManager.mqh` | 🔲 | 6 | | | |
| `Journal.mqh` | 🔲 | 4 | | | |
| `Visualizer.mqh` | 🔲 | 1 | | | |
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

### _(no sessions yet)_

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
