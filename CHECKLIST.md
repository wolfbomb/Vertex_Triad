# CHECKLIST.md — VERTEX_Triad

Phase gates. Each item is verified with **stated evidence**, not asserted. "Compiles" is not evidence that logic is correct.

A phase is complete only when every item passes. On all-pass: `git add -A && git commit -m "Phase N: <summary>" && git push`, then **stop and report**. Do not begin the next phase unprompted.

If an item fails, fix it and re-verify the whole phase — not just the failed item. Fixes cause regressions.

---

## Universal gates (apply to every phase)

- [ ] Compiles with **zero errors and zero warnings**
- [ ] No `AUTO_TRADING_ENABLED` default changed from `false`
- [ ] No forming-bar evaluation introduced anywhere
- [ ] All position queries filter by magic number
- [ ] No hardcoded credentials, tokens, or account numbers
- [ ] No bare numeric literals in conditional logic — named `input` or `const`
- [ ] All `ArraySize()` checked before indexing
- [ ] No double comparison with `==`
- [ ] SPEC section cited in code comments for non-obvious logic
- [ ] Git committed and pushed

---

## Phase 0 — Scaffold

- [ ] Repo initialized; `.gitignore` excludes `journal/`, `*.ex5`, config with secrets
- [ ] `SPEC.md`, `CLAUDE.md`, `CHECKLIST.md`, `PROJECT_IMPLEMENTATION_TRACKER.md` present
- [ ] Empty `VERTEX_Triad.mq5` compiles with `OnInit`/`OnTick`/`OnDeinit`/`OnTimer`/`OnChartEvent`/`OnTradeTransaction` stubs
- [ ] `Include/Triad/` created with empty `.mqh` files per SPEC §11
- [ ] Magic number assigned and recorded in tracker
- [ ] EA attaches to a chart without error; removes cleanly

**Evidence required:** compile log, screenshot of attach/detach with clean Experts tab.

---

## Phase 1 — SwingDetector + FibZone

- [ ] Fractal swing detection returns correct highs/lows for `SwingLookback = 5`
- [ ] Leg qualification applies all four filters (size, momentum, recency, cleanliness)
- [ ] Legs failing any filter are rejected, with reason logged
- [ ] Golden Zone boundaries computed correctly for **both** bullish and bearish legs
- [ ] Zone invalidates at 0.786 breach, full retrace, and age expiry — all three tested
- [ ] Zone drawn on chart matches manual MT5 Fibonacci tool **within 1 tick**, verified on ≥ 5 separate legs
- [ ] Bearish leg case verified separately — not assumed symmetric
- [ ] Objects cleaned up on `OnDeinit` with prefix-scoped deletion only

**Evidence required:** screenshots comparing EA zone vs. manual Fib tool on 5 legs, including at least 2 bearish. Log excerpt showing rejected legs with reasons.

---

## Phase 2 — VolumeProfile

- [ ] Bins constructed across `ProfileLookbackBars` at `ProfileRowCount` resolution
- [ ] Volume distributed **linearly across each bar's high–low range**, not assigned to close
- [ ] POC identified as max-volume bin
- [ ] Value Area expansion algorithm reaches `ValueAreaPercent` correctly; VAH/VAL sane
- [ ] HVN clusters merge contiguous qualifying bins
- [ ] LVN regions identified
- [ ] Overlap test between zone and POC/HVN returns correct ATR-normalized value
- [ ] LVN rejection rule fires when zone sits entirely in low-volume region
- [ ] **POC/VAH/VAL match a TradingView reference profile on the same range within one bin** — this is the critical validation
- [ ] Tick-volume-vs-real-volume caveat documented in code header and surfaced in journal
- [ ] Profile recomputes on new bar only — verified by instrumenting call count over 100 ticks

**Evidence required:** side-by-side screenshot of EA profile vs. TradingView on identical range. Call-count log proving no per-tick recompute.

---

## Phase 3 — EngulfDetector

- [ ] Bullish and bearish patterns detected per SPEC §4.1 rules
- [ ] All five body/range filters applied
- [ ] `RequireWickEngulf` toggle behaves correctly in both states
- [ ] Location requirement enforced — engulf must interact with zone
- [ ] `ZoneDwellBars` expiry works; stale setups do not fire
- [ ] Evaluated on **closed bars only** — verified by confirming no signal changes intrabar
- [ ] **Manual review of 100 consecutive bars: detected patterns match human reading, zero false positives**
- [ ] Long-wick fake engulfs correctly rejected by `MinBodyToRange`

**Evidence required:** annotated chart over 100 bars with EA detections marked; explicit count of true positives, false positives, misses.

---

## Phase 4 — ConfluenceScorer

- [ ] Score computed per SPEC §5 weighting table
- [ ] Mandatory components (Fib, Engulf) at zero correctly abort with score 0
- [ ] POC overlap scores 30, plain HVN scores 20 — not conflated
- [ ] HTF trend alignment check reads correct timeframe
- [ ] Body bonus applies only above 1.5× threshold
- [ ] `MinConfluenceScore` threshold blocks below-threshold setups
- [ ] **Score breakdown logged on every evaluation including rejections**
- [ ] Manual audit of 10 logged samples: score arithmetic correct in all 10

**Evidence required:** log excerpt of 200 bars' evaluations. Manual recomputation of 10 samples shown alongside EA output.

---

## Phase 5 — RiskManager + TradeExecutor

- [ ] Lot size correct from risk %, stop distance, tick value, contract size
- [ ] Lot normalized to `SYMBOL_VOLUME_STEP`; clamped to MIN/MAX
- [ ] Stop selection takes furthest of the three candidates (SPEC §6.2)
- [ ] `MaxStopATR` cap causes trade **skip**, never a tightened stop
- [ ] **Each of the five gates verified individually with a forced-fail test**
  - [ ] Gate 1: `AUTO_TRADING_ENABLED = false` blocks
  - [ ] Gate 2: artificial spread above `MaxSpreadPoints` blocks
  - [ ] Gate 3: score below threshold blocks
  - [ ] Gate 4: daily loss / consecutive loss / margin limits each block
  - [ ] Gate 5: sub-stops-level distance blocks
- [ ] Gates abort in order; first failure short-circuits the chain
- [ ] Every gate failure logged with gate number and specific reason
- [ ] `ORDER_FILLING_IOC` used; FOK fallback triggers on rejection
- [ ] `OrderSend` retcode checked and logged on every call
- [ ] Duplicate signal on same bar time cannot double-fire

**Evidence required:** five forced-fail test logs, one per gate. Lot sizing worked example verified by hand for both XAUUSD and BTCUSD.

---

## Phase 6 — PositionManager

- [ ] TP1 partial close executes at `PartialClosePercent`
- [ ] Stop moves to breakeven + buffer after TP1
- [ ] TP2 mode toggle (swing origin vs. R-multiple) both work
- [ ] Trailing activates only after TP1
- [ ] Trailing never moves stop against the position
- [ ] Positions from other magics untouched
- [ ] **Verified in Strategy Tester visual mode across ≥ 10 trades**

**Evidence required:** visual-mode recording or screenshots of 10 managed trades showing partial, BE move, and trail.

---

## Phase 7 — Notifier + Dashboard

- [ ] `Notifier.mqh` routes semantic events; **no trading module calls Dashboard or Telegram directly**
- [ ] Panel renders all five sections per SPEC §9.4
- [ ] Values update correctly and match Experts-tab log
- [ ] Drag works from title bar; body drag does nothing
- [ ] Position clamped — panel cannot be dragged fully off-screen
- [ ] `CHART_MOUSE_SCROLL` disabled during drag, **restored on drag end and on `OnDeinit`**
- [ ] Collapse/expand toggle works; state correct after both
- [ ] Position and collapse state **survive recompile and terminal restart**
- [ ] All objects prefixed `VTX_PNL_<magic>_`
- [ ] `OnDeinit` deletes only prefixed objects — **user's own chart drawings survive**
- [ ] Two EA instances on different charts do not collide
- [ ] Refresh throttled to `PanelRefreshMs`; one `ChartRedraw()` per cycle
- [ ] Panel skipped entirely in non-visual tester
- [ ] **No measurable tick-rate regression** — tester speed compared with `ShowPanel` on vs. off
- [ ] Colour coding correct for pass/warn/fail states

**Evidence required:** screenshots of expanded, collapsed, and dragged states. Before/after tester speed numbers. Confirmation that a manually drawn trendline survives EA removal.

---

## Phase 8 — Telegram

- [ ] Test message sent on `OnInit` when enabled
- [ ] **Error 4014 detected and logged with explicit whitelist instruction**
- [ ] Every notification category fires correctly and is independently toggleable
- [ ] HTML escaping applied to `&`, `<`, `>` — verified with a message containing all three
- [ ] Message queue is fixed-size; overflow drops oldest without crashing
- [ ] Dedupe suppresses identical messages within window
- [ ] Critical alerts bypass dedupe and flush immediately
- [ ] Retry with backoff, then drop and log locally
- [ ] **`WebRequest` never called inline with `OrderSend`** — verified by code inspection
- [ ] **Telegram failure proven not to affect execution**: disable network, confirm trades still open/close correctly
- [ ] Bot token never appears in logs, Experts tab, or committed files
- [ ] `TelegramInTester = false` suppresses messages during backtest
- [ ] Daily summary fires at `DailySummaryHour`
- [ ] Message formatting readable on a phone lock screen

**Evidence required:** screenshots of received messages for each major category. Network-disabled test log showing normal trade execution. `grep` of repo confirming no token present.

---

## Phase 9 — Backtest + Optimization

- [ ] **Every tick based on real ticks** — M1 OHLC results are not acceptable evidence
- [ ] ≥ 200 trades on XAUUSD; ≥ 200 on BTCUSD
- [ ] Walk-forward split 70/30, rolling — not single-period optimization
- [ ] Report includes: net profit, profit factor, max DD %, Sharpe, expectancy in R, win rate, avg R, longest losing streak, trade count
- [ ] **Sensitivity sweep** ±20% on `MinConfluenceScore`, `HVNThreshold`, `MinEngulfBodyRatio` — results do not collapse
- [ ] **Ablation controls run**: Pillar 2 disabled, Pillar 3 disabled
- [ ] Three-pillar version compared honestly against both ablations
- [ ] If three pillars do **not** beat two, this is reported plainly as a finding — not tuned away
- [ ] Out-of-sample numbers reported, not in-sample
- [ ] Spread and commission modelled realistically for both brokers

**Evidence required:** full tester reports for all runs including ablations. Sensitivity table. Explicit statement of out-of-sample expectancy.

---

## Phase 10 — Demo Forward Test

- [ ] Deployed to demo on both VT Markets and Pepperstone
- [ ] ≥ 30 calendar days continuous run
- [ ] Journal CSV reviewed; rejection reasons analysed
- [ ] Telegram feed reviewed for noise level — categories retuned if needed
- [ ] Trade count ≥ 2/month per symbol; if lower, threshold relaxed before adding complexity
- [ ] Live behaviour compared against backtest expectancy — divergence explained
- [ ] Panel stable over multi-day runs; no object leak, no memory growth
- [ ] No unhandled errors in Experts tab over the full period
- [ ] Broker execution differences documented

**Evidence required:** 30-day journal export, live vs. backtest comparison table, Experts tab error scan.

---

## Pre-live gate

Not a phase — a hard stop before any real capital.

- [ ] All phases 0–10 passed
- [ ] Demo results reviewed and accepted by Nimrod explicitly
- [ ] `RiskPercent` set conservatively for live (≤ demo setting)
- [ ] `MaxDailyLossPercent` and `MaxConsecutiveLosses` confirmed active
- [ ] Manual kill procedure documented and tested
- [ ] Backtest performance explicitly **not** treated as a live-performance prediction

Live deployment is a separate decision, made deliberately. Passing Phase 10 authorizes nothing on its own.
