//+------------------------------------------------------------------+
//|                                                        Bands.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Bollinger Bands"
#property strict

#include <MovingAverages.mqh>

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 LightSeaGreen
#property indicator_color2 LightSeaGreen
#property indicator_color3 LightSeaGreen
//--- indicator parameters
input int    InpBandsPeriod = 20;
input int    InpBandsShift = 0;
input double InpBandsDeviations = 0.3;
//--- buffers
double ExtMovingBuffer[];
double ExtUpperBuffer[];
double ExtLowerBuffer[];
double ExtStdDevBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- 1 additional buffer used for counting.
   IndicatorBuffers(4);
   IndicatorDigits(Digits);
//--- middle line
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtMovingBuffer);
   SetIndexShift(0,InpBandsShift);
   SetIndexLabel(0,"Bands SMA");
//--- upper band
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1,ExtUpperBuffer);
   SetIndexShift(1,InpBandsShift);
   SetIndexLabel(1,"Bands Upper");
//--- lower band
   SetIndexStyle(2,DRAW_LINE);
   SetIndexBuffer(2,ExtLowerBuffer);
   SetIndexShift(2,InpBandsShift);
   SetIndexLabel(2,"Bands Lower");
//--- work buffer
   SetIndexBuffer(3,ExtStdDevBuffer);
//--- check for input parameter
   if(InpBandsPeriod<=0)
     {
      Print("Wrong input parameter Bands Period=",InpBandsPeriod);
      return(INIT_FAILED);
     }
//---
   SetIndexDrawBegin(0,InpBandsPeriod+InpBandsShift);
   SetIndexDrawBegin(1,InpBandsPeriod+InpBandsShift);
   SetIndexDrawBegin(2,InpBandsPeriod+InpBandsShift);
//--- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Bollinger Bands                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int i,pos;
//---
   if(rates_total<=InpBandsPeriod || InpBandsPeriod<=0)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtMovingBuffer,false);
   ArraySetAsSeries(ExtUpperBuffer,false);
   ArraySetAsSeries(ExtLowerBuffer,false);
   ArraySetAsSeries(ExtStdDevBuffer,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);
//--- initial zero
   if(prev_calculated<1)
     {
      for(i=0; i<InpBandsPeriod; i++)
        {
         ExtMovingBuffer[i]=EMPTY_VALUE;
         ExtUpperBuffer[i]=EMPTY_VALUE;
         ExtLowerBuffer[i]=EMPTY_VALUE;
        }
     }
//--- starting calculation
   if(prev_calculated>1)
    {
      pos=prev_calculated-1;
    }
   else
      pos=0;
//--- main cycle
   for(i = pos; i < rates_total && !IsStopped(); i++) {
      ExtMovingBuffer[i] = 0;
      ExtStdDevBuffer[i] = 0;
      ExtUpperBuffer [pos] = Ask + iStdDev(NULL, 0, InpBandsPeriod, 0, MODE_SMA, PRICE_TYPICAL, 0) * 2;
      ExtLowerBuffer [pos] = Bid - iStdDev(NULL, 0, InpBandsPeriod, 0, MODE_SMA, PRICE_TYPICAL, 0) * 2;
     }
//---- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
double StdDev_Func(int position,const double &price[],const double &MAprice[],int period)
  {
//--- variables
   double StdDev_dTmp=0.0;
//--- check for position
   if(position>=period)
     {
      //--- calcualte StdDev
      for(int i=0; i<period; i++)
         StdDev_dTmp+=MathPow(price[position-i]-MAprice[position],2);
      StdDev_dTmp=MathSqrt(StdDev_dTmp/period);
     }
//--- return calculated value
   return(StdDev_dTmp);
  }
//+------------------------------------------------------------------+
