import re
with open('lib/core/app-ui/example.dart', 'r') as f:
    content = f.read()

bad = r'''                  SizedBox\(height: context\.sp\(theme\.spacing\.md\)\),\n                  const AppTickerCard\(\n                    ticker: AppTicker\(\n                      symbol: 'AAPL',\n                      name: 'Apple Inc\.',\n                      price: 224\.50,\n                      changePercent: 1\.85,\n                    \),\n                  \),'''

content = re.sub(bad, '', content)
with open('lib/core/app-ui/example.dart', 'w') as f:
    f.write(content)
