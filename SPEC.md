# VERTEX_Triad — Technical Specification

**EA name:** `VERTEX_Triad.mq5`
**Magic number:** `20260720xx` (YYMMDDNN — assign NN at build time, e.g. `2026072001`)
**Platform:** MQL5 / MetaTrader 5
**Targets:** XAUUSD, BTCUSD (VT Markets, Pepperstone Razor ECN)
**Strategy class:** Multi-factor confluence, pullback-continuation / reversal at value

---

## 1. Strategy Thesis

A trade is taken only when three independent forms of evidence agree. Each pillar answers one question:

| Pillar | Question | Instrument |
|---|---|---|
| 1. Fibonacci retracement | **WHERE** should I wait for price? | 0.5–0.618 Golden Zone of the last impulse leg |
| 2. Volume Profile | **WHY** does this level matter? | POC / HVN overlap = real participation |
| 3. Engulfing candle | **WHEN** do I execute? | Bullish/bearish engulf inside the zone |

No single pillar is tradeable alone. The EA must reject setups where any pillar is absent. This is the core design constraint — the whole point is refusing signals that individually look attractive.

---

## 2. Pillar 1 — Fibonacci Golden Zone (WHERE)

### 2.1 Impulse leg detection
An impulse leg is a directional swing that qualifies as "strong."

**Swing point identification (fractal method):**
- A swing high at bar `i` requires `High[i]` to exceed the highs of `SwingLookback` bars on both sides.
- Symmetric definition for swing low.
- `SwingLookback` default: `5`.

**Leg qualification filters** (all must pass):
| Filter | Rule | Default |
|---|---|---|
| Minimum size | `legRange >= MinLegATR * ATR(14)` | `2.0` |
| Momentum | ≥ `MinImpulseBodyRatio` of leg bars close in leg direction | `0.60` |
| Recency | Leg terminated within `MaxLegAgeBars` | `50` |
| Cleanliness | No opposing retrace > `MaxInternalRetrace` during the leg | `0.382` |

Store the qualified leg as `{legHigh, legLow, direction, endBarTime}`.

### 2.2 Zone construction
For a bullish leg (low → high):
```
fib050 = legHigh - 0.500 * (legHigh - legLow)
fib0618 = legHigh - 0.618 * (legHigh - legLow)
goldenZone = [fib0618, fib050]     // lower, upper
```
Mirror for bearish legs.

### 2.3 Invalidation
The leg and its zone are discarded when:
- Price closes beyond the 0.786 retracement (`FibInvalidation`, default `0.786`), or
- Price closes beyond `legLow` (bullish) / `legHigh` (bearish) — full retrace, or
- Leg age exceeds `MaxLegAgeBars`.

On invalidation, re-scan for a new qualified leg.

---

## 3. Pillar 2 — Volume Profile (WHY)

MT5 has no native volume profile, so it must be computed. Note that FX and most CFDs provide **tick volume**, not true traded volume; the profile is a proxy for participation, not exchange volume. This is acceptable for the strategy but should be documented in-code and surfaced in the journal.

### 3.1 Profile construction
```
Inputs:
  ProfileLookbackBars   default 200
  ProfileRowCount       default 100     // price bins
  ProfileTimeframe      default PERIOD_CURRENT
  UseRealVolumeIfAvailable  default true
```

Algorithm:
1. Determine `profileHigh` / `profileLow` across the lookback window.
2. Divide into `ProfileRowCount` equal-height bins; `binSize = (profileHigh - profileLow) / ProfileRowCount`.
3. For each bar, distribute its volume across the bins its high–low range spans. Use **linear distribution** (volume split proportionally across touched bins) rather than assigning all volume to the close — this materially changes POC location.
4. Accumulate into `binVolume[]`.

### 3.2 Derived levels
- **POC** — bin with maximum `binVolume`; POC price = bin midpoint.
- **Value Area (VA)** — expand outward from POC, repeatedly adding the higher-volume of the two adjacent bins, until cumulative volume ≥ `ValueAreaPercent` (default `70.0`). Yields `VAH` / `VAL`.
- **HVN** — any bin where `binVolume >= HVNThreshold * maxBinVolume` (default `0.70`). Merge contiguous qualifying bins into HVN clusters.
- **LVN** — any bin where `binVolume <= LVNThreshold * maxBinVolume` (default `0.25`). Used for stop placement and as a rejection filter.

### 3.3 Confluence test
Pillar 2 passes when the Golden Zone overlaps a POC or an HVN cluster:
```
overlap = (min(zoneUpper, nodeUpper) - max(zoneLower, nodeLower))
pass = overlap > 0 && overlap >= MinOverlapATR * ATR(14)
```
`MinOverlapATR` default `0.10`. POC overlap scores higher than plain HVN overlap (see §5).

**Rejection rule:** if the Golden Zone sits entirely within an LVN region, reject the setup regardless of other pillars. Price moves fast through LVNs; there is no participation to defend the level.

---

## 4. Pillar 3 — Engulfing Confirmation (WHEN)

### 4.1 Pattern definition
Evaluated on the **close of a completed bar** only. Never on the forming bar.

Bullish engulfing at bar `i`:
```
Close[i-1] < Open[i-1]                              // prior bar bearish
Close[i]   > Open[i]                                // current bar bullish
Open[i]   <= Close[i-1]                             // opens at/below prior close
Close[i]   > Open[i-1]                              // closes above prior open
body[i] >= MinEngulfBodyRatio * body[i-1]           // default 1.10
body[i] >= MinEngulfBodyATR * ATR(14)               // default 0.30, filters noise bars
bodyRatio[i] = body[i] / range[i] >= MinBodyToRange // default 0.55, rejects long-wick fakes
```
Mirror for bearish.

**Configurable strictness:** `RequireWickEngulf` (default `false`). When true, requires `High[i] > High[i-1] && Low[i] < Low[i-1]` — full range engulf, fewer but cleaner signals.

### 4.2 Location requirement
The engulfing candle must interact with the zone:
- Its low (bullish) / high (bearish) must penetrate the Golden Zone, **and**
- Its close must be back inside or beyond the zone in the trade direction.

This is what distinguishes a meaningful engulf from one "in the middle of nowhere."

### 4.3 Expiry
If no qualifying engulf appears within `ZoneDwellBars` (default `20`) of the first zone touch, the setup expires. Prevents stale setups from firing days later.

---

## 5. Confluence Scoring

Rather than a pure boolean AND, score the setup so quality can be graded and position size scaled.

| Component | Points | Condition |
|---|---:|---|
| Fib zone valid | 30 | Mandatory — 0 here aborts |
| POC overlap | 30 | Full points for POC |
| HVN overlap | 20 | If no POC overlap |
| Engulf confirmed | 25 | Mandatory — 0 here aborts |
| HTF trend alignment | 10 | Leg direction matches `HTFTrendTimeframe` EMA slope |
| Engulf body ≥ 1.5× prior | 5 | Bonus for conviction |

`MinConfluenceScore` default `85`. Below threshold → no trade. Log the score and component breakdown on every evaluation, including rejections.

---

## 6. Execution

### 6.1 Entry
| Mode | Behaviour |
|---|---|
| `ENTRY_MARKET` | Market order on confirmed bar close (default) |
| `ENTRY_LIMIT_RETEST` | Limit at engulf candle 50% body level, expires after `LimitExpiryBars` |

Apply `MaxSpreadPoints` guard (default `40` for XAUUSD, tune per symbol) and `SlippagePoints`.

### 6.2 Stops
`StopLoss` = the furthest of:
1. Engulf candle low/high ± `StopBufferATR * ATR(14)` (default `0.25`)
2. Nearest LVN edge beyond the zone
3. `legLow` / `legHigh` (structural invalidation)

Capped at `MaxStopATR * ATR(14)` (default `3.0`). If the required stop exceeds the cap, skip the trade rather than tightening it.

### 6.3 Targets
- **TP1** — `TP1_R` (default `1.0` R) → close `PartialClosePercent` (default `50`), move stop to breakeven + `BreakevenBufferPoints`.
- **TP2** — swing origin (`legHigh` for bullish) or `TP2_R` (default `2.5` R), whichever the `TP2Mode` input selects.
- Optional trailing after TP1: ATR trail (`TrailATRMultiplier`, default `2.0`) or prior-swing trail. Reuse the trailing module from `SMC_MultiModel_v2` if compatible.

### 6.4 Risk
- `RiskPercent` per trade, default `0.5`.
- Lot size from stop distance, tick value, and symbol contract spec. Normalize to `SYMBOL_VOLUME_STEP`; validate against `SYMBOL_VOLUME_MIN` / `MAX`.
- `MaxConcurrentPositions` default `1` per symbol per magic.
- `MaxDailyLossPercent` default `3.0` → halt new entries for the session.
- `MaxConsecutiveLosses` default `4` → halt, require manual reset.

---

## 7. Safety Gates

Five sequential gates, per SIGMA convention. Each logs its own pass/fail with reason. Any failure aborts the chain.

1. **Gate 1 — Authorization.** `AUTO_TRADING_ENABLED` is true (defaults to **false**), terminal AutoTrading on, symbol trade mode is full, account allows trading.
2. **Gate 2 — Market conditions.** Spread within `MaxSpreadPoints`; not inside `NewsBlackoutMinutes` window if news filter enabled; within `TradingSessionStart`/`End`; not within `MinutesBeforeClose` of session end.
3. **Gate 3 — Signal integrity.** Confluence score ≥ `MinConfluenceScore`; all mandatory pillars non-zero; setup not expired; bar is fully closed; no duplicate signal on this bar time.
4. **Gate 4 — Risk envelope.** Position count, daily loss, consecutive losses, margin level ≥ `MinMarginLevelPercent` (default `200`), computed lot within symbol bounds.
5. **Gate 5 — Order construction.** Stop distance ≥ `SYMBOL_TRADE_STOPS_LEVEL`; SL/TP normalized to `SYMBOL_DIGITS`; filling mode `ORDER_FILLING_IOC` with FOK fallback; magic number set; deviation set.

---

## 8. Inputs Summary

```mql5
// --- Master
input bool   AUTO_TRADING_ENABLED   = false;
input long   MagicNumber            = 2026072001;
input string TradeComment           = "VERTEX_Triad";

// --- Pillar 1: Fibonacci
input int    SwingLookback          = 5;
input double MinLegATR              = 2.0;
input double MinImpulseBodyRatio    = 0.60;
input int    MaxLegAgeBars          = 50;
input double MaxInternalRetrace     = 0.382;
input double FibZoneUpper           = 0.500;
input double FibZoneLower           = 0.618;
input double FibInvalidation        = 0.786;

// --- Pillar 2: Volume Profile
input int    ProfileLookbackBars    = 200;
input int    ProfileRowCount        = 100;
input double ValueAreaPercent       = 70.0;
input double HVNThreshold           = 0.70;
input double LVNThreshold           = 0.25;
input double MinOverlapATR          = 0.10;
input bool   UseRealVolumeIfAvailable = true;

// --- Pillar 3: Engulfing
input double MinEngulfBodyRatio     = 1.10;
input double MinEngulfBodyATR       = 0.30;
input double MinBodyToRange         = 0.55;
input bool   RequireWickEngulf      = false;
input int    ZoneDwellBars          = 20;

// --- Confluence
input double MinConfluenceScore     = 85.0;
input ENUM_TIMEFRAMES HTFTrendTimeframe = PERIOD_H4;

// --- Execution & Risk
input double RiskPercent            = 0.5;
input double StopBufferATR          = 0.25;
input double MaxStopATR             = 3.0;
input double TP1_R                  = 1.0;
input double TP2_R                  = 2.5;
input int    PartialClosePercent    = 50;
input int    MaxSpreadPoints        = 40;
input int    SlippagePoints         = 20;
input int    MaxConcurrentPositions = 1;
input double MaxDailyLossPercent    = 3.0;
input int    MaxConsecutiveLosses   = 4;
```

---

## 9. Dashboard Panel

An on-chart panel showing live EA state. Draggable and collapsible.

### 9.1 Implementation approach

MQL5 has no native draggable window. The panel is built from chart objects and the drag is implemented manually.

- Container: `OBJ_RECTANGLE_LABEL` with `OBJPROP_CORNER = CORNER_LEFT_UPPER`, positioned by `OBJPROP_XDISTANCE` / `OBJPROP_YDISTANCE`.
- Rows: `OBJ_LABEL` objects, positioned relative to the container origin.
- All object names prefixed `VTX_PNL_` plus the magic number, so multiple instances on one terminal never collide. Deleting the EA removes only its own objects.
- `OBJPROP_SELECTABLE = false` and `OBJPROP_HIDDEN = true` on every object — the user must not be able to drag or delete individual elements with the mouse.
- `OBJPROP_ZORDER` set above chart content so the panel stays on top.

**Do not use `CAppDialog` from the standard library.** It provides dragging out of the box but is heavyweight, hard to style, and interacts poorly with the Strategy Tester's visual mode. Build from primitives.

### 9.2 Drag behaviour

Requires `ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true)` in `OnInit`.

Handle in `OnChartEvent`:
```
CHARTEVENT_MOUSE_MOVE:
  sparam encodes mouse button state; lparam = x, dparam = y
  
  On button-down inside the title bar region:
     dragging = true
     dragOffsetX = mouseX - panelX
     dragOffsetY = mouseY - panelY
     ChartSetInteger(0, CHART_MOUSE_SCROLL, false)   // stop chart panning while dragging
  
  While dragging and button held:
     panelX = mouseX - dragOffsetX
     panelY = mouseY - dragOffsetY
     clamp to chart bounds (CHART_WIDTH_IN_PIXELS / CHART_HEIGHT_IN_PIXELS)
     reposition container + all child labels
     ChartRedraw()
  
  On button-up:
     dragging = false
     ChartSetInteger(0, CHART_MOUSE_SCROLL, true)     // restore
     persist panelX/panelY to GlobalVariable
```

**Restore `CHART_MOUSE_SCROLL` on drag end and in `OnDeinit`.** Leaving it disabled makes the chart feel broken and the user will not connect it to the EA.

Clamp position so the title bar can never be dragged fully off-screen — otherwise the panel becomes unrecoverable without deleting global variables.

Persist `panelX`, `panelY`, and collapsed state via `GlobalVariableSet` keyed on magic number, so layout survives recompiles and terminal restarts.

### 9.3 Collapse behaviour

- Toggle control in the title bar (an `OBJ_LABEL` rendered as `▾` / `▸`, or a Wingdings glyph).
- Click detection: `CHARTEVENT_OBJECT_CLICK` where `sparam` matches the toggle object name.
- Collapsed: hide all body labels (`OBJPROP_TIMEFRAMES = OBJ_NO_PERIODS` hides without deleting), shrink container height to title-bar height only.
- Expanded: restore visibility and full height.
- State persisted alongside position.

### 9.4 Panel content

```
┌─────────────────────────────────────────┐
│ VERTEX_Triad · XAUUSD M15           ▾ ✕ │   title bar (drag handle)
├─────────────────────────────────────────┤
│ STATUS                                  │
│   Auto Trading      ● ENABLED / DISABLED│
│   Gates             5/5 PASS            │
│   Last Block        Gate 2: spread 62   │
├─────────────────────────────────────────┤
│ SETUP                                   │
│   Leg               BULL  2547.10→2588.4│
│   Golden Zone       2568.2 – 2562.9     │
│   Zone Status       PRICE INSIDE (4 bars)│
│   POC               2565.8  ✓ OVERLAP   │
│   HVN Overlap       0.34 ATR            │
│   Engulf            WAITING             │
│   Confluence Score  60 / 85             │
├─────────────────────────────────────────┤
│ POSITION                                │
│   Open              1  BUY 0.12         │
│   Entry / SL / TP   2564.1 / 2558.0 /…  │
│   Floating          +18.40  (+0.42 R)   │
│   TP1 Hit           NO                  │
├─────────────────────────────────────────┤
│ RISK                                    │
│   Risk / Trade      0.5%                │
│   Daily P/L         -1.2%  (limit 3.0%) │
│   Consec. Losses    1 / 4               │
│   Margin Level      842%                │
├─────────────────────────────────────────┤
│ SESSION                                 │
│   Trades Today      2                   │
│   Wins / Losses     1 / 1               │
│   Expectancy        +0.31 R  (n=47)     │
│   Spread            28 pts              │
│   Telegram          ● CONNECTED         │
└─────────────────────────────────────────┘
```

Colour coding: green for pass/profit, amber for waiting/warning, red for blocked/loss, grey for inactive. Use `InpPanelColor*` inputs so the scheme is adjustable rather than hardcoded.

### 9.5 Refresh policy

- Full recompute on new bar.
- Lightweight fields only (floating P/L, spread, price-in-zone) on tick, throttled to `PanelRefreshMs` (default `500`) via `GetTickCount()` comparison. Redrawing every label on every tick is a measurable drag on the tester.
- `ChartRedraw()` called once per refresh cycle, not per object update.
- Skip panel updates entirely when `MQLInfoInteger(MQL_TESTER)` is true and visual mode is off — no point rendering to nothing.

### 9.6 Panel inputs

```mql5
input bool   ShowPanel            = true;
input int    PanelX               = 20;
input int    PanelY               = 20;
input int    PanelWidth           = 300;
input int    PanelRefreshMs       = 500;
input bool   PanelStartCollapsed  = false;
input color  PanelBgColor         = C'28,32,38';
input color  PanelTextColor       = clrGainsboro;
input color  PanelAccentColor     = C'240,185,60';
input color  PanelGoodColor       = clrMediumSeaGreen;
input color  PanelWarnColor       = clrGoldenrod;
input color  PanelBadColor        = clrIndianRed;
input string PanelFont            = "Consolas";
input int    PanelFontSize        = 8;
```

---

## 10. Telegram Notifications

### 10.1 Setup prerequisite

`WebRequest` requires the domain to be whitelisted manually in each terminal:

**Tools → Options → Expert Advisors → Allow WebRequest for listed URL → add `https://api.telegram.org`**

This cannot be done programmatically. On `OnInit`, send a test message; if it fails with error `4014` (function not allowed), log an explicit instruction to the user rather than a generic failure. This is the single most common setup mistake with Telegram in MQL5.

### 10.2 Transport

```mql5
// POST to https://api.telegram.org/bot<TOKEN>/sendMessage
// Body: chat_id, text, parse_mode=HTML, disable_web_page_preview=true
WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
```

Rules:
- `WebRequest` is **synchronous and blocking**. Never call it inside the order-execution path. Queue messages and flush from a timer or the tail of `OnTick`, after trade logic has completed. A 3-second Telegram timeout during order placement is a real slippage cost.
- Timeout: `TelegramTimeoutMs`, default `3000`.
- HTML-escape `&`, `<`, `>` in any dynamic text before sending, or messages with those characters will silently fail to deliver.
- Never log the bot token. Mask it in all diagnostic output.

### 10.3 Message queue

- Fixed-size ring buffer (`TelegramQueueSize`, default `50`).
- Flush one message per timer tick to respect Telegram's ~30 messages/second limit; in practice this EA will never approach it, but bursts during rapid gate failures could.
- On send failure: retry up to `TelegramMaxRetries` (default `3`) with backoff, then drop and log locally. **Telegram delivery failure must never block or alter trading logic.**
- Deduplicate: suppress identical messages within `TelegramDedupeSeconds` (default `60`). Prevents a repeating gate block from flooding the channel.

### 10.4 Notification catalogue

Each category independently toggleable. Defaults chosen so the channel stays useful rather than noisy.

| Event | Default | Content |
|---|:---:|---|
| **EA started** | ON | Symbol, TF, magic, auto-trading state, build version |
| **EA stopped** | ON | Reason (`OnDeinit` reason code, decoded) |
| **Setup forming** | OFF | Leg identified, zone levels, awaiting POC/engulf |
| **Zone entered** | ON | Price entered Golden Zone, POC overlap status, current score |
| **Signal confirmed** | ON | Full confluence breakdown, score, direction |
| **Trade opened** | ON | Direction, lots, entry, SL, TP1/TP2, R-distance, score |
| **TP1 hit** | ON | Partial closed, realized R, stop moved to BE |
| **Trade closed** | ON | Exit reason, gross/net P/L, R multiple, duration |
| **Stop loss hit** | ON | Loss in account currency and R, consecutive-loss count |
| **Trailing stop moved** | OFF | Old → new SL, locked-in R |
| **Gate blocked** | OFF | Which gate, reason, relevant value (deduped) |
| **Daily loss limit hit** | ON | Loss %, trading halted for session |
| **Consecutive loss limit** | ON | Count, halted, manual reset required |
| **Margin warning** | ON | Margin level below `MinMarginLevelPercent` |
| **Connection lost/restored** | ON | Terminal disconnect detection |
| **Error / exception** | ON | `OrderSend` failures with retcode, array bounds, division guards |
| **Daily summary** | ON | Trades, W/L, net R, net currency, best/worst, sent at `DailySummaryHour` |
| **Weekly summary** | OFF | Aggregate stats, expectancy, drawdown |

**Critical alerts** (daily loss limit, consecutive losses, margin warning, errors, connection lost) bypass the dedupe window and flush immediately rather than waiting for the queue.

### 10.5 Message format

HTML `parse_mode`. Keep messages scannable on a phone lock screen — the first line must carry the essential information.

```
🟢 <b>TRADE OPENED</b> · XAUUSD M15

Direction   BUY
Entry       2564.10
Stop        2558.00  (-6.10 | 0.42 ATR)
TP1         2570.20  (1.0R)
TP2         2579.35  (2.5R)
Lots        0.12  (0.5% risk)

<b>Confluence 92/100</b>
✓ Fib Zone      30  (0.5–0.618)
✓ POC Overlap   30  (0.34 ATR)
✓ Bull Engulf   25  (1.8× body)
✓ H4 Trend      10
+ Body bonus     5

<i>Magic 2026072001 · 14:32:07 GMT+8</i>
```

Emoji prefix by severity: 🟢 entry/profit · 🔴 loss/stop · 🟡 warning/blocked · 🔵 informational · ⚫ EA lifecycle · ⚠️ critical.

### 10.6 Telegram inputs

```mql5
input bool   TelegramEnabled           = false;   // opt-in, like AUTO_TRADING_ENABLED
input string TelegramBotToken          = "";
input string TelegramChatID            = "";
input int    TelegramTimeoutMs         = 3000;
input int    TelegramQueueSize         = 50;
input int    TelegramMaxRetries        = 3;
input int    TelegramDedupeSeconds     = 60;
input bool   NotifyLifecycle           = true;
input bool   NotifySetupForming        = false;
input bool   NotifyZoneEntered         = true;
input bool   NotifySignalConfirmed     = true;
input bool   NotifyTradeEvents         = true;
input bool   NotifyTrailingMoves       = false;
input bool   NotifyGateBlocks          = false;
input bool   NotifyRiskLimits          = true;
input bool   NotifyErrors              = true;
input bool   NotifyDailySummary        = true;
input int    DailySummaryHour          = 23;      // server time
input bool   TelegramInTester          = false;   // suppress during backtests
```

`TelegramInTester` defaults false — a backtest firing hundreds of messages will get the bot rate-limited.

---

## 11. Module Layout

```
VERTEX_Triad/
├── VERTEX_Triad.mq5         Entry points: OnInit/OnTick/OnTimer/OnDeinit/
│                            OnChartEvent/OnTradeTransaction
├── Include/Triad/           Modules (13)
├── config/                  telegram.ini.template (real .ini gitignored)
├── tests/                   Forced-fail gate harnesses
├── journal/                 CSV output (gitignored)
├── docs/phase0..phase10/    Validation evidence per phase
├── SPEC.md                  This document
├── CLAUDE.md                Build rules
├── CHECKLIST.md             Phase gates
├── PROJECT_IMPLEMENTATION_TRACKER.md
├── README.md
└── .gitignore
```

### Module files

```
VERTEX_Triad.mq5              Entry points: OnInit/OnTick/OnTimer/OnDeinit/OnChartEvent/OnTradeTransaction
Include/Triad/
  SwingDetector.mqh          Fractal swings, impulse leg qualification
  FibZone.mqh                Zone construction, invalidation tracking
  VolumeProfile.mqh          Binning, POC, VA, HVN/LVN clustering
  EngulfDetector.mqh         Pattern rules, location + expiry checks
  ConfluenceScorer.mqh       Weighted scoring, breakdown logging
  RiskManager.mqh            Lot sizing, daily/streak limits
  TradeExecutor.mqh          Gates 1-5, order send, filling fallback
  PositionManager.mqh        Partials, breakeven, trailing
  Journal.mqh                CSV + structured log output
  Visualizer.mqh             Chart objects: zone, POC/HVN, signal markers
  Dashboard.mqh              Panel render, drag, collapse, state persistence
  Telegram.mqh               WebRequest transport, queue, retry, formatting
  Notifier.mqh               Event routing — decides what gets sent where
```

`Notifier.mqh` sits between the trading modules and both output channels. Trading modules raise semantic events (`Notify_TradeOpened(...)`); the notifier decides whether that becomes a Telegram message, a panel update, a journal row, or all three. **No trading module calls `Telegram.mqh` directly** — that coupling is what makes notification bugs turn into execution bugs.

**Performance note:** recompute the volume profile only on new bar formation, not every tick. Cache the binned array; a 200-bar × 100-row rebuild on every tick will bog down the tester and live charts alike.

---

## 12. Logging & Journal

Every evaluation writes a row, including rejections — rejected setups are where tuning information lives.

CSV columns: `timestamp, symbol, tf, direction, legHigh, legLow, zoneUpper, zoneLower, pocPrice, hvnOverlap, overlapATR, engulfType, engulfBodyRatio, score, scoreBreakdown, decision, rejectReason, entry, sl, tp1, tp2, lots, spread, resultR`.

---

## 13. Build Phases

Phase gates follow SIGMA convention: each phase ends with a checklist; on all-pass, git commit and push.

| Phase | Deliverable | Exit criteria |
|---|---|---|
| 0 | Repo scaffold, CLAUDE.md, SPEC.md, CHECKLIST.md | Compiles empty EA, git initialized |
| 1 | SwingDetector + FibZone | Zones drawn on chart match manual Fib tool within 1 tick |
| 2 | VolumeProfile | POC/VAH/VAL match a reference TradingView profile on same range within one bin |
| 3 | EngulfDetector | Detected patterns match manual chart review across 100 bars, no false positives |
| 4 | ConfluenceScorer | Score breakdown logged for 200 bars; manual audit of 10 samples |
| 5 | RiskManager + TradeExecutor | All 5 gates verified individually with forced-fail tests |
| 6 | PositionManager | Partials, BE, trailing verified in Strategy Tester visual mode |
| 7 | Notifier + Dashboard | Panel renders, drags within bounds, collapses, state survives recompile; no tick-rate performance regression |
| 8 | Telegram | Test message on init; all categories fire correctly; WebRequest failure proven not to affect trade execution |
| 9 | Backtest + optimization | ≥ 200 trades, XAUUSD + BTCUSD, walk-forward split |
| 10 | Demo forward test | 30 days minimum, live journal and Telegram feed reviewed |

---

## 14. Validation Requirements

- **Every-tick modelling** with real ticks for the tester. M1 OHLC will misrepresent engulf detection and stop-hit sequencing.
- **Walk-forward**, not single-period optimization. In-sample 70 / out-of-sample 30, rolling.
- Report: net profit, profit factor, max drawdown %, Sharpe, expectancy in R, win rate, average R, longest losing streak, trade count.
- **Sensitivity check:** vary `MinConfluenceScore`, `HVNThreshold`, `MinEngulfBodyRatio` ±20%. If results collapse, the edge is curve-fit rather than real.
- Compare against a control: same entries with Pillar 2 disabled, and with Pillar 3 disabled. If the three-pillar version doesn't beat both, the extra complexity isn't earning its keep — that comparison is the honest test of the whole premise.

Backtest results are not predictive of live performance. Treat the demo forward test as the real gate, and size conservatively regardless of what the optimizer reports.

---

## 15. Known Risks

| Risk | Mitigation |
|---|---|
| Tick volume ≠ real volume on FX/CFD | Document; validate POC against a reference platform; prefer symbols with real volume where available |
| Over-filtering → too few trades | Track rejection reasons; if trade count < 2/month per symbol, relax score threshold before adding pillars |
| Repainting via forming-bar evaluation | Hard rule: all pattern logic on closed bars only |
| Profile recompute cost | New-bar-only recompute, cached arrays |
| Curve-fit parameters | Walk-forward + sensitivity sweep + ablation controls |
| Broker execution differences | Validate on both VT Markets and Pepperstone before live |
| Blocking WebRequest delays orders | Queue + flush outside execution path; never call inline with OrderSend |
| Panel redraw cost on every tick | Throttled refresh; skip entirely in non-visual tester |
| Bot token leaked via logs or repo | Never logged, masked in diagnostics, gitignored config |
| Telegram domain not whitelisted | Explicit error 4014 detection with setup instructions on init |
| Panel dragged off-screen | Position clamped to chart bounds; reset via GlobalVariable delete |
