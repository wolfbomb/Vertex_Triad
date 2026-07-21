//+------------------------------------------------------------------+
//| SwingDetector.mqh
//| VERTEX_Triad - Fractal swings, impulse leg qualification
//| Implemented in Phase 1. See SPEC §2.
//+------------------------------------------------------------------+
#property strict

// Function prefix for this module: Swing_
// Self-contained module. No cross-module global state.
// MQL5 note: price arrays (High/Low/Open/Close/Time) are not global in MQL5.
// All functions that need OHLCV data accept them as const-ref array parameters.

struct SwingConfig
  {
   int    lookback;           // bars each side for fractal (SPEC §2.1)
   double minLegAtr;          // minimum leg size in ATR multiples
   double minImpulseBodyRatio;// fraction of bars closing in leg direction
   int    maxLegAgeBars;      // maximum age of terminating swing point
   double maxInternalRetrace; // maximum retrace fraction allowed within leg
  };

struct SwingImpulseLeg
  {
   bool     valid;
   bool     bullish;
   int      startIndex;       // older end (bar index, series order)
   int      endIndex;         // newer end (smaller index = more recent)
   double   legHigh;
   double   legLow;
   double   legRange;
   double   atr;              // ATR(14) at leg terminus
   double   momentumRatio;
   double   maxInternalRetrace;
   datetime endBarTime;
  };

// ATR(14) calculated from provided high/low/close arrays. SPEC §2.1 filter.
double Swing_CalcAtr(const int period,
                     const int shift,
                     const double &_high[],
                     const double &_low[],
                     const double &_close[])
  {
   if(period <= 0 || shift < 1)
      return(0.0);

   const int arrSize = ArraySize(_high);
   if(arrSize <= shift + period + 1)
      return(0.0);

   double trSum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double h = _high[i];
      const double l = _low[i];
      const double prevClose = _close[i + 1];
      const double tr1 = h - l;
      const double tr2 = MathAbs(h - prevClose);
      const double tr3 = MathAbs(l - prevClose);
      trSum += MathMax(tr1, MathMax(tr2, tr3));
     }

   return(trSum / period);
  }

bool Swing_IsSwingHigh(const int index,
                       const int lookback,
                       const double &_high[])
  {
   const int arrSize = ArraySize(_high);
   if(index < lookback + 1 || index + lookback >= arrSize)
      return(false);

   for(int k = 1; k <= lookback; ++k)
     {
      if(_high[index] <= _high[index - k])
         return(false);
      if(_high[index] <= _high[index + k])
         return(false);
     }

   return(true);
  }

bool Swing_IsSwingLow(const int index,
                      const int lookback,
                      const double &_low[])
  {
   const int arrSize = ArraySize(_low);
   if(index < lookback + 1 || index + lookback >= arrSize)
      return(false);

   for(int k = 1; k <= lookback; ++k)
     {
      if(_low[index] >= _low[index - k])
         return(false);
      if(_low[index] >= _low[index + k])
         return(false);
     }

   return(true);
  }

// Qualify a candidate leg from startIndex (older) to endIndex (newer).
// All four SPEC §2.1 filters are applied in order; first failure returns.
bool Swing_QualifyLeg(const SwingConfig &cfg,
                      const bool bullish,
                      const int startIndex,
                      const int endIndex,
                      const double &_high[],
                      const double &_low[],
                      const double &_close[],
                      const double &_open[],
                      const datetime &_time[],
                      SwingImpulseLeg &outLeg,
                      string &rejectReason)
  {
   outLeg.valid = false;
   rejectReason = "";

   if(startIndex <= endIndex || endIndex < 1)
     {
      rejectReason = "invalid indices";
      return(false);
     }

   const int arrSize = ArraySize(_high);
   if(startIndex >= arrSize || endIndex + 1 >= arrSize)
     {
      rejectReason = "array bounds";
      return(false);
     }

   outLeg.bullish    = bullish;
   outLeg.startIndex = startIndex;
   outLeg.endIndex   = endIndex;
   outLeg.legHigh    = _high[startIndex];
   outLeg.legLow     = _low[startIndex];

   int    directionalBars = 0;
   int    totalBars       = 0;
   double maxRetrace      = 0.0;

   if(bullish)
     {
      double peak = -DBL_MAX;
      for(int i = startIndex; i >= endIndex; --i)
        {
         outLeg.legHigh = MathMax(outLeg.legHigh, _high[i]);
         outLeg.legLow  = MathMin(outLeg.legLow,  _low[i]);

         if(_close[i] > _open[i])
            directionalBars++;
         totalBars++;

         peak = MathMax(peak, _high[i]);
         if(peak > -DBL_MAX / 2.0)
           {
            const double retrace = peak - _low[i];
            maxRetrace = MathMax(maxRetrace, retrace);
           }
        }
     }
   else
     {
      double trough = DBL_MAX;
      for(int i = startIndex; i >= endIndex; --i)
        {
         outLeg.legHigh = MathMax(outLeg.legHigh, _high[i]);
         outLeg.legLow  = MathMin(outLeg.legLow,  _low[i]);

         if(_close[i] < _open[i])
            directionalBars++;
         totalBars++;

         trough = MathMin(trough, _low[i]);
         if(trough < DBL_MAX / 2.0)
           {
            const double retrace = _high[i] - trough;
            maxRetrace = MathMax(maxRetrace, retrace);
           }
        }
     }

   outLeg.legRange = outLeg.legHigh - outLeg.legLow;
   if(outLeg.legRange <= 0.0)
     {
      rejectReason = "zero leg range";
      return(false);
     }

   // Filter 3 (recency) checked before ATR to short-circuit early.
   if(outLeg.endIndex > cfg.maxLegAgeBars)
     {
      rejectReason = StringFormat("recency fail: age=%d > max=%d", outLeg.endIndex, cfg.maxLegAgeBars);
      return(false);
     }

   // Filter 1: minimum size (SPEC §2.1)
   outLeg.atr = Swing_CalcAtr(14, endIndex, _high, _low, _close);
   if(outLeg.atr <= 0.0)
     {
      rejectReason = "ATR unavailable";
      return(false);
     }

   if(outLeg.legRange < cfg.minLegAtr * outLeg.atr)
     {
      rejectReason = StringFormat("size fail: range=%.5f < %.5f", outLeg.legRange, cfg.minLegAtr * outLeg.atr);
      return(false);
     }

   // Filter 2: momentum (SPEC §2.1)
   outLeg.momentumRatio = (totalBars > 0) ? ((double)directionalBars / (double)totalBars) : 0.0;
   if(outLeg.momentumRatio < cfg.minImpulseBodyRatio)
     {
      rejectReason = StringFormat("momentum fail: %.3f < %.3f", outLeg.momentumRatio, cfg.minImpulseBodyRatio);
      return(false);
     }

   // Filter 4: cleanliness (SPEC §2.1)
   outLeg.maxInternalRetrace = maxRetrace / outLeg.legRange;
   if(outLeg.maxInternalRetrace > cfg.maxInternalRetrace)
     {
      rejectReason = StringFormat("cleanliness fail: %.3f > %.3f", outLeg.maxInternalRetrace, cfg.maxInternalRetrace);
      return(false);
     }

   outLeg.endBarTime = _time[endIndex];
   outLeg.valid = true;
   return(true);
  }

// Scan for the most recent qualified impulse leg. Returns false if none found.
// Scans both bullish and bearish candidates; returns whichever has the most
// recent (smallest) endIndex (= closest to current bar). SPEC §2.1.
bool Swing_FindLatestQualifiedLeg(const SwingConfig &cfg,
                                  const double &_high[],
                                  const double &_low[],
                                  const double &_close[],
                                  const double &_open[],
                                  const datetime &_time[],
                                  SwingImpulseLeg &outLeg,
                                  string &rejectReason)
  {
   outLeg.valid = false;
   rejectReason = "";

   const int arrSize = ArraySize(_high);
   if(arrSize < (cfg.lookback * 4 + 20))
     {
      rejectReason = "insufficient bars";
      return(false);
     }

   const int scanStart = cfg.lookback + 1;
   const int scanEnd   = MathMin(arrSize - cfg.lookback - 2,
                                  cfg.maxLegAgeBars + cfg.lookback + 80);

   int swingHighs[];
   int swingLows[];

   for(int i = scanStart; i <= scanEnd; ++i)
     {
      if(Swing_IsSwingHigh(i, cfg.lookback, _high))
        {
         const int n = ArraySize(swingHighs);
         ArrayResize(swingHighs, n + 1);
         swingHighs[n] = i;
        }
      if(Swing_IsSwingLow(i, cfg.lookback, _low))
        {
         const int n = ArraySize(swingLows);
         ArrayResize(swingLows, n + 1);
         swingLows[n] = i;
        }
     }

   SwingImpulseLeg bestLeg;
   bestLeg.valid    = false;
   int    bestEnd   = INT_MAX;
   string lastReject = "no candidate";

   // Bullish: low (older, larger index) -> high (newer, smaller index)
   for(int h = 0; h < ArraySize(swingHighs); ++h)
     {
      const int endHigh = swingHighs[h];
      int startLow = -1;
      for(int l = 0; l < ArraySize(swingLows); ++l)
        {
         if(swingLows[l] > endHigh)
           {
            startLow = swingLows[l];
            break;
           }
        }

      if(startLow > endHigh)
        {
         SwingImpulseLeg candidate;
         string reason;
         if(Swing_QualifyLeg(cfg, true, startLow, endHigh,
                             _high, _low, _close, _open, _time,
                             candidate, reason))
           {
            if(candidate.endIndex < bestEnd)
              {
               bestEnd = candidate.endIndex;
               bestLeg = candidate;
              }
           }
         else
            lastReject = "bull " + reason;
        }
     }

   // Bearish: high (older, larger index) -> low (newer, smaller index)
   for(int l = 0; l < ArraySize(swingLows); ++l)
     {
      const int endLow = swingLows[l];
      int startHigh = -1;
      for(int h = 0; h < ArraySize(swingHighs); ++h)
        {
         if(swingHighs[h] > endLow)
           {
            startHigh = swingHighs[h];
            break;
           }
        }

      if(startHigh > endLow)
        {
         SwingImpulseLeg candidate;
         string reason;
         if(Swing_QualifyLeg(cfg, false, startHigh, endLow,
                             _high, _low, _close, _open, _time,
                             candidate, reason))
           {
            if(candidate.endIndex < bestEnd)
              {
               bestEnd = candidate.endIndex;
               bestLeg = candidate;
              }
           }
         else
            lastReject = "bear " + reason;
        }
     }

   if(bestLeg.valid)
     {
      outLeg = bestLeg;
      return(true);
     }

   rejectReason = lastReject;
   return(false);
  }
