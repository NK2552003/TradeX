import re

with open('lib/features/markets/ui/markets_screen.dart', 'r') as f:
    content = f.read()

# 1. Fix UiPage padding
content = content.replace("UiPage(\n                padding: EdgeInsets.zero,\n                child: Row(", 
                          "UiPage(\n                child: Row(")
content = content.replace("UiPage(\n                  padding: EdgeInsets.zero,\n                  child: MarketInstrumentDetail(", 
                          "UiPage(\n                  child: MarketInstrumentDetail(")

# 2. Fix UiSkeleton.watchlists()
content = content.replace("const UiSkeleton.watchlists()", "UiSkeleton.watchlists()")

# 3. Fix UiCardVariant.soft
content = content.replace("variant: UiCardVariant.soft,", "") # remove soft

# 4. Fix UiAreaChart -> UiCandleChart
chart_replacement = """
               return SizedBox(
                 height: 300,
                 child: UiCandleChart(
                   candles: bars.map((b) => UiCandle(
                      time: b.time,
                      open: b.open,
                      high: b.high,
                      low: b.low,
                      close: b.close,
                      volume: b.volume.toDouble(),
                   )).toList(),
                 ),
               );
"""
# We need to replace the FutureBuilder's return for SizedBox AreaChart.
chart_pattern = r"return SizedBox\(\s*height: 300,\s*child: UiAreaChart\(.*?\),\s*\);"
content = re.sub(chart_pattern, chart_replacement.strip(), content, flags=re.DOTALL)

with open('lib/features/markets/ui/markets_screen.dart', 'w') as f:
    f.write(content)

