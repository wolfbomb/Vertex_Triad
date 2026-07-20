# VERTEX_Triad

MQL5 Expert Advisor for MetaTrader 5. Trades only where three independent signals converge.

| Pillar | Question | Instrument |
|---|---|---|
| Fibonacci retracement | **WHERE** | 0.5-0.618 Golden Zone |
| Volume Profile | **WHY** | POC / HVN overlap |
| Engulfing candle | **WHEN** | Confirmation inside the zone |

No single pillar is tradeable alone. The strategy's value is in what it refuses.

**Targets:** XAUUSD, BTCUSD - VT Markets, Pepperstone Razor ECN
**Magic:** `2026072001`
**Status:** Phase 0 - scaffold. No trading logic implemented.

## Documents

| File | Purpose |
|---|---|
| `SPEC.md` | Technical specification - source of truth |
| `CLAUDE.md` | Build rules for Claude Code |
| `CHECKLIST.md` | Phase gates with required evidence |
| `PROJECT_IMPLEMENTATION_TRACKER.md` | Living state - update every session |

## Setup

1. Copy `Include/Triad/` to `MQL5/Include/Triad/`
2. Copy `VERTEX_Triad.mq5` to `MQL5/Experts/`
3. Compile in MetaEditor
4. For Telegram: whitelist `https://api.telegram.org` in
   Tools > Options > Expert Advisors. This is manual per terminal.
5. Copy `config/telegram.ini.template` to `config/telegram.ini`, fill in

## Safety

`AUTO_TRADING_ENABLED` defaults to **false**. This default is never changed.

Five sequential safety gates guard every trade (SPEC 7). Notifications and UI
cannot affect trading logic - if Telegram is down or the panel fails, trades
still execute correctly.

Backtest performance is not a prediction of live performance. The demo forward
test is the real gate, and passing it authorizes nothing on its own.
