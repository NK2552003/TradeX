import re

with open('lib/core/app-ui/blocks/dashboard_blocks.dart', 'r') as f:
    content = f.read()

bad = r'/// Horizontally scrolling gainers / losers rail\.\nclass AppMoversRailBlock extends StatelessWidget \{.*?\}\n'
content = re.sub(bad, '', content, flags=re.DOTALL)

with open('lib/core/app-ui/blocks/dashboard_blocks.dart', 'w') as f:
    f.write(content)
