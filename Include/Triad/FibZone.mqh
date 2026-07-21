//+------------------------------------------------------------------+
//| FibZone.mqh
//| VERTEX_Triad - Zone construction, invalidation tracking
//| Implemented in Phase 1. See SPEC.md.
//+------------------------------------------------------------------+
#property strict

// Function prefix for this module: Fib_
// Self-contained module. No cross-module global state.

struct FibZoneState
	{
	 bool     valid;
	 bool     bullish;
	 int      startIndex;
	 int      endIndex;
	 double   legHigh;
	 double   legLow;
	 double   fib050;
	 double   fib0618;
	 double   zoneLower;
	 double   zoneUpper;
	 double   invalidationLevel;
	 datetime endBarTime;
	};

void Fib_Reset(FibZoneState &zone)
	{
	 zone.valid = false;
	 zone.bullish = true;
	 zone.startIndex = -1;
	 zone.endIndex = -1;
	 zone.legHigh = 0.0;
	 zone.legLow = 0.0;
	 zone.fib050 = 0.0;
	 zone.fib0618 = 0.0;
	 zone.zoneLower = 0.0;
	 zone.zoneUpper = 0.0;
	 zone.invalidationLevel = 0.0;
	 zone.endBarTime = 0;
	}

void Fib_BuildFromLeg(const SwingImpulseLeg &leg,const double fibInvalidation,FibZoneState &zone)
	{
	 Fib_Reset(zone);
	 if(!leg.valid)
			return;

	 const double range = leg.legHigh - leg.legLow;
	 if(range <= 0.0)
			return;

	 zone.valid = true;
	 zone.bullish = leg.bullish;
	 zone.startIndex = leg.startIndex;
	 zone.endIndex = leg.endIndex;
	 zone.legHigh = leg.legHigh;
	 zone.legLow = leg.legLow;
	 zone.endBarTime = leg.endBarTime;

	 if(leg.bullish)
		 {
			zone.fib050 = zone.legHigh - 0.500 * range;
			zone.fib0618 = zone.legHigh - 0.618 * range;
			zone.zoneLower = MathMin(zone.fib050,zone.fib0618);
			zone.zoneUpper = MathMax(zone.fib050,zone.fib0618);
			zone.invalidationLevel = zone.legHigh - fibInvalidation * range;
		 }
	 else
		 {
			zone.fib050 = zone.legLow + 0.500 * range;
			zone.fib0618 = zone.legLow + 0.618 * range;
			zone.zoneLower = MathMin(zone.fib050,zone.fib0618);
			zone.zoneUpper = MathMax(zone.fib050,zone.fib0618);
			zone.invalidationLevel = zone.legLow + fibInvalidation * range;
		 }
	}

bool Fib_IsPriceInsideZone(const FibZoneState &zone,const double price)
	{
	 if(!zone.valid)
			return(false);
	 return(price >= zone.zoneLower && price <= zone.zoneUpper);
	}

// Check three SPEC §2.3 invalidation conditions: age, 0.786 breach, full retrace.
// _close[] must be a series array (index 1 = last closed bar).
bool Fib_CheckInvalidation(const FibZoneState &zone,
                           const int maxLegAgeBars,
                           const double &_close[],
                           string &reason)
  {
   reason = "";
   if(!zone.valid)
     {
      reason = "zone not valid";
      return(true);
     }

   if(zone.endIndex > maxLegAgeBars)
     {
      reason = StringFormat("age expiry: %d > %d", zone.endIndex, maxLegAgeBars);
      return(true);
     }

   if(ArraySize(_close) < 2)
     {
      reason = "close array too small";
      return(true);
     }

   const double c1 = _close[1];   // last CLOSED bar (series order, SPEC §2 repainting rule)
   if(zone.bullish)
     {
      if(c1 < zone.invalidationLevel)
        {
         reason = StringFormat("0.786 breach: close=%.5f < %.5f", c1, zone.invalidationLevel);
         return(true);
        }
      if(c1 < zone.legLow)
        {
         reason = StringFormat("full retrace: close=%.5f < legLow=%.5f", c1, zone.legLow);
         return(true);
        }
     }
   else
     {
      if(c1 > zone.invalidationLevel)
        {
         reason = StringFormat("0.786 breach: close=%.5f > %.5f", c1, zone.invalidationLevel);
         return(true);
        }
      if(c1 > zone.legHigh)
        {
         reason = StringFormat("full retrace: close=%.5f > legHigh=%.5f", c1, zone.legHigh);
         return(true);
        }
     }

   return(false);
  }

