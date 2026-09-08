import re

with open('lib/core/app-ui/shell/app_shell.dart', 'r') as f:
    content = f.read()

# Remove _buildTicker
content = re.sub(r'  Widget _buildTicker\(UiTheme theme\) \{.*?    \);\n  }\n\n', '', content, flags=re.DOTALL)

# Remove usage of _buildTicker
content = re.sub(r'          SafeArea\(\n            bottom: false,\n            child: _buildTicker\(theme\),\n          \),\n', '', content)
content = re.sub(r'          if \(!r\.isMobile\)\n            SafeArea\(\n              bottom: false,\n              child: _buildTicker\(theme\),\n            \),\n', '', content)

with open('lib/core/app-ui/shell/app_shell.dart', 'w') as f:
    f.write(content)
