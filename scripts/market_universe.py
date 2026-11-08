"""Curated market universe; provider failures are reported per symbol."""

US_TICKERS = [
    # Magnificent Seven & Mega-Cap Tech
    "AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA",
    # Semiconductors & Hardware
    "AMD", "INTC", "AVGO", "QCOM", "TXN", "ARM", "MU", "AMAT", "LRCX", "KLAC",
    # Enterprise Software, Cloud & AI
    "CRM", "ORCL", "ADBE", "NOW", "PLTR", "SNOW", "PANW", "CRWD", "WDAY", "INTU",
    # Consumer Tech, Streaming & FinTech
    "NFLX", "UBER", "ABNB", "PYPL", "XYZ", "COIN", "SHOP", "SPOT",
    # Financials & Banking
    "JPM", "BAC", "WFC", "MS", "GS", "BLK", "C", "AXP", "V", "MA",
    # Healthcare & Pharma
    "LLY", "UNH", "JNJ", "PFE", "MRK", "ABBV", "TMO", "DHR", "ISRG", "BMY", "AMGN", "GILD",
    # Retail & Consumer Goods
    "WMT", "COST", "TGT", "HD", "LOW", "MCD", "SBUX", "NKE", "KO", "PEP", "PG", "PM", "CL",
    # Industrials & Aerospace
    "GE", "CAT", "DE", "BA", "LMT", "RTX", "HON", "UNP", "UPS", "FDX",
    # Energy & Utilities
    "XOM", "CVX", "COP", "SLB", "EOG", "NEE", "DUK", "SO",
    # Telecom & Media
    "T", "VZ", "DIS", "CMCSA",
    # Broad Market & Sector ETFs
    "SPY", "QQQ", "DIA", "IWM", "VOO", "VTI", "XLK", "XLF", "XLE", "XLV", "SMH",
    # Major Crypto Pairs
    "BTC-USD", "ETH-USD", "SOL-USD", "BNB-USD", "XRP-USD",
]

IN_TICKERS = [
    # Benchmark Indices
    "^NSEI", "^NSEBANK", "^BSESN",
    # Nifty 50 Heavyweights
    "RELIANCE.NS", "TCS.NS", "HDFCBANK.NS", "INFY.NS", "ICICIBANK.NS",
    "BHARTIARTL.NS", "SBIN.NS", "ITC.NS", "LT.NS", "HINDUNILVR.NS",
    "BAJFINANCE.NS", "KOTAKBANK.NS", "AXISBANK.NS", "HCLTECH.NS", "MARUTI.NS",
    "SUNPHARMA.NS", "TMCV.NS", "TMPV.NS", "NTPC.NS", "ONGC.NS", "TITAN.NS",
    "POWERGRID.NS", "ADANIENT.NS", "ADANIPORTS.NS", "COALINDIA.NS", "TATASTEEL.NS",
    "BAJAJFINSV.NS", "ASIANPAINT.NS", "M&M.NS", "ULTRACEMCO.NS", "WIPRO.NS",
    "NESTLEIND.NS", "JSWSTEEL.NS", "TECHM.NS", "GRASIM.NS", "LTM.NS",
    "SBILIFE.NS", "HDFCLIFE.NS", "DRREDDY.NS", "CIPLA.NS", "BRITANNIA.NS",
    "HEROMOTOCO.NS", "EICHERMOT.NS", "DIVISLAB.NS", "HINDALCO.NS", "APOLLOHOSP.NS",
    "BPCL.NS", "TRENT.NS", "BEL.NS", "SHREECEM.NS", "INDUSINDBK.NS",
    # Next 50 & High-Conviction Midcaps
    "ETERNAL.NS", "JIOFIN.NS", "VBL.NS", "HAL.NS", "DLF.NS",
    "CHOLAFIN.NS", "SIEMENS.NS", "ABB.NS", "PFC.NS", "RECLTD.NS",
    "GAIL.NS", "IOC.NS", "TATAPOWER.NS", "POLYCAB.NS", "BHEL.NS",
    "IRFC.NS", "RVNL.NS", "SUZLON.NS", "IDEA.NS", "YESBANK.NS",
    "IDFCFIRSTB.NS", "FEDERALBNK.NS", "PNB.NS", "BANKBARODA.NS", "CANBK.NS",
    "UNIONBANK.NS", "AUROPHARMA.NS", "LUPIN.NS", "TORNTPHARM.NS", "MUTHOOTFIN.NS",
    "SHRIRAMFIN.NS", "TATACOMM.NS", "PERSISTENT.NS", "COFORGE.NS", "KPITTECH.NS",
    "DIXON.NS", "CGPOWER.NS", "MAXHEALTH.NS", "MANKIND.NS", "BOSCHLTD.NS",
    "PIDILITIND.NS", "HAVELLS.NS", "DABUR.NS", "GODREJCP.NS", "MARICO.NS",
    "COLPAL.NS", "BERGEPAINT.NS", "MOTHERSON.NS", "BALKRISIND.NS", "INDIGO.NS",
]

TARGET_TICKERS = list(dict.fromkeys(US_TICKERS + IN_TICKERS))

# Retain these instruments' stored history; never relabel it across a rename
# or demerger. Fetch the current provider listings as distinct instruments.
RETIRED_SYMBOLS = {'SQ', 'ZOMATO.NS', 'TATAMOTORS.NS', 'LTIM.NS'}
