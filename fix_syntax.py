import re

with open('lib/core/widgets/app_scaffold.dart', 'r') as f:
    content = f.read()

bad_pattern = r'            primaryAction: _buildDesktopPreviewControls\(\),\n                    \},\n                  \),\n            child: _buildActivePage\(\),\n          \),\n        \),'

good_pattern = r'''            primaryAction: _buildDesktopPreviewControls(),
            researchPanelBuilder: null,
            child: _buildActivePage(),
          ),
        ),'''

content = content.replace(bad_pattern, good_pattern)

with open('lib/core/widgets/app_scaffold.dart', 'w') as f:
    f.write(content)
