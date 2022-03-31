//+------------------------------------------------------------------+
//|                                           TraderDynamicIndex.mq4 |
//|                                 Copyright © 2015-2022, EarnForex |
//|                                        https://www.earnforex.com |
//|                         Based on indicator by Dean Malone (2006) |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2015-2022"
#property link      "https://www.earnforex.com/metatrader-indicators/Traders-Dynamic-Index/"
#property version   "1.06"
#property strict

#property description "Shows trend direction, strength, and volatility."
#property description "Green line  - RSI Price line."
#property description "Red line    - Trade Signal line."
#property description "Blue lines  - Volatility Band."
#property description "Yellow line - Market Base line."

#property indicator_separate_window
#property indicator_buffers 6
#property indicator_level1 32
#property indicator_level2 50
#property indicator_level3 68
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1
#property indicator_color1 clrNONE
#property indicator_type1  DRAW_NONE
#property indicator_color2 clrMediumBlue
#property indicator_label2 "VB High"
#property indicator_type2  DRAW_LINE
#property indicator_color3 clrYellow
#property indicator_label3 "Market Base Line"
#property indicator_type3  DRAW_LINE
#property indicator_width3 2
#property indicator_color4 clrMediumBlue
#property indicator_label4 "VB Low"
#property indicator_type4  DRAW_LINE
#property indicator_color5 clrGreen
#property indicator_label5 "RSI Price Line"
#property indicator_type5  DRAW_LINE
#property indicator_width5 2
#property indicator_color6 clrRed
#property indicator_label6 "Trade Signal Line"
#property indicator_type6  DRAW_LINE
#property indicator_width6 2

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

input int RSI_Period = 13; // RSI_Period: 8-25
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE;
input int Volatility_Band = 34; // Volatility_Band: 20-40
input double StdDev = 1.6185; // Standard Deviations: 1-3
input int RSI_Price_Line = 2;
input ENUM_MA_METHOD RSI_Price_Type = MODE_SMA;
input int Trade_Signal_Line = 7;
input ENUM_MA_METHOD Trade_Signal_Type = MODE_SMA;
input ENUM_TIMEFRAMES UpperTimeframe = PERIOD_CURRENT; // UpperTimeframe: If above current will display values from  that timeframe.
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input bool EnableArrowAlerts = false;
input string ArrowPrefix = "TDI-";
input bool EnableRedYellowCrossAlert = true; // EnableRedYellowCrossAlert: yellow/red lines alerts.
input bool EnableHookAlert = false; // EnableHookAlert: Enable green line hook alerts.
input bool EnableGreenRedCrossAlert = false; // EnableGreenRedCrossAlert: green/red lines alerts.
input bool EnableYellowGreenCrossAlert = false; // EnableYellowGreenCrossAlert: yellow/green lines alerts.
input enum_candle_to_check TriggerCandle = Previous;

double RSIBuf[], UpZone[], MdZone[], DnZone[], MaBuf[], MbBuf[];
double _RSIBuf[], _UpZone[], _MdZone[], _DnZone[], _MaBuf[], _MbBuf[]; // For upper timeframe data.

datetime AlertPlayed = 0, HookAlertPlayed = 0, RedGreenAlertPlayed = 0, YellowGreenAlertPlayed = 0;

int OnInit()
{
    if (PeriodSeconds(UpperTimeframe) < PeriodSeconds())
    {
        Print("Upper timeframe cannot be lower than the current timeframe.");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    IndicatorShortName("TDI (" + IntegerToString(RSI_Period) + ", " + IntegerToString(Volatility_Band) + ", " + IntegerToString(RSI_Price_Line) + ", " + IntegerToString(Trade_Signal_Line) +  ")");

    SetIndexBuffer(0, RSIBuf);
    SetIndexBuffer(1, UpZone);
    SetIndexBuffer(2, MdZone);
    SetIndexBuffer(3, DnZone);
    SetIndexBuffer(4, MaBuf);
    SetIndexBuffer(5, MbBuf);

    if (UpperTimeframe != Period())
    {
        IndicatorBuffers(12);
        SetIndexBuffer(6, _RSIBuf);
        SetIndexBuffer(7, _UpZone);
        SetIndexBuffer(8, _MdZone);
        SetIndexBuffer(9, _DnZone);
        SetIndexBuffer(10, _MaBuf);
        SetIndexBuffer(11, _MbBuf);
    }

    IndicatorDigits(1);
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), ArrowPrefix, 0, OBJ_ARROW);
}

int OnCalculate(const int        rates_total,
                const int        prev_calculated,
                const datetime&  time[],
                const double&    open[],
                const double&    high[],
                const double&    low[],
                const double&    close[],
                const long&      tick_volume[],
                const long&      volume[],
                const int&       spread[]
               )
{
    int counted_bars = IndicatorCounted();
    if (counted_bars > 0) counted_bars--;
    int limit = Bars - 1 - counted_bars;
    if (PeriodSeconds(UpperTimeframe) == PeriodSeconds(Period()))
    {
        if (FillIndicatorBuffers((ENUM_TIMEFRAMES)Period(), limit, RSIBuf, UpZone, DnZone, MdZone, MaBuf, MbBuf) < 0) return 0; // Bad value returned. Data not yet ready. Recalculate everything.
    }
    else
    {
        static int upper_prev_counted = 0;
        if (upper_prev_counted > 0) upper_prev_counted--;
        int upper_limit = iBars(Symbol(), UpperTimeframe) - 1 - upper_prev_counted;
        if (upper_limit > Bars - Volatility_Band) upper_limit = Bars - Volatility_Band; // Buffers cannot hold more than the current period's bars worth of data!
        upper_prev_counted = FillIndicatorBuffers(UpperTimeframe, upper_limit, _RSIBuf, _UpZone, _DnZone, _MdZone, _MaBuf, _MbBuf);
        if (upper_prev_counted < -1) return 0; // Bad value returned. Data not yet ready. Recalculate everything.
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
            if (i + 1 == Bars) break;
        }
    }

    if (EnableRedYellowCrossAlert)
    {
        if ((MbBuf[TriggerCandle] > MdZone[TriggerCandle]) && (MbBuf[TriggerCandle + 1] <= MdZone[TriggerCandle + 1]) && (AlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Bullish cross");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI Alert: BUY " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Alert: BUY " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(Low[0], Time[0], Buy, 233, "Bullish cross");
            AlertPlayed = Time[0];
        }
        if ((MbBuf[TriggerCandle] < MdZone[TriggerCandle]) && (MbBuf[TriggerCandle + 1] >= MdZone[TriggerCandle + 1]) && (AlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Bearish cross");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI Alert: SELL " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Alert: SELL " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(High[0], Time[0], Sell, 234, "Bearish cross");
            AlertPlayed = Time[0];
        }
    }

    if (EnableHookAlert)
    {
        // Green line crosses upper blue line from above when both are above level 68.
        if ((MaBuf[TriggerCandle] < UpZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= UpZone[TriggerCandle + 1]) && ((MaBuf[TriggerCandle] > 68) || (MaBuf[TriggerCandle + 1] > 68)) && ((UpZone[TriggerCandle] > 68) || (UpZone[TriggerCandle + 1] > 68)) && (HookAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Bearish Hook");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI Hook Alert: SELL " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Hook Alert: SELL " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(High[0], Time[0], Sell, 72, "Bearish Hook");
            HookAlertPlayed = Time[0];
        }
        // Green line crosses lower blue line from below when both are below level 32.
        else if ((MaBuf[TriggerCandle] > DnZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= DnZone[TriggerCandle + 1]) && ((MaBuf[TriggerCandle] < 32) || (MaBuf[TriggerCandle + 1] < 32)) && ((DnZone[TriggerCandle] < 32) || (DnZone[TriggerCandle + 1] < 32)) && (HookAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Bullish Hook");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI Hook Alert: BUY " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI Hook Alert: BUY " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(Low[0], Time[0], Buy, 71, "Bullish Hook");
            HookAlertPlayed = Time[0];
        }
    }

    if (EnableGreenRedCrossAlert)
    {
        // Green line crosses red one from above.
        if ((MaBuf[TriggerCandle] < MbBuf[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= MbBuf[TriggerCandle + 1]) && (RedGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Green line crossed red one from above");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI: Green line crossed red one from above - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed red one from above - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(High[0], Time[0], Sell, 201, "Green line crossed red one from above");
            RedGreenAlertPlayed = Time[0];
        }
        // Green line crosses red one from below.
        else if ((MaBuf[TriggerCandle] > MbBuf[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= MbBuf[TriggerCandle + 1]) && (RedGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Green line crossed red one from below");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI: Green line crossed red one from below - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed red one from below - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(Low[0], Time[0], Buy, 200, "Green line crossed red one from below");
            RedGreenAlertPlayed = Time[0];
        }
    }

    if (EnableYellowGreenCrossAlert)
    {
        // Green line crosses yellow one from above.
        if ((MaBuf[TriggerCandle] < MdZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] >= MdZone[TriggerCandle + 1]) && (YellowGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Green line crossed yellow one from above");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI: Green line crossed yellow one from above - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed yellow one from above - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(High[0], Time[0], Sell, 226, "Green line crossed yellow one from above");
            YellowGreenAlertPlayed = Time[0];
        }
        // Green line crosses yellow one from below.
        else if ((MaBuf[TriggerCandle] > MdZone[TriggerCandle]) && (MaBuf[TriggerCandle + 1] <= MdZone[TriggerCandle + 1]) && (YellowGreenAlertPlayed != Time[0]))
        {
            if (EnableNativeAlerts) Alert(_Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period) + " - Green line crossed yellow one from below");
            if (EnableEmailAlerts)
            {
                RefreshRates();
                SendMail("TDI: Green line crossed yellow one from below - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period), "Current rate = " + DoubleToString(Bid, _Digits) + "/" + DoubleToString(Ask, _Digits) + "\nIndicator buffers:\nVB High = " + DoubleToString(UpZone[TriggerCandle], 1) + "\nMarket Base Line = " + DoubleToString(MdZone[TriggerCandle], 1) + "\nVB Low = " + DoubleToString(DnZone[TriggerCandle], 1) + "\nRSI Price Line = " + DoubleToString(MaBuf[TriggerCandle], 1) + "\nTrade Signal Line = " + DoubleToString(MbBuf[TriggerCandle], 1));
            }
            if (EnablePushAlerts) SendNotification("TDI: Green line crossed yellow one from below - " + _Symbol + " @ " + TimeframeToString((ENUM_TIMEFRAMES)_Period));
            if (EnableArrowAlerts) PutArrow(Low[0], Time[0], Buy, 225, "Green line crossed yellow one from below");
            YellowGreenAlertPlayed = Time[0];
        }
    }
        
    return rates_total;
}

// Standard Deviation function.
double StDev(double& Data[], const int Per)
{
    return MathSqrt(Variance(Data, Per));
}

// Math Variance function.
double Variance(double& Data[], const int Per)
{
    double sum = 0, ssum = 0;
    for (int i = 0; i < Per; i++)
    {
        sum += Data[i];
        ssum += MathPow(Data[i], 2);
    }
    return ((ssum * Per - sum * sum) / (Per * (Per - 1)));
}

// For alerts.
string TimeframeToString(ENUM_TIMEFRAMES P)
{
    return StringSubstr(EnumToString(P), 7);
}

void PutArrow(double price, const datetime time, enum_arrow_type dir, const uchar arrow_code, const string text)
{
    string name = ArrowPrefix + "Arrow" + IntegerToString(arrow_code) + TimeToString(time);
    if (ObjectFind(ChartID(), name) > -1) return;
    color colour;
    if (dir == Buy)
    {
        colour = clrGreen;
    }
    else
    {
        colour = clrRed;
        price += 10 * _Point;
    }
    ObjectCreate(ChartID(), name, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
    ObjectSetInteger(0, name, OBJPROP_COLOR, colour);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
}


// Returns the number processed bars.
int FillIndicatorBuffers(ENUM_TIMEFRAMES period, int limit, double& rsibuf[], double& upzone[], double& dnzone[], double& mdzone[], double& mabuf[], double& mbbuf[])
{
    double MA, RSI[];
    ArrayResize(RSI, Volatility_Band);
    int bars = iBars(Symbol(), period);
    int adjusted_limit = MathMax(MathMax(limit, Trade_Signal_Line), RSI_Price_Line);
    for (int i = adjusted_limit; i >= 0; i--)
    {
        rsibuf[i] = iRSI(NULL, period, RSI_Period, RSI_Price, i);
        MA = 0;
        for (int x = i; x < i + Volatility_Band; x++)
        {
            if (x > bars - 1) break;
            if ((rsibuf[x] > 100) || (rsibuf[x] < 0)) return -1; // Bad RSI value. Try later.
            RSI[x - i] = rsibuf[x];
            MA += rsibuf[x] / Volatility_Band;
        }
        double SD = StdDev * StDev(RSI, Volatility_Band);
        upzone[i] = MA + SD;
        dnzone[i] = MA - SD;
        mdzone[i] = (upzone[i] + dnzone[i]) / 2;
    }
    for (int i = limit; i >= 0; i--)
    {
        mabuf[i] = iMAOnArray(rsibuf, 0, RSI_Price_Line, 0, RSI_Price_Type, i);
        mbbuf[i] = iMAOnArray(rsibuf, 0, Trade_Signal_Line, 0, Trade_Signal_Type, i);
    }
    return bars;
}
//+------------------------------------------------------------------+