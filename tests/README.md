# Tests

Forced-fail harnesses proving each safety gate blocks. See CHECKLIST.md Phase 5.

| Script | Proves |
|---|---|
| `gate1_authorization.mq5` | `AUTO_TRADING_ENABLED = false` blocks |
| `gate2_market.mq5` | Spread above `MaxSpreadPoints` blocks |
| `gate3_signal.mq5` | Score below `MinConfluenceScore` blocks |
| `gate4_risk.mq5` | Daily loss / streak / margin each block |
| `gate5_order.mq5` | Sub-stops-level distance blocks |
| `telegram_offline.mq5` | Network down does not affect execution |

A gate that has not been proven to block has not been tested.
