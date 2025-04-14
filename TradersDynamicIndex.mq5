//+------------------------------------------------------------------+
//|                                          TradersDynamicIndex.mq5 |
//|                                      Copyright © 2025, EarnForex |
//|                                        https://www.earnforex.com |
//|                         Based on indicator by Dean Malone (2006) |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2025"
#property link      "https://www.earnforex.com/metatrader-indicators/Traders-Dynamic-Index/"
#property version   "1.08"

#property description "Shows trend direction, strength, and volatility."
#property description "Green line  - RSI Price line."
#property description "Red line    - Trade Signal line."
#property description "Blue lines  - Volatility Band."
#property description "Yellow line - Market Base line."

#property indicator_separate_window
#property indicator_buffers 12 // 6 + 6 possible with upper timeframe.
#property indicator_plots   5
#property indicator_level1 32
#property indicator_level2 50
#property indicator_level3 68
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1
#property indicator_color1 clrMediumBlue
#property indicator_label1 "VB High"
#property indicator_type1  DRAW_LINE
#property indicator_color2 clrYellow
#property indicator_label2 "Market Base Line"
#property indicator_type2  DRAW_LINE
#property indicator_width2 2
#property indicator_color3 clrMediumBlue
#property indicator_label3 "VB Low"
#property indicator_type3  DRAW_LINE
#property indicator_color4 clrGreen
#property indicator_label4 "RSI Price Line"
#property indicator_type4  DRAW_LINE
#property indicator_width4 2
#property indicator_color5 clrRed
#property indicator_label5 "Trade Signal Line"
#property indicator_type5  DRAW_LINE
#property indicator_width5 2

enum enum_arrow_type
{
    Buy,
    Sell
};

enum enum_candle_to_check
{
    Current,
    Previous
};

input group "Main";
input int RSI_Period = 13; // RSI_Period: 8-25
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE;
input int Volatility_Band = 34; // Volatility_Band: 20-40
input double StdDev = 1.6185; // Standard Deviations: 1-3
input int RSI_Price_Line = 2;
input ENUM_MA_METHOD RSI_Price_Type = MODE_SMA;
input int Trade_Signal_Line = 7;
input ENUM_MA_METHOD Trade_Signal_Type = MODE_SMA;
input ENUM_TIMEFRAMES UpperTimeframe = PERIOD_CURRENT; // UpperTimeframe: If above current will display values from  that timeframe.
input group "Alerts";
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input bool EnableArrowAlerts = false;
input bool EnableRedYellowCrossAlert = true; // EnableRedYellowCrossAlert: yellow/red lines alerts.
input bool EnableHookAlert = false; // EnableHookAlert: Enable green line hook alerts.
input bool EnableGreenRedCrossAlert = false; // EnableGreenRedCrossAlert: green/red lines alerts.
input bool EnableGreenRedCrossWithYellowAlert = false; // EnableGreenRedCrossWithYellowAlert: green/red with yellow lines alerts.
input bool EnableYellowGreenCrossAlert = false; // EnableYellowGreenCrossAlert: yellow/green lines alerts.
input enum_candle_to_check TriggerCandle = Previous;
input group "Arrows";
input color RedYellowCrossArrowBullishColor = clrGreen;
input color RedYellowCrossArrowBearishColor = clrRed;
input color HookArrowBullishColor = clrGreen;
input color HookArrowBearishColor = clrRed;
input color GreenRedCrossArrowBullishColor = clrGreen;
input color GreenRedCrossArrowBearishColor = clrRed;
input color YellowGreenCrossArrowBullishColor = clrGreen;
input color YellowGreenCrossArrowBearishColor = clrRed;
input uchar RedYellowCrossArrowBullishCode = 233;
input uchar RedYellowCrossArrowBearishCode = 234;
input uchar HookArrowBullishCode = 71;
input uchar HookArrowBearishCode = 72;
input uchar GreenRedCrossArrowBullishCode = 200;
input uchar GreenRedCrossArrowBearishCode = 201;
input uchar YellowGreenCrossArrowBullishCode = 226;
input uchar YellowGreenCrossArrowBearishCode = 225;
input int ArrowSize = 1;
input string ArrowPrefix = "TDI-";

double RSIBuf[], UpZone[], MdZone[], DnZone[], MaBuf[], MbBuf[];
double _RSIBuf[], _UpZone[], _MdZone[], _DnZone[], _MaBuf[], _MbBuf[]; // For upper timeframe data.

int MaxPeriod = 0;

datetime AlertPlayed = 0, HookAlertPlayed = 0, RedGreenAlertPlayed = 0, YellowGreenAlertPlayed = 0;

int RSI_handle;

int OnInit()
{
    if (PeriodSeconds(UpperTimeframe) < PeriodSeconds())
    {
        Print("Upper timeframe cannot be lower than the current timeframe.");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    IndicatorSetString(INDICATOR_SHORTNAME, "TDI (" + IntegerToString(RSI_Period) + "," + IntegerToString(Volatility_Band) + "," + IntegerToString(RSI_Price_Line) + "," + IntegerToString(Trade_Signal_Line) +  ")");

    SetIndexBuffer(0, UpZone, INDICATOR_DATA);
    SetIndexBuffer(1, MdZone, INDICATOR_DATA);
    SetIndexBuffer(2, DnZone, INDICATOR_DATA);
    SetIndexBuffer(3, MaBuf, INDICATOR_DATA);
    SetIndexBuffer(4, MbBuf, INDICATOR_DATA);
    SetIndexBuffer(5, RSIBuf, INDICATOR_CALCULATIONS);

    ArraySetAsSeries(UpZone, true);
    ArraySetAsSeries(MdZone, true);
    ArraySetAsSeries(DnZone, true);
    ArraySetAsSeries(MaBuf, true);
    ArraySetAsSeries(MbBuf, true);
    ArraySetAsSeries(RSIBuf, true);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0);

    if (PeriodSeconds(UpperTimeframe) != PeriodSeconds(Period()))
    {
        SetIndexBuffer(6, _RSIBuf, INDICATOR_CALCULATIONS);
        SetIndexBuffer(7, _UpZone, INDICATOR_CALCULATIONS);
        SetIndexBuffer(8, _MdZone, INDICATOR_CALCULATIONS);
        SetIndexBuffer(9, _DnZone, INDICATOR_CALCULATIONS);
        SetIndexBuffer(10, _MaBuf, INDICATOR_CALCULATIONS);
        SetIndexBuffer(11, _MbBuf, INDICATOR_CALCULATIONS);
        ArraySetAsSeries(_UpZone, true);
        ArraySetAsSeries(_MdZone, true);
        ArraySetAsSeries(_DnZone, true);
        ArraySetAsSeries(_MaBuf, true);
        ArraySetAsSeries(_MbBuf, true);
        ArraySetAsSeries(_RSIBuf, true);
    }

    IndicatorSetInteger(INDICATOR_DIGITS, 1);

    RSI_handle = iRSI(Symbol(), UpperTimeframe, RSI_Period, RSI_Price);

    MaxPeriod = Volatility_Band + RSI_Period;

    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MaxPeriod);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, MaxPeriod);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, MaxPeriod);
    PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, MaxPeriod + RSI_Price_Line);
    PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, MaxPeriod + Trade_Signal_Line);
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), ArrowPrefix, 0, OBJ_ARROW);
}

int OnCalculate(const int        rates_total,
                const int        prev_calculated,
                const datetime&  Time[],
                const double&    open[],
                const double&    High[],
                const double&    Low[],
                const double&    close[],
                const long&      tick_volume[],
                const long&      volume[],
                const int&       spread[]
               )
{
    ArraySetAsSeries(Time, true);
    ArraySetAsSeries(Low, true);
    ArraySetAsSeries(High, true);

    int counted_bars = prev_calculated;
    if (counted_bars > 0) counted_bars--;

    // Too few bars to work with.
    if (rates_total < MaxPeriod) return 0;

    int limit = rates_total - 1 - counted_bars;
    if (limit > rates_total - MaxPeriod - 1) limit = rates_total - MaxPeriod - 1;

    if (PeriodSeconds(UpperTimeframe) == PeriodSeconds(Period()))
    {
        if (FillIndicatorBuffers((ENUM_TIMEFRAMES)Period(), limit, RSIBuf, UpZone, DnZone, MdZone, MaBuf, MbBuf) == -1) return 0; // No RSI data yet.
    }
    else
    {
        static int upper_prev_counted = 0;
        if (upper_prev_counted > 0) upper_prev_counted--;
        int upper_limit = iBars(Symbol(), UpperTimeframe) - 1 - upper_prev_counted;
        if (upper_limit > iBars(Symbol(), UpperTimeframe) - MaxPeriod - 1) upper_limit = iBars(Symbol(), UpperTimeframe) - MaxPeriod - 1;
        if (upper_limit > rates_total - Volatility_Band) upper_limit = rates_total - Volatility_Band; // Buffers cannot hold more than the current period's bars worth of data!
        upper_prev_counted = FillIndicatorBuffers(UpperTimeframe, upper_limit, _RSIBuf, _UpZone, _DnZone, _MdZone, _MaBuf, _MbBuf);
        if (upper_prev_counted == -1) return 0; // No RSI data yet.
        for (int i = 0, j = 0; Time[i] >= iTime(Symbol(), UpperTimeframe, upper_limit); i++)
        {
            while ((iTime(Symbol(), UpperTimeframe, j) > Time[i]) && (j < iBars(Symbol(), UpperTimeframe))) j++;
            if (j >= iBars(Symbol(), UpperTimeframe)) break;
            RSIBuf[i] = _RSIBuf[j];
            UpZone[i] = _UpZone[j];
            DnZone[i] = _DnZone[j];
            MdZone[i] = _MdZone[j];
            MaBuf[i] = _MaBuf[j];
            MbBuf[i] = _MbBuf[j];
            if (i + 1 == rates_total) break;
        }
    }

    if (EnableRedYellowCrossAlert)
    {
        if ((MbBuf[TriggerCandle] > MdZone[TriggerCandle]) && (MbBuf[TriggerCandle + 1] <= MdZone[TriggerCandle + 1]) && (AlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Bullish cross");
            if (EnableEmailAlerts)
            {
                SendMail("TDI Alert: BUY " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Alert: BUY " + _Symbol + " @ " + PeriodToString(_Period));
            AlertPlayed = Time[0];
        }
        if ((MbBuf[TriggerCandle] < MdZone[TriggerCandle]) && (MbBuf[TriggerCandle + 1] >= MdZone[TriggerCandle + 1]) && (AlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Bearish cross");
            if (EnableEmailAlerts)
            {
                SendMail("TDI Alert: SELL " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Alert: SELL " + _Symbol + " @ " + PeriodToString(_Period));
            AlertPlayed = Time[0];
        }
    }

    if (EnableHookAlert)
    {
        // Green line crosses upper blue line from above when both are above level 68.
        if ((MaBuf[TriggerCandle] < UpZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= UpZone[TriggerCandle + 1]) && ((MaBuf[TriggerCandle] > 68) || (MaBuf[TriggerCandle + 1] > 68)) && ((UpZone[TriggerCandle] > 68) || (UpZone[TriggerCandle + 1] > 68)) && (HookAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Bearish Hook");
            if (EnableEmailAlerts)
            {
                SendMail("TDI Hook Alert: SELL " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Hook Alert: SELL " + _Symbol + " @ " + PeriodToString(_Period));
            HookAlertPlayed = Time[0];
        }
        // Green line crosses lower blue line from below when both are below level 32.
        else if ((MaBuf[TriggerCandle] > DnZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= DnZone[TriggerCandle + 1]) && ((MaBuf[TriggerCandle] < 32) || (MaBuf[TriggerCandle + 1] < 32)) && ((DnZone[TriggerCandle] < 32) || (DnZone[TriggerCandle + 1] < 32)) && (HookAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Bullish Hook");
            if (EnableEmailAlerts)
            {
                SendMail("TDI Hook Alert: BUY " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Hook Alert: BUY " + _Symbol + " @ " + PeriodToString(_Period));
            HookAlertPlayed = Time[0];
        }
    }

    if (EnableGreenRedCrossAlert)
    {
        // Green line crosses red one from above.
        if ((MaBuf[TriggerCandle] < MbBuf[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= MbBuf[TriggerCandle + 1]) && (RedGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Green line crossed red one from above");
            if (EnableEmailAlerts)
            {
                SendMail("TDI: Green line crossed red one from above - " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed red one from above - " + _Symbol + " @ " + PeriodToString(_Period));
            RedGreenAlertPlayed = Time[0];
        }
        // Green line crosses red one from below.
        else if ((MaBuf[TriggerCandle] > MbBuf[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= MbBuf[TriggerCandle + 1]) && (RedGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Green line crossed red one from below");
            if (EnableEmailAlerts)
            {
                SendMail("TDI: Green line crossed red one from below - " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed red one from below - " + _Symbol + " @ " + PeriodToString(_Period));
            RedGreenAlertPlayed = Time[0];
        }
    }

    if (EnableGreenRedCrossWithYellowAlert)
    {
        // Green line crosses red one from above and both are below the yellow line.
        if ((MaBuf[TriggerCandle] < MbBuf[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= MbBuf[TriggerCandle + 1]) && (MaBuf[TriggerCandle] < MdZone[TriggerCandle]) && (MbBuf[TriggerCandle] < MdZone[TriggerCandle]) && (RedGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Green line crossed red one from above while both below yellow");
            if (EnableEmailAlerts)
            {
                SendMail("TDI: Green line crossed red one from above while both below yellow - " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed red one from above while both below yellow - " + _Symbol + " @ " + PeriodToString(_Period));
            RedGreenAlertPlayed = Time[0];
        }
        // Green line crosses red one from below and both are above the yellow line.
        else if ((MaBuf[TriggerCandle] > MbBuf[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= MbBuf[TriggerCandle + 1]) && (MaBuf[TriggerCandle] > MdZone[TriggerCandle]) && (MbBuf[TriggerCandle] > MdZone[TriggerCandle]) && (RedGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Green line crossed red one from below while both above yellow");
            if (EnableEmailAlerts)
            {
                SendMail("TDI: Green line crossed red one from below while both above yellow - " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed red one from below while both above yellow - " + _Symbol + " @ " + PeriodToString(_Period));
            RedGreenAlertPlayed = Time[0];
        }
    }

    if (EnableYellowGreenCrossAlert)
    {
        // Green line crosses yellow one from above.
        if ((MaBuf[TriggerCandle] < MdZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= MdZone[TriggerCandle + 1]) && (YellowGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Green line crossed yellow one from above");
            if (EnableEmailAlerts)
            {
                SendMail("TDI: Green line crossed yellow one from above - " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed yellow one from above - " + _Symbol + " @ " + PeriodToString(_Period));
            YellowGreenAlertPlayed = Time[0];
        }
        // Green line crosses yellow one from below.
        else if ((MaBuf[TriggerCandle] > MdZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= MdZone[TriggerCandle + 1]) && (YellowGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert("Green line crossed yellow one from below");
            if (EnableEmailAlerts)
            {
                SendMail("TDI: Green line crossed yellow one from below - " + _Symbol + " @ " + PeriodToString(_Period), "Current rate = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "/" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed yellow one from below - " + _Symbol + " @ " + PeriodToString(_Period));
            YellowGreenAlertPlayed = Time[0];
        }
    }
    
    return rates_total;
}

// Standard Deviation function.
double StDev(double& Data[], int Per)
{
    return MathSqrt(Variance(Data, Per));
}

// Math Variance function.
double Variance(double& Data[], int Per)
{
    double sum = 0, ssum = 0;
    for (int i = 0; i < Per; i++)
    {
        sum += Data[i];
        ssum += MathPow(Data[i], 2);
    }
    return ((ssum * Per - sum * sum) / (Per * (Per - 1)));
}

//+------------------------------------------------------------------+
//| Based on http://www.mql5.com/en/articles/81                      |
//| Simplified SMA calculation.                                      |
//+------------------------------------------------------------------+
double iMAOnArray(double &Array[], int total, int iMAPeriod, int ma_shift, ENUM_MA_METHOD ma_method, int Shift)
{
    double buf[];
    if ((total > 0) && (total <= iMAPeriod)) return(0);
    if (total == 0) total = ArraySize(Array);
    if (ArrayResize(buf, total) < 0) return(0);

    switch(ma_method)
    {
    // Simplified SMA. No longer works with ma_shift parameter.
    case MODE_SMA:
    {
        double sum = 0;
        for (int i = Shift; i < Shift + iMAPeriod; i++)
            sum += Array[i] / iMAPeriod;
        return sum;
    }
    case MODE_EMA:
    {
        double pr = 2.0 / (iMAPeriod + 1);
        int pos = total - 2;
        while (pos >= 0)
        {
            if (pos == total - 2) buf[pos + 1] = Array[pos + 1];
            buf[pos] = Array[pos] * pr + buf[pos + 1] * (1 - pr);
            pos--;
        }
        return buf[Shift + ma_shift];
    }
    case MODE_SMMA:
    {
        double sum = 0;
        int i, k, pos;
        pos = total - iMAPeriod;
        while (pos >= 0)
        {
            if (pos == total - iMAPeriod)
            {
                for (i = 0, k = pos; i < iMAPeriod; i++, k++)
                {
                    sum += Array[k];
                    buf[k] = 0;
                }
            }
            else sum = buf[pos + 1] * (iMAPeriod - 1) + Array[pos];
            buf[pos] = sum / iMAPeriod;
            pos--;
        }
        return buf[Shift + ma_shift];
    }
    case MODE_LWMA:
    {
        double sum = 0.0, lsum = 0.0;
        double price;
        int i, weight = 0, pos = total - 1;
        for (i = 1; i <= iMAPeriod; i++, pos--)
        {
            price = Array[pos];
            sum += price * i;
            lsum += price;
            weight += i;
        }
        pos++;
        i = pos + iMAPeriod;
        while (pos >= 0)
        {
            buf[pos] = sum / weight;
            if (pos == 0) break;
            pos--;
            i--;
            price = Array[pos];
            sum = sum - lsum + price * iMAPeriod;
            lsum -= Array[i];
            lsum += price;
        }
        return buf[Shift + ma_shift];
    }
    default:
        return 0;
    }
    return 0;
}

// For alerts.
string PeriodToString(const ENUM_TIMEFRAMES per)
{
    return StringSubstr(EnumToString(per), 7);
}

void PutArrow(const double price, const datetime time, enum_arrow_type dir, const color colour, const uchar arrow_code, const string text)
{
    string name = ArrowPrefix + "Arrow" + IntegerToString(arrow_code) + TimeToString(time);
    if (ObjectFind(ChartID(), name) > -1) return;
    ENUM_ARROW_ANCHOR anchor;
    if (dir == Buy)
    {
        anchor = ANCHOR_TOP;
    }
    else
    {
        anchor = ANCHOR_BOTTOM;
    }
    ObjectCreate(ChartID(), name, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, ArrowSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, colour);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
}

void RemoveArrow(const datetime time, const uchar arrow_code)
{
    string name = ArrowPrefix + "Arrow" + IntegerToString(arrow_code) + TimeToString(time);
    ObjectDelete(0, name);
}

// Returns the number processed bars.
int FillIndicatorBuffers(ENUM_TIMEFRAMES period, int limit, double& rsibuf[], double& upzone[], double& dnzone[], double& mdzone[], double& mabuf[], double& mbbuf[])
{
    double MA, RSI[];
    ArrayResize(RSI, Volatility_Band);
    int i = MathMax(MathMax(limit, RSI_Price_Line), Trade_Signal_Line); // Cannot calculate everything with at least so many RSI bars.
    int bars = iBars(Symbol(), period);
    
    int RSI_bars = CopyBuffer(RSI_handle, 0, 0, i + Volatility_Band, rsibuf); // No need to copy all RSI for too old bars.

    if (RSI_bars < i + Volatility_Band) return -1;

    // Calculate BB on RSI.
    while (i >= 0)
    {
        MA = 0;
        for (int x = i; x < i + Volatility_Band; x++)
        {
            if ((rsibuf[x] > 100) || (rsibuf[x] < 0)) return -1; // Bad RSI value. Try later.
            RSI[x - i] = rsibuf[x];
            MA += rsibuf[x] / Volatility_Band;
        }
        double SD = StdDev * StDev(RSI, Volatility_Band);
        upzone[i] = MA + SD;
        dnzone[i] = MA - SD;
        mdzone[i] = (upzone[i] + dnzone[i]) / 2;

        i--;
    }

    // Calculate MAs of RSI.
    for (int i = limit; i >= 0; i--)
    {
        mabuf[i] = iMAOnArray(rsibuf, 0, RSI_Price_Line, 0, RSI_Price_Type, i);
        mbbuf[i] = iMAOnArray(rsibuf, 0, Trade_Signal_Line, 0, Trade_Signal_Type, i);

        if (EnableArrowAlerts)
        {
            if (i + TriggerCandle + 1 >= iBars(Symbol(), period)) continue; // Check if there is enough bars.
            // Lower timeframe bar index:
            int lower_i = iBarShift(Symbol(), Period(), iTime(Symbol(), period, i + TriggerCandle), false);
            if (EnableRedYellowCrossAlert)
            {
                if ((mbbuf[i + TriggerCandle] > mdzone[i + TriggerCandle]) && (mbbuf[i + TriggerCandle + 1] <= mdzone[i + TriggerCandle + 1]))
                {
                    PutArrow(iLow(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Buy, RedYellowCrossArrowBullishColor, RedYellowCrossArrowBullishCode, "Bullish cross");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), RedYellowCrossArrowBullishCode);
                if ((mbbuf[i + TriggerCandle] < mdzone[i + TriggerCandle]) && (mbbuf[i + TriggerCandle + 1] >= mdzone[i + TriggerCandle + 1]))
                {
                    PutArrow(iHigh(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Sell, RedYellowCrossArrowBearishColor, RedYellowCrossArrowBearishCode, "Bearish cross");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), RedYellowCrossArrowBearishCode);
            }
            if (EnableHookAlert)
            {
                // Green line crosses upper blue line from above when both are above level 68.
                if ((mabuf[i + TriggerCandle] < upzone[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] >= upzone[i + TriggerCandle + 1]) && ((mabuf[i + TriggerCandle] > 68) || (mabuf[i + TriggerCandle + 1] > 68)) && ((upzone[i + TriggerCandle] > 68) || (upzone[i + TriggerCandle + 1] > 68)))
                {
                    PutArrow(iHigh(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Sell, HookArrowBearishColor, HookArrowBearishCode, "Bearish Hook");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), HookArrowBearishCode);
                // Green line crosses lower blue line from below when both are below level 32.
                if ((mabuf[i + TriggerCandle] > dnzone[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] <= dnzone[i + TriggerCandle + 1]) && ((mabuf[i + TriggerCandle] < 32) || (mabuf[i + TriggerCandle + 1] < 32)) && ((dnzone[i + TriggerCandle] < 32) || (dnzone[i + TriggerCandle + 1] < 32)))
                {
                    PutArrow(iLow(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Buy, HookArrowBullishColor, HookArrowBullishCode, "Bullish Hook");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), HookArrowBullishCode);
            }
            if (EnableGreenRedCrossAlert)
            {
                // Green line crosses red one from above.
                if ((mabuf[i + TriggerCandle] < mbbuf[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] >= mbbuf[i + TriggerCandle + 1]))
                {
                    PutArrow(iHigh(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Sell, GreenRedCrossArrowBearishColor, GreenRedCrossArrowBearishCode, "Green line crossed red one from above");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), GreenRedCrossArrowBearishCode);
                // Green line crosses red one from below.
                if ((mabuf[i + TriggerCandle] > mbbuf[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] <= mbbuf[i + TriggerCandle + 1]))
                {
                    PutArrow(iLow(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Buy, GreenRedCrossArrowBullishColor, GreenRedCrossArrowBullishCode, "Green line crossed red one from below");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), GreenRedCrossArrowBullishCode);
            }
            if (EnableGreenRedCrossWithYellowAlert)
            {
                // Green line crosses red one from above and both are below the yellow line.
                if ((mabuf[i + TriggerCandle] < mbbuf[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] >= mbbuf[i + TriggerCandle + 1]) && (mabuf[i + TriggerCandle] < mdzone[i + TriggerCandle]) && (mbbuf[i + TriggerCandle] < mdzone[i + TriggerCandle]))
                {
                    PutArrow(iHigh(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Sell, GreenRedCrossArrowBearishColor, GreenRedCrossArrowBearishCode, "Green line crossed red one from above while both below yellow");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), GreenRedCrossArrowBearishCode);
                // Green line crosses red one from below and both are above the yellow line.
                if ((mabuf[i + TriggerCandle] > mbbuf[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] <= mbbuf[i + TriggerCandle + 1]) && (mabuf[i + TriggerCandle] > mdzone[i + TriggerCandle]) && (mbbuf[i + TriggerCandle] > mdzone[i + TriggerCandle]))
                {
                    PutArrow(iLow(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Buy, GreenRedCrossArrowBullishColor, GreenRedCrossArrowBullishCode, "Green line crossed red one from below while both above yellow");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), GreenRedCrossArrowBullishCode);
            }
            if (EnableYellowGreenCrossAlert)
            {
                // Green line crosses yellow one from above.
                if ((mabuf[i + TriggerCandle] < mdzone[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] >= mdzone[i + TriggerCandle + 1]))
                {
                    PutArrow(iHigh(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Sell, YellowGreenCrossArrowBearishColor, YellowGreenCrossArrowBullishCode, "Green line crossed yellow one from above");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), YellowGreenCrossArrowBullishCode);
                // Green line crosses yellow one from below.
                if ((mabuf[i + TriggerCandle] > mdzone[i + TriggerCandle]) && (mabuf[i + TriggerCandle + 1] <= mdzone[i + TriggerCandle + 1]))
                {
                    PutArrow(iLow(Symbol(), Period(), lower_i), iTime(Symbol(), period, i + TriggerCandle), Buy, YellowGreenCrossArrowBullishColor, YellowGreenCrossArrowBearishCode, "Green line crossed yellow one from below");
                }
                else RemoveArrow(iTime(Symbol(), period, i + TriggerCandle), YellowGreenCrossArrowBearishCode);
            }
        }
    }
    return bars;
}
//+------------------------------------------------------------------+