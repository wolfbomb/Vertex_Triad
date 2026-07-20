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
#property version   "0.01"
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

//--- TODO Phase 1-8: remaining inputs per SPEC

//+------------------------------------------------------------------+
//| Global state                                                     |
//+------------------------------------------------------------------+
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- TODO Phase 0: validate inputs, symbol specs
//--- TODO Phase 7: ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
//--- TODO Phase 7: restore panel position/collapse from GlobalVariable
//--- TODO Phase 8: Telegram init test, detect error 4014

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

//--- New bar: full evaluation (closed bars only - repainting boundary)
//--- TODO Phase 1: detect impulse leg, build/invalidate Golden Zone
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
