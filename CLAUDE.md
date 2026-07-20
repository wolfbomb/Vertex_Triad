# CLAUDE.md — VERTEX_Triad

Operating instructions for Claude Code on this repository. Read this before any task. Read `SPEC.md` before writing code.

---

## Project

`VERTEX_Triad` — MQL5 Expert Advisor for MetaTrader 5. Trades only where three independent signals converge: Fibonacci Golden Zone (0.5–0.618), Volume Profile POC/HVN, and an Engulfing candle confirmation.

Targets: XAUUSD, BTCUSD. Brokers: VT Markets, Pepperstone Razor ECN.

**The strategy's value is in what it refuses to trade.** When implementing, bias toward rejecting ambiguous setups. A missed trade costs nothing; a filter that quietly passes bad setups defeats the entire design.

---

## Non-negotiable rules

1. `AUTO_TRADING_ENABLED` defaults to `false`. Never change this default. Never add code that bypasses it.
2. All pattern and signal logic evaluates **closed bars only**. No forming-bar evaluation anywhere. This is the repainting boundary.
3. Order filling: `ORDER_FILLING_IOC`, with FOK fallback when the symbol rejects IOC.
4. Magic number format `YYMMDDNN`. One magic per EA instance. All position queries filter by magic — never operate on positions this instance didn't open.
5. Every trade decision passes all five safety gates in order (SPEC §7). No shortcuts, no "temporary" gate skips.
6. Log rejections as thoroughly as entries. Rejection data is the tuning signal.
7. Never commit credentials, account numbers, or broker server details.
8. **Notifications and UI must never affect trading.** No `WebRequest` inside the order path. No panel code that can throw into `OnTick`'s trade logic. If Telegram is down or the panel fails to render, trades still execute correctly. Wrap both subsystems so their failures are contained and logged, not propagated.
9. **Never log or commit the bot token.** Mask it in all diagnostic output. `TelegramBotToken` and `TelegramChatID` go in a gitignored config, never in committed source or default input values.
10. Trading modules raise semantic events via `Notifier.mqh`. They never call `Telegram.mqh` or `Dashboard.mqh` directly.

---

## Repository layout

```
VERTEX_Triad.mq5           Main EA
Include/Triad/*.mqh       Modules — see SPEC §9
SPEC.md                   Technical specification (source of truth)
CHECKLIST.md              Phase gates with required evidence
CLAUDE.md                 This file
PROJECT_IMPLEMENTATION_TRACKER.md   Living state — update every session
tests/                    Test harness scripts
journal/                  CSV output (gitignored)
docs/                     Backtest reports, decision notes
```

---

## Workflow

Phase-based, per SIGMA convention. One phase at a time.

1. Read `SPEC.md` for the phase's requirements.
2. Read `CHECKLIST.md` for its exit criteria.
3. Implement.
4. Compile — zero errors, zero warnings. Warnings are not acceptable in this codebase.
5. Verify each checklist item explicitly. State the evidence, not just "done."
6. Update `PROJECT_IMPLEMENTATION_TRACKER.md`: phase status, module status, session log entry, any decisions or parameter changes.
7. On all-pass: `git add -A && git commit -m "Phase N: <summary>" && git push`.
8. Report status and stop. Wait for confirmation before the next phase.

**Tracker discipline:** update it at the end of every session, including sessions that end blocked or incomplete. A session that ends without a tracker entry leaves the next session starting blind. Record unfavourable results too — deleted bad runs destroy the pattern that makes the good ones interpretable.

Do not advance phases unprompted. Do not implement Phase 4 while Phase 2 is unverified.

---

## Code conventions

- Modules are self-contained `.mqh` includes with a clear public interface. No cross-module global state.
- Prefix module functions: `Fib_`, `VP_`, `Eng_`, `Risk_`, `Exec_`.
- Struct-based data passing. Avoid parallel arrays.
- Every magic number in logic gets a named `input` or `const`. No bare literals in conditionals.
- Normalize all prices with `NormalizeDouble(price, _Digits)` before sending.
- Never compare doubles with `==`. Use an epsilon or `MathAbs(a-b) < _Point/2`.
- Validate every `OrderSend` return. Log `retcode` and `comment` on failure.
- Guard array access. `ArraySize()` before indexing, always.

---

## Dashboard conventions

- All object names prefixed `VTX_PNL_<magic>_`. `OnDeinit` deletes only objects matching that prefix — never `ObjectsDeleteAll(0)`, which would wipe the user's own chart drawings.
- Every panel object: `SELECTABLE = false`, `HIDDEN = true`. Users must not be able to select or delete elements individually.
- Restore `CHART_MOUSE_SCROLL` to true on drag end **and** in `OnDeinit`. Leaving chart panning disabled makes the terminal feel broken.
- Clamp panel position to chart bounds so the title bar always remains grabbable.
- Persist position and collapse state to `GlobalVariable` keyed on magic.
- Build from `OBJ_RECTANGLE_LABEL` + `OBJ_LABEL` primitives. Do not use `CAppDialog`.

## Telegram conventions

- `WebRequest` is blocking. Queue and flush from `OnTimer`, never inline with trade logic.
- HTML-escape `&`, `<`, `>` in dynamic content or delivery fails silently.
- Detect error `4014` on init and log the explicit whitelist instruction: Tools → Options → Expert Advisors → Allow WebRequest for `https://api.telegram.org`. This is the most common setup failure — a generic error message wastes the user's time.
- Retry with backoff, then drop and log locally. Never block on delivery.
- `TelegramInTester` defaults false. Do not flood the bot during backtests.

## Performance

- Volume profile recomputes on **new bar only**, never per tick. Cache the bin array.
- Gate `OnTick` on a new-bar check early; most ticks should exit immediately.
- Chart objects: create once, update properties. Don't delete and recreate each bar.
- Panel refresh throttled to `PanelRefreshMs`. One `ChartRedraw()` per cycle, not per object.
- Skip panel rendering entirely when in the tester without visual mode.

---

## Testing

- Strategy Tester: **every tick based on real ticks**. M1 OHLC misrepresents engulf detection and stop sequencing — results from it are not valid evidence.
- Before claiming a phase complete, run the visual-mode tester and confirm behaviour matches intent on screen.
- For each gate, write a forced-fail test proving it blocks.
- Walk-forward, not single-period optimization. Report the out-of-sample numbers, not the in-sample ones.

---

## When reporting results

State what the numbers actually show, including when they're unfavourable. If a backtest looks exceptional, treat that as a signal to check for look-ahead bias, unrealistic fills, or curve-fitting before treating it as a result. If the ablation controls (SPEC §12) show two pillars perform as well as three, say so plainly — that's a finding worth acting on, not a problem to tune away.

Do not present optimized in-sample results as expected live performance.

---

## When uncertain

Ask. Do not infer strategy intent from partial context. Specifically, escalate rather than guess on:
- Anything that changes risk sizing or gate behaviour
- Ambiguity between SPEC and existing SIGMA suite conventions
- Broker-specific behaviour differences
- Whether to add a parameter versus hardcode a value

Cite the SPEC section number when implementing from it, so decisions are traceable.
