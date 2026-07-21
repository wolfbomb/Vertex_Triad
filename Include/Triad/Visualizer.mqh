//+------------------------------------------------------------------+
//| Visualizer.mqh
//| VERTEX_Triad - Chart objects: zone, POC/HVN, signal markers
//| Implemented in Phase 1. See SPEC.md.
//+------------------------------------------------------------------+
#property strict

// Function prefix for this module: Viz_
// Self-contained module. No cross-module global state.

string Viz_Prefix(const long magic)
	{
	 return(StringFormat("VTX_FIB_%I64d_",magic));
	}

void Viz_DeleteByPrefix(const string prefix)
	{
	 for(int i = ObjectsTotal(0,0,-1) - 1; i >= 0; --i)
		 {
			const string name = ObjectName(0,i,0,-1);
			if(StringFind(name,prefix) == 0)
				 ObjectDelete(0,name);
		 }
	}

void Viz_ClearPhase1(const long magic)
	{
	 Viz_DeleteByPrefix(Viz_Prefix(magic));
	}

// Draw (or clear) the fib zone and impulse leg on the chart.
// _time[] is the series time array passed from the EA (MQL5 has no global Time[]).
void Viz_DrawFibZone(const long magic,
                     const FibZoneState &zone,
                     const datetime &_time[])
  {
   const string prefix    = Viz_Prefix(magic);
   const string upperName = prefix + "upper";
   const string lowerName = prefix + "lower";
   const string legName   = prefix + "leg";

   if(!zone.valid)
     {
      ObjectDelete(0, upperName);
      ObjectDelete(0, lowerName);
      ObjectDelete(0, legName);
      return;
     }

   const color zoneColor = zone.bullish ? clrMediumSeaGreen : clrIndianRed;

   if(ObjectFind(0, upperName) < 0)
      ObjectCreate(0, upperName, OBJ_HLINE, 0, 0, zone.zoneUpper);
   ObjectSetDouble(0,  upperName, OBJPROP_PRICE, zone.zoneUpper);
   ObjectSetInteger(0, upperName, OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, upperName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 1);

   if(ObjectFind(0, lowerName) < 0)
      ObjectCreate(0, lowerName, OBJ_HLINE, 0, 0, zone.zoneLower);
   ObjectSetDouble(0,  lowerName, OBJPROP_PRICE, zone.zoneLower);
   ObjectSetInteger(0, lowerName, OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, lowerName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 1);

   const int timeSize = ArraySize(_time);
   if(zone.startIndex < timeSize && zone.endIndex < timeSize)
     {
      const datetime t1 = _time[zone.startIndex];
      const datetime t2 = _time[zone.endIndex];
      const double   p1 = zone.bullish ? zone.legLow  : zone.legHigh;
      const double   p2 = zone.bullish ? zone.legHigh : zone.legLow;

      if(ObjectFind(0, legName) < 0)
         ObjectCreate(0, legName, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectMove(0,    legName, 0, t1, p1);
      ObjectMove(0,    legName, 1, t2, p2);
      ObjectSetInteger(0, legName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, legName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, legName, OBJPROP_WIDTH, 1);
     }
  }

