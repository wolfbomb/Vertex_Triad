//+------------------------------------------------------------------+
//|                                                 VERTEX_Triad.mq5 |
//|                    Three-pillar confluence Expert Advisor        |
//|   Fibonacci Golden Zone (WHERE) + Volume Profile (WHY)           |
//|                                   + Engulfing (WHEN)             |
//|                                                                  |
//|   See SPEC.md for full specification.                            |
//|   See CLAUDE.md for build rules. Phase 0 scaffold.               |
//+------------------------------------------------------------------+
#property copyright "Nimrod"
#property version   "1.00"
#property strict

//--- Modules (SPEC §11)
#include <Triad/SwingDetector.mqh>
#include <Triad/FibZone.mqh>
#include <Triad/VolumeProfile.mqh>
#include <Triad/EngulfDetector.mqh>
#include <Triad/ConfluenceScorer.mqh>
#include <Triad/RiskManager.mqh>
#include <Triad/TradeExecutor.mqh>
#include <Triad/PositionManager.mqh>
#include <Triad/Journal.mqh>
#include <Triad/Visualizer.mqh>
#include <Triad/Notifier.mqh>
#include <Triad/Dashboard.mqh>
#include <Triad/Telegram.mqh>

//+------------------------------------------------------------------+
//| INPUTS - see SPEC §8 (strategy), §9.6 (panel), §10.6 (telegram)  |
//+------------------------------------------------------------------+

//--- Master
input bool   AUTO_TRADING_ENABLED   = false;   // NEVER default to true
input long   MagicNumber            = 2026072001;
input string TradeComment           = "VERTEX_Triad";

//--- Pillar 1: Fibonacci
input int    SwingLookback          = 5;
input double MinLegATR              = 2.0;
input double MinImpulseBodyRatio    = 0.60;
input int    MaxLegAgeBars          = 50;
input double MaxInternalRetrace     = 0.382;
input double FibInvalidation        = 0.786;

//+------------------------------------------------------------------+
//| Global state                                                     |
//+------------------------------------------------------------------+
datetime g_lastBarTime = 0;
SwingImpulseLeg g_activeLeg;
FibZoneState    g_activeZone;

// Identity of the most recently invalidated leg (SPEC §2.3: re-scan for a NEW
// qualified leg — without this, the same dead fractal pair keeps re-qualifying
// every bar until it ages out, since raw price data alone can't tell "new" from
// "the same swing that already failed").
bool     g_hasInvalidatedLeg  = false;
bool     g_invalidatedBullish = false;
datetime g_invalidatedStart   = 0;
datetime g_invalidatedEnd     = 0;

// Price series arrays — copied from the broker feed on each new bar.
// MQL5 has no implicit global High[]/Low[]/etc. in include files;
// all modules receive these by const-ref parameter. (SPEC §11 MQL5 note)
static const int PRICE_COPY_DEPTH = 350;   // covers maxLegAgeBars(50)+ATR(14)+scan margin
double   g_high[];   // series order: [0]=current bar, [1]=prev, ...
double   g_low[];
double   g_open[];
double   g_close[];
datetime g_time[];

// Phase 1 validation file handle (open only in Strategy Tester).
// Writes one CSV row per accepted leg so Python can verify zone math offline.
int g_ph1File = INVALID_HANDLE;

bool G_CopyPriceSeries()
  {
   if(CopyHigh (_Symbol, _Period, 0, PRICE_COPY_DEPTH, g_high)  <= 0) return(false);
   if(CopyLow  (_Symbol, _Period, 0, PRICE_COPY_DEPTH, g_low)   <= 0) return(false);
   if(CopyOpen (_Symbol, _Period, 0, PRICE_COPY_DEPTH, g_open)  <= 0) return(false);
   if(CopyClose(_Symbol, _Period, 0, PRICE_COPY_DEPTH, g_close) <= 0) return(false);
   if(CopyTime (_Symbol, _Period, 0, PRICE_COPY_DEPTH, g_time)  <= 0) return(false);
   ArraySetAsSeries(g_high,  true);
   ArraySetAsSeries(g_low,   true);
   ArraySetAsSeries(g_open,  true);
   ArraySetAsSeries(g_close, true);
   ArraySetAsSeries(g_time,  true);
   return(true);
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- TODO Phase 0: validate inputs, symbol specs
//--- TODO Phase 7: ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
//--- TODO Phase 7: restore panel position/collapse from GlobalVariable
//--- TODO Phase 8: Telegram init test, detect error 4014

   g_activeLeg.valid = false;
   Fib_Reset(g_activeZone);

   ArraySetAsSeries(g_high,  true);
   ArraySetAsSeries(g_low,   true);
   ArraySetAsSeries(g_open,  true);
   ArraySetAsSeries(g_close, true);
   ArraySetAsSeries(g_time,  true);

   // Open Phase-1 validation CSV when running in Strategy Tester.
   // Closed in OnDeinit. Used by tests/verify_phase1_zones.py.
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      g_ph1File = FileOpen("VERTEX_Triad/phase1_zones.csv",
                           FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(g_ph1File != INVALID_HANDLE)
         FileWrite(g_ph1File,
                   "bartime","direction",
                   "legHigh","legLow","legRange",
                   "fib050","fib0618",
                   "zoneUpper","zoneLower",
                   "invalidLevel");
     }

   EventSetTimer(1);   // Telegram queue flush - never inline with OrderSend
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

//--- Phase 7: restore chart scrolling - leaving this off feels broken
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);

//--- TODO Phase 7: persist panel state; delete ONLY VTX_PNL_<magic>_ objects
//---              never ObjectsDeleteAll(0) - would wipe user's drawings
//--- TODO Phase 8: notify lifecycle stop with decoded reason

  Viz_ClearPhase1(MagicNumber);

  if(g_ph1File != INVALID_HANDLE)
    {
     FileClose(g_ph1File);
     g_ph1File = INVALID_HANDLE;
    }
  }

//+------------------------------------------------------------------+
//| Tick handler                                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Cheap per-tick work only. Gate heavy logic on new bar.
//--- TODO Phase 7: throttled panel refresh (PanelRefreshMs)
//--- TODO Phase 6: position management

   if(!IsNewBar())
      return;

//--- Copy price series once per new bar. All modules receive these arrays.
   if(!G_CopyPriceSeries())
     {
      Print("[EA] Price copy failed — skipping bar");
      return;
     }

//--- New bar: full evaluation (closed bars only - repainting boundary)
//--- Phase 1: detect impulse leg and maintain Golden Zone (SPEC §2)
   SwingConfig cfg;
   cfg.lookback            = SwingLookback;
   cfg.minLegAtr           = MinLegATR;
   cfg.minImpulseBodyRatio = MinImpulseBodyRatio;
   cfg.maxLegAgeBars       = MaxLegAgeBars;
   cfg.maxInternalRetrace  = MaxInternalRetrace;

   SwingImpulseLeg detectedLeg;
   string rejectReason;
   if(Swing_FindLatestQualifiedLeg(cfg, g_high, g_low, g_close, g_open, g_time,
                                   g_hasInvalidatedLeg, g_invalidatedBullish,
                                   g_invalidatedStart, g_invalidatedEnd,
                                   detectedLeg, rejectReason))
     {
      const bool legChanged = (!g_activeLeg.valid ||
                               g_activeLeg.startIndex != detectedLeg.startIndex ||
                               g_activeLeg.endIndex != detectedLeg.endIndex ||
                               g_activeLeg.bullish != detectedLeg.bullish);

      g_activeLeg = detectedLeg;
      if(legChanged)
        {
         Fib_BuildFromLeg(g_activeLeg, FibInvalidation, g_activeZone);
         PrintFormat("[PH1] Leg accepted: %s start=%d end=%d high=%.5f low=%.5f range=%.5f ATR=%.5f",
                     g_activeLeg.bullish ? "BULL" : "BEAR",
                     g_activeLeg.startIndex,
                     g_activeLeg.endIndex,
                     g_activeLeg.legHigh,
                     g_activeLeg.legLow,
                     g_activeLeg.legRange,
                     g_activeLeg.atr);
         // Log zone bounds so verify_phase1_zones.py can check the math.
         PrintFormat("[PH1] Zone: upper=%.5f lower=%.5f fib050=%.5f fib0618=%.5f invLevel=%.5f dir=%s",
                     g_activeZone.zoneUpper,
                     g_activeZone.zoneLower,
                     g_activeZone.fib050,
                     g_activeZone.fib0618,
                     g_activeZone.invalidationLevel,
                     g_activeZone.bullish ? "BULL" : "BEAR");
         // Write CSV row in tester for offline verification.
         if(g_ph1File != INVALID_HANDLE)
            FileWrite(g_ph1File,
                      TimeToString(g_activeZone.endBarTime, TIME_DATE|TIME_MINUTES),
                      g_activeZone.bullish ? "BULL" : "BEAR",
                      g_activeLeg.legHigh, g_activeLeg.legLow, g_activeLeg.legRange,
                      g_activeZone.fib050, g_activeZone.fib0618,
                      g_activeZone.zoneUpper, g_activeZone.zoneLower,
                      g_activeZone.invalidationLevel);
        }
     }
   else
     {
      g_activeLeg.valid = false;
      Fib_Reset(g_activeZone);
      PrintFormat("[PH1] Leg rejected: %s",rejectReason);
     }

   if(g_activeZone.valid)
     {
      string invalidReason;
      if(Fib_CheckInvalidation(g_activeZone, MaxLegAgeBars, g_close, invalidReason))
        {
         PrintFormat("[PH1] Zone invalidated: %s", invalidReason);
         g_hasInvalidatedLeg  = true;
         g_invalidatedBullish = g_activeLeg.bullish;
         g_invalidatedStart   = g_activeLeg.startBarTime;
         g_invalidatedEnd     = g_activeLeg.endBarTime;
         g_activeLeg.valid = false;
         Fib_Reset(g_activeZone);
        }
      else
         Viz_DrawFibZone(MagicNumber, g_activeZone, g_time);
     }
   else
      Viz_DrawFibZone(MagicNumber, g_activeZone, g_time);

//--- TODO Phase 2: rebuild volume profile (new bar ONLY, never per tick)
//--- TODO Phase 3: engulfing detection
//--- TODO Phase 4: confluence score + journal row (including rejections)
//--- TODO Phase 5: five safety gates, then execute
  }

//+------------------------------------------------------------------+
//| Timer - notification queue flush (SPEC §10.3)                    |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- TODO Phase 8: flush one queued Telegram message
//--- WebRequest is blocking. Never call it from OnTick's trade path.
  }

//+------------------------------------------------------------------+
//| Chart events - panel drag and collapse (SPEC §9.2, §9.3)         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//--- TODO Phase 7: CHARTEVENT_MOUSE_MOVE  -> drag with bounds clamping
//--- TODO Phase 7: CHARTEVENT_OBJECT_CLICK -> collapse toggle
  }

//+------------------------------------------------------------------+
//| Trade transactions                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
//--- TODO Phase 5/6: filter by MagicNumber, track fills and closes
//--- TODO Phase 8: notify trade opened / TP1 / closed / stopped
  }

//+------------------------------------------------------------------+
//| New bar detection                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(t == g_lastBarTime)
      return(false);
   g_lastBarTime = t;
   return(true);
  }
//+------------------------------------------------------------------+
