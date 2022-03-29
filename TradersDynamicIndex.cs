// -------------------------------------------------------------------------------
//   Based on TradersDynamicIndex.mq4 by Dean Malone
//   
//   Shows trend direction, strength, and volatility.
//   Green line  - RSI Price line.
//   Red line    - Trade Signal line.
//   Blue lines  - Volatility Band.
//   Yellow line - Market Base line.
//   
//   Version 1.05
//   Copyright 2015-2022, EarnForex.com
//   https://www.earnforex.com/metatrader-indicators/Traders-Dynamic-Index/
// -------------------------------------------------------------------------------

using cAlgo.API;
using cAlgo.API.Indicators;

namespace cAlgo.Indicators
{
    [Levels(32, 50, 68)]
    [Indicator(AccessRights = AccessRights.None)]
    public class TradersDynamicIndex : Indicator
    {
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

        private RelativeStrengthIndex RSI;
        private MovingAverage MA_Price;
        private MovingAverage MA_Signal;
        private BollingerBands VolatilityBands;

        protected override void Initialize()
        {
            RSI = Indicators.RelativeStrengthIndex(Source, RSI_Period);
            VolatilityBands = Indicators.BollingerBands(RSI.Result, Volatility_Band, StdDev, MovingAverageType.Simple);
            MA_Price = Indicators.MovingAverage(RSI.Result, RSI_Price_Line, RSI_Price_Type);
            MA_Signal = Indicators.MovingAverage(RSI.Result, Trade_Signal_Line, Trade_Signal_Type);
        }

        public override void Calculate(int index)
        {
            UpZone[index] = VolatilityBands.Top[index];
            DnZone[index] = VolatilityBands.Bottom[index];
            MdZone[index] = VolatilityBands.Main[index];
            MaBuf[index] = MA_Price.Result[index];
            MbBuf[index] = MA_Signal.Result[index];
        }
    }
}
