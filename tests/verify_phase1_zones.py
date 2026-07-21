"""
verify_phase1_zones.py — Phase 1 automated Fibonacci zone math verifier.

Reads the CSV written by VERTEX_Triad.mq5 during a Strategy Tester run
(MQL5/Files/VERTEX_Triad/phase1_zones.csv) and checks every detected leg:

  For a BULLISH leg:
    expected_fib050  = legHigh - 0.500 * legRange
    expected_fib0618 = legHigh - 0.618 * legRange
    expected_upper   = max(fib050, fib0618)
    expected_lower   = min(fib050, fib0618)
    expected_invLevel = legHigh - 0.786 * legRange

  For a BEARISH leg (mirror):
    expected_fib050  = legLow + 0.500 * legRange
    expected_fib0618 = legLow + 0.618 * legRange
    etc.

Pass condition: every value within TICK_TOLERANCE of the computed expectation.

Usage:
  python tests/verify_phase1_zones.py <path_to_phase1_zones.csv>

The CSV is written to the MT5 "Files" folder of the active terminal profile:
  C:\\Users\\<user>\\AppData\\Roaming\\MetaQuotes\\Terminal\\<hash>\\MQL5\\Files\\VERTEX_Triad\\phase1_zones.csv

Example (adjust the path):
  python tests/verify_phase1_zones.py "C:/Users/nimrod.resulta/AppData/Roaming/MetaQuotes/Terminal/9BB124B7D418C7FB69DF2865535BA9BF/MQL5/Files/VERTEX_Triad/phase1_zones.csv"
"""

import csv
import sys
import math

# Tolerance: 1 point in price — adjust to match your symbol's pip/point size.
# For XAUUSD with 2 decimal places, 1 point = 0.01. For 3 dp, 0.001 etc.
# Set to 0.01 (1 point XAUUSD) — tighter than the 1-tick SPEC requirement.
TICK_TOLERANCE = 0.01

FIB_050  = 0.500
FIB_0618 = 0.618
FIB_786  = 0.786


def expected_values(direction: str, leg_high: float, leg_low: float, leg_range: float):
    """Return expected fib050, fib0618, upper, lower, inv_level for a leg."""
    if direction == "BULL":
        f050   = leg_high - FIB_050  * leg_range
        f0618  = leg_high - FIB_0618 * leg_range
        inv    = leg_high - FIB_786  * leg_range
    else:  # BEAR
        f050   = leg_low + FIB_050  * leg_range
        f0618  = leg_low + FIB_0618 * leg_range
        inv    = leg_low + FIB_786  * leg_range

    upper = max(f050, f0618)
    lower = min(f050, f0618)
    return f050, f0618, upper, lower, inv


def approx_eq(a: float, b: float, tol: float = TICK_TOLERANCE) -> bool:
    return math.fabs(a - b) <= tol


def verify(csv_path: str):
    passed = 0
    failed = 0
    errors = []

    with open(csv_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row_num, row in enumerate(reader, start=2):  # row 1 = header
            try:
                direction   = row["direction"].strip()
                leg_high    = float(row["legHigh"])
                leg_low     = float(row["legLow"])
                leg_range   = float(row["legRange"])
                ea_f050     = float(row["fib050"])
                ea_f0618    = float(row["fib0618"])
                ea_upper    = float(row["zoneUpper"])
                ea_lower    = float(row["zoneLower"])
                ea_inv      = float(row["invalidLevel"])
                bartime     = row["bartime"].strip()
            except (KeyError, ValueError) as e:
                errors.append(f"  Row {row_num}: parse error — {e}")
                failed += 1
                continue

            # Recompute expected values independently (SPEC §2.2)
            ex_f050, ex_f0618, ex_upper, ex_lower, ex_inv = expected_values(
                direction, leg_high, leg_low, leg_range)

            checks = [
                ("fib050",     ea_f050,  ex_f050),
                ("fib0618",    ea_f0618, ex_f0618),
                ("zoneUpper",  ea_upper, ex_upper),
                ("zoneLower",  ea_lower, ex_lower),
                ("invalidLevel", ea_inv, ex_inv),
            ]

            row_ok = True
            for field, ea_val, ex_val in checks:
                if not approx_eq(ea_val, ex_val):
                    errors.append(
                        f"  FAIL row {row_num} ({bartime} {direction}): "
                        f"{field} EA={ea_val:.5f} expected={ex_val:.5f} "
                        f"delta={math.fabs(ea_val-ex_val):.5f}"
                    )
                    row_ok = False

            if row_ok:
                passed += 1
            else:
                failed += 1

    print(f"\n=== Phase 1 Zone Math Verification ===")
    print(f"File : {csv_path}")
    print(f"Rows : {passed + failed}")
    print(f"PASS : {passed}")
    print(f"FAIL : {failed}")
    print(f"Tolerance : ±{TICK_TOLERANCE} (1 point XAUUSD)\n")

    if errors:
        print("Failures:")
        for e in errors:
            print(e)
    else:
        print("All zone calculations verified correct.")

    if failed == 0 and passed > 0:
        print("\nPhase 1 math gate: PASS")
        print(f"Evidence: {passed} legs verified across backtest run.")
        return 0
    elif passed == 0 and failed == 0:
        print("\nNo rows found — did the backtest produce any accepted legs?")
        print("Try increasing MaxLegAgeBars in EA inputs to 150 for the test run.")
        return 1
    else:
        print(f"\nPhase 1 math gate: FAIL ({failed} rows with incorrect zone values)")
        return 2


if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Try the default MT5 path automatically
        import os
        default = (
            r"C:\Users\nimrod.resulta\AppData\Roaming\MetaQuotes\Terminal"
            r"\9BB124B7D418C7FB69DF2865535BA9BF\MQL5\Files"
            r"\VERTEX_Triad\phase1_zones.csv"
        )
        if os.path.exists(default):
            print(f"No path given — using default:\n  {default}\n")
            sys.exit(verify(default))
        else:
            print(__doc__)
            sys.exit(1)
    else:
        sys.exit(verify(sys.argv[1]))
