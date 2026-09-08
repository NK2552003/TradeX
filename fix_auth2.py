import re
with open('lib/features/auth/widgets/auth_window_graphics.dart', 'r') as f:
    content = f.read()

bad = r'''              child: widget\.scene == AuthScene\.markets\n                  \? _MarketsScene\(\n                      areaData: _areaData,\n                      areaSeries: areaSeries,\n                      tickers: _tickers,\n                      statPnl: _statPnl,\n                      statWinRate: _statWinRate,\n                      gap: context\.sp\(theme\.spacing\.md\),\n                    \)\n                  : _SocialScene\('''

content = re.sub(bad, '              child: _SocialScene(', content)

with open('lib/features/auth/widgets/auth_window_graphics.dart', 'w') as f:
    f.write(content)
