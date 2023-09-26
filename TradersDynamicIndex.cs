// -------------------------------------------------------------------------------
//   Based on TradersDynamicIndex.mq4 by Dean Malone
//   
//   Shows trend direction, strength, and volatility.
//   Green line  - RSI Price line.
//   Red line    - Trade Signal line.
//   Blue lines  - Volatility Band.
//   Yellow line - Market Base line.
//   
//   Version 1.07
//   Copyright 2023, EarnForex.com
//   https://www.earnforex.com/metatrader-indicators/Traders-Dynamic-Index/
// -------------------------------------------------------------------------------
using System;
using cAlgo.API;
using cAlgo.API.Indicators;

namespace cAlgo.Indicators
{
    [Levels(32, 50, 68)]
    [Indicator(AccessRights = AccessRights.None)]
    public class TradersDynamicIndex : Indicator
    {
        public enum ENUM_CANDLE_TO_CHECK
        {
            Current = 0,
            Previous = 1
        }
        
        [Parameter("RSI Period (8-25)", DefaultValue = 13, MinValue = 1)]
        public int RSI_Period { get; set; }

        [Parameter()]
        public DataSeries Source { get; set; }

        [Parameter("Volatility Band (20-40)", DefaultValue = 34, MinValue = 1)]
        public int Volatility_Band { get; set; }

        [Parameter("Standard Deviations (1-3)", DefaultValue = 1.6185, MinValue = 0)]
        public double StdDev { get; set; }

        [Parameter("RSI Price MA Period", DefaultValue = 2, MinValue = 1)]
        public int RSI_Price_Line { get; set; }

        [Parameter("Price MA Type", DefaultValue = MovingAverageType.Simple)]
        public MovingAverageType RSI_Price_Type { get; set; }

        [Parameter("Trade Signal MA Period", DefaultValue = 7, MinValue = 1)]
        public int Trade_Signal_Line { get; set; }

        [Parameter("Signal MA Type", DefaultValue = MovingAverageType.Simple)]
        public MovingAverageType Trade_Signal_Type { get; set; }

        [Parameter("Upper timeframe")]
        public TimeFrame UpperTimeframe { get; set; }

        [Parameter("Enable email alerts", DefaultValue = false)]
        public bool EnableEmailAlerts { get; set; }

        [Parameter("AlertEmail: Email From", DefaultValue = "")]
        public string AlertEmailFrom { get; set; }

        [Parameter("AlertEmail: Email To", DefaultValue = "")]
        public string AlertEmailTo { get; set; }

        [Parameter("Enable arrows", DefaultValue = false)]
        public bool EnableArrowAlerts { get; set; }

        [Parameter("Enable alerts when the red line crosses the yellow line?", DefaultValue = false)]
        public bool EnableRedYellowCrossAlert { get; set; }

        [Parameter("Enable alerts when the green line crosses the blue line above 68 or below 32?", DefaultValue = false)]
        public bool EnableHookAlert { get; set; }

        [Parameter("Enable alerts when the green line crosses the red line?", DefaultValue = false)]
        public bool EnableGreenRedCrossAlert { get; set; }
        
        [Parameter("Enable alerts when the yellow line crosses the green line?", DefaultValue = false)]
        public bool EnableYellowGreenCrossAlert { get; set; }

        [Parameter(DefaultValue = ENUM_CANDLE_TO_CHECK.Previous)]
        public ENUM_CANDLE_TO_CHECK TriggerCandle { get; set; }

        [Parameter(DefaultValue = "Green")]
        public string RedYellowCrossArrowBullishColor { get; set; }

        [Parameter(DefaultValue = "Red")]
        public string RedYellowCrossArrowBearishColor { get; set; }

        [Parameter(DefaultValue = "Green")]
        public string HookArrowBullishColor { get; set; }

        [Parameter(DefaultValue = "Red")]
        public string HookArrowBearishColor { get; set; }

        [Parameter(DefaultValue = "Green")]
        public string GreenRedCrossArrowBullishColor { get; set; }

        [Parameter(DefaultValue = "Red")]
        public string GreenRedCrossArrowBearishColor { get; set; }

        [Parameter(DefaultValue = "Green")]
        public string YellowGreenCrossArrowBullishColor { get; set; }

        [Parameter(DefaultValue = "Red")]
        public string YellowGreenCrossArrowBearishColor { get; set; }

        [Parameter(DefaultValue = "TDI-")]
        public string ArrowPrefix { get; set; }

        [Output("Upper Volatility Band", LineColor = "MediumBlue")]
        public IndicatorDataSeries UpZone { get; set; }

        [Output("Lower Volatility Band", LineColor = "MediumBlue")]
        public IndicatorDataSeries DnZone { get; set; }

        [Output("Middle Volatility Band", LineColor = "Yellow", Thickness = 2)]
        public IndicatorDataSeries MdZone { get; set; }

        [Output("RSI Price Line", LineColor = "Green", Thickness = 2)]
        public IndicatorDataSeries MaBuf { get; set; }

        [Output("Trade Signal Line", LineColor = "Red", Thickness = 2)]
        public IndicatorDataSeries MbBuf { get; set; }

        // Output buffers:
        private RelativeStrengthIndex RSI;
        private MovingAverage MA_Price;
        private MovingAverage MA_Signal;
        private BollingerBands VolatilityBands;

        // MTF:
        private bool UseUpperTimeFrame;
        private Bars customBars;

        // Alerts:
        private DateTime LastAlertTimeRedYellow, LastAlertTimeHook, LastAlertTimeGreenRed, LastAlertTimeYellowGreen, unix_epoch;
        private int prev_index = -1;
        private int int_tc;

        protected override void Initialize()
        {
            if (UpperTimeframe <= TimeFrame)
            {
                Print("UpperTimeframe <= current timeframe. Ignored.");
                UseUpperTimeFrame = false;
                customBars = Bars;
            }
            else
            {
                UseUpperTimeFrame = true;
                customBars = MarketData.GetBars(UpperTimeframe);
            }

            RSI = Indicators.RelativeStrengthIndex(customBars.ClosePrices, RSI_Period);
            VolatilityBands = Indicators.BollingerBands(RSI.Result, Volatility_Band, StdDev, MovingAverageType.Simple);
            MA_Price = Indicators.MovingAverage(RSI.Result, RSI_Price_Line, RSI_Price_Type);
            MA_Signal = Indicators.MovingAverage(RSI.Result, Trade_Signal_Line, Trade_Signal_Type);

            unix_epoch = new DateTime(1970, 1, 1, 0, 0, 0);
            LastAlertTimeRedYellow = unix_epoch;
            LastAlertTimeHook = unix_epoch;
            LastAlertTimeGreenRed = unix_epoch;
            LastAlertTimeYellowGreen = unix_epoch;

            int_tc = (int)TriggerCandle;
        }

        public override void Calculate(int index)
        {
            int customIndex = index;
            int cnt = 0; // How many bars of the current timeframe should be recalculated.
            if (UseUpperTimeFrame)
            {
                customIndex = customBars.OpenTimes.GetIndexByTime(Bars.OpenTimes[index]);
                // Find how many current timeframe bars should be recalculated:
                while (customBars.OpenTimes.GetIndexByTime(Bars.OpenTimes[index - cnt]) == customIndex)
                {
                    cnt++;
                }
            }
            else
            {
                cnt = 1; // Non-MTF.
                if (customIndex <= RSI_Period) return; // Too early to calculate anything.
            }

            for (int i = 0; i < cnt; i++) // Making sure to rewrite previous lower timeframe candles with the updated upper one.
            {
                UpZone[index - i] = VolatilityBands.Top[customIndex];
                DnZone[index - i] = VolatilityBands.Bottom[customIndex];
                MdZone[index - i] = VolatilityBands.Main[customIndex];
                MaBuf[index - i] = MA_Price.Result[customIndex];
                MbBuf[index - i] = MA_Signal.Result[customIndex];
            }

            // Arrows
            if (EnableArrowAlerts)
            {
                int lower_i = Bars.OpenTimes.GetIndexByTime(customBars.OpenTimes[customIndex - int_tc]);
                if (EnableRedYellowCrossAlert)
                {
                    if ((MA_Signal.Result[customIndex - int_tc] > VolatilityBands.Main[customIndex - int_tc]) && (MA_Signal.Result[customIndex - int_tc - 1] <= VolatilityBands.Main[customIndex - int_tc - 1]))
                    {
                        Chart.DrawIcon(ArrowPrefix + "RY" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.UpTriangle, lower_i, Bars.LowPrices[lower_i], Color.FromName(RedYellowCrossArrowBullishColor));
                    }
                    else if ((MA_Signal.Result[customIndex - int_tc] < VolatilityBands.Main[customIndex - int_tc]) && (MA_Signal.Result[customIndex - int_tc - 1] >= VolatilityBands.Main[customIndex - int_tc - 1]))
                    {
                        Chart.DrawIcon(ArrowPrefix + "RY" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.DownTriangle, lower_i, Bars.HighPrices[lower_i], Color.FromName(RedYellowCrossArrowBearishColor));
                    }
                }
                if (EnableHookAlert)
                {
                    if ((MA_Price.Result[customIndex - int_tc] < VolatilityBands.Top[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] >= VolatilityBands.Top[customIndex - int_tc - 1]) && ((MA_Price.Result[customIndex - int_tc] > 68) || (MA_Price.Result[customIndex - int_tc - 1] > 68)) && ((VolatilityBands.Top[customIndex - int_tc] > 68) || (VolatilityBands.Top[customIndex - int_tc - 1] > 68)))
                    {
                        Chart.DrawIcon(ArrowPrefix + "H" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.DownArrow, lower_i, Bars.HighPrices[lower_i], Color.FromName(HookArrowBearishColor));
                    }
                    else if ((MA_Price.Result[customIndex - int_tc] >= VolatilityBands.Bottom[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] < VolatilityBands.Bottom[customIndex - int_tc - 1]) && ((MA_Price.Result[customIndex - int_tc] < 32) || (MA_Price.Result[customIndex - int_tc - 1] < 32)) && ((VolatilityBands.Bottom[customIndex - int_tc] < 32) || (VolatilityBands.Bottom[customIndex - int_tc - 1] < 32)))
                    {
                        Chart.DrawIcon(ArrowPrefix + "H" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.UpArrow, lower_i, Bars.LowPrices[lower_i], Color.FromName(HookArrowBullishColor));
                    }
                }
                if (EnableGreenRedCrossAlert)
                {
                    if ((MA_Price.Result[customIndex - int_tc] < MA_Signal.Result[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] >= MA_Signal.Result[customIndex - int_tc - 1]))
                    {
                        Chart.DrawIcon(ArrowPrefix + "GR" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.Diamond, lower_i, Bars.HighPrices[lower_i], Color.FromName(HookArrowBearishColor));
                    }
                    else if ((MA_Price.Result[customIndex - int_tc] > MA_Signal.Result[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] <= MA_Signal.Result[customIndex - int_tc - 1]))
                    {
                        Chart.DrawIcon(ArrowPrefix + "GR" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.Diamond, lower_i, Bars.LowPrices[lower_i], Color.FromName(HookArrowBullishColor));
                    }
                }
                if (EnableYellowGreenCrossAlert)
                {
                    if ((MA_Price.Result[customIndex - int_tc] < VolatilityBands.Main[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] >= VolatilityBands.Main[customIndex - int_tc - 1]))
                    {
                        Chart.DrawIcon(ArrowPrefix + "YG" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.Star, lower_i, Bars.HighPrices[lower_i], Color.FromName(HookArrowBearishColor));
                    }
                    else if ((MA_Price.Result[customIndex - int_tc] > VolatilityBands.Main[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] <= VolatilityBands.Main[customIndex - int_tc - 1]))
                    {
                        Chart.DrawIcon(ArrowPrefix + "YG" + Bars.OpenTimes[lower_i].ToString(), ChartIconType.Star, lower_i, Bars.LowPrices[lower_i], Color.FromName(HookArrowBullishColor));
                    }
                }
            }

            // Alerts
            if (!EnableEmailAlerts) return; // No need to go further.
            if ((!EnableRedYellowCrossAlert) && (!EnableHookAlert) && (!EnableGreenRedCrossAlert) && (!EnableYellowGreenCrossAlert)) return;

            string Text = "";
            if ((EnableRedYellowCrossAlert) && (LastAlertTimeRedYellow > unix_epoch) && (customBars.OpenTimes.LastValue > LastAlertTimeRedYellow))
            {
                if ((MA_Signal.Result[customIndex - int_tc] > VolatilityBands.Main[customIndex - int_tc]) && (MA_Signal.Result[customIndex - int_tc - 1] <= VolatilityBands.Main[customIndex - int_tc - 1]))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Bullish cross";
                    DoAlert(customIndex, Text);
                    LastAlertTimeRedYellow = customBars.OpenTimes.LastValue;
                }
                else if ((MA_Signal.Result[customIndex - int_tc] < VolatilityBands.Main[customIndex - int_tc]) && (MA_Signal.Result[customIndex - int_tc - 1] >= VolatilityBands.Main[customIndex - int_tc - 1]))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Bearish cross";
                    DoAlert(customIndex, Text);
                    LastAlertTimeRedYellow = customBars.OpenTimes.LastValue;
                }
            }
            if ((EnableHookAlert) && (LastAlertTimeHook > unix_epoch) && (customBars.OpenTimes.LastValue > LastAlertTimeHook))
            {
                if ((MA_Price.Result[customIndex - int_tc] < VolatilityBands.Top[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] >= VolatilityBands.Top[customIndex - int_tc - 1]) && ((MA_Price.Result[customIndex - int_tc] > 68) || (MA_Price.Result[customIndex - int_tc - 1] > 68)) && ((VolatilityBands.Top[customIndex - int_tc] > 68) || (VolatilityBands.Top[customIndex - int_tc - 1] > 68)))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Hook cross down";
                    DoAlert(customIndex, Text);
                    LastAlertTimeHook = customBars.OpenTimes.LastValue;
                }
                else if ((MA_Price.Result[customIndex - int_tc] >= VolatilityBands.Bottom[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] < VolatilityBands.Bottom[customIndex - int_tc - 1]) && ((MA_Price.Result[customIndex - int_tc] < 32) || (MA_Price.Result[customIndex - int_tc - 1] < 32)) && ((VolatilityBands.Bottom[customIndex - int_tc] < 32) || (VolatilityBands.Bottom[customIndex - int_tc - 1] < 32)))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Hook cross up";
                    DoAlert(customIndex, Text);
                    LastAlertTimeHook = customBars.OpenTimes.LastValue;
                }
            }
            if ((EnableGreenRedCrossAlert) && (LastAlertTimeGreenRed > unix_epoch) && (customBars.OpenTimes.LastValue > LastAlertTimeGreenRed))
            {
                if ((MA_Price.Result[customIndex - int_tc] < MA_Signal.Result[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] >= MA_Signal.Result[customIndex - int_tc - 1]))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Green line crossed red one from above";
                    DoAlert(customIndex, Text);
                    LastAlertTimeGreenRed = customBars.OpenTimes.LastValue;
                }
                else if ((MA_Price.Result[customIndex - int_tc] > MA_Signal.Result[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] <= MA_Signal.Result[customIndex - int_tc - 1]))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Green line crossed red one from below";
                    DoAlert(customIndex, Text);
                    LastAlertTimeGreenRed = customBars.OpenTimes.LastValue;
                }
            }
            if ((EnableYellowGreenCrossAlert) && (LastAlertTimeYellowGreen > unix_epoch) && (customBars.OpenTimes.LastValue > LastAlertTimeYellowGreen))
            {
                if ((MA_Price.Result[customIndex - int_tc] < VolatilityBands.Main[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] >= VolatilityBands.Main[customIndex - int_tc - 1]))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Green line crossed yellow one from above";
                    DoAlert(customIndex, Text);
                    LastAlertTimeYellowGreen = customBars.OpenTimes.LastValue;
                }
                else if ((MA_Price.Result[customIndex - int_tc] > VolatilityBands.Main[customIndex - int_tc]) && (MA_Price.Result[customIndex - int_tc - 1] <= VolatilityBands.Main[customIndex - int_tc - 1]))
                {
                    Text = "TDI Alert: " + Symbol.Name + " - " + TimeFrame.Name + " - Green line crossed yellow one from below";
                    DoAlert(customIndex, Text);
                    LastAlertTimeYellowGreen = customBars.OpenTimes.LastValue;
                }
            }
            
            if ((LastAlertTimeRedYellow == unix_epoch) && (prev_index == index)) LastAlertTimeRedYellow = customBars.OpenTimes.LastValue;
            if ((LastAlertTimeHook == unix_epoch) && (prev_index == index)) LastAlertTimeHook = customBars.OpenTimes.LastValue;
            if ((LastAlertTimeGreenRed == unix_epoch) && (prev_index == index)) LastAlertTimeGreenRed = customBars.OpenTimes.LastValue;
            if ((LastAlertTimeYellowGreen == unix_epoch) && (prev_index == index)) LastAlertTimeYellowGreen = customBars.OpenTimes.LastValue;
            prev_index = index;
        }

        protected override void OnDestroy()
        {
            if (EnableArrowAlerts)
            {
                var icons = Chart.FindAllObjects(ChartObjectType.Icon);
                for (int i = icons.Length - 1; i >= 0; i--)
                {
                    if (icons[i].Name.StartsWith(ArrowPrefix))
                    {
                        Chart.RemoveObject(icons[i].Name);
                    }
                }
            }
        }

        private void DoAlert(int customIndex, string text)
        {
            text += "\nCurrent rate = " + Symbol.Bid.ToString() + "/" + Symbol.Ask.ToString() + 
                    "\nIndicator buffers:\nVB High = " + VolatilityBands.Top[customIndex - int_tc].ToString() + 
                    "\nMarket Base Line = " + VolatilityBands.Main[customIndex - int_tc].ToString() + 
                    "\nVB Low = " + VolatilityBands.Bottom[customIndex - int_tc].ToString() + 
                    "\nRSI Price Line = " + MA_Price.Result[customIndex - int_tc].ToString() + 
                    "\nTrade Signal Line = " + MA_Signal.Result[customIndex - int_tc].ToString();
            Notifications.SendEmail(AlertEmailFrom, AlertEmailTo, "TDI Alert - " + Symbol.Name + " @ " + TimeFrame.Name, text);
        }
    }
}