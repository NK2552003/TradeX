import re
with open('lib/features/auth/widgets/auth_window_graphics.dart', 'r') as f:
    content = f.read()

content = content.replace("  markets,\n\n  /// AI + community view: an AI insight, a logged trade, a community post.\n  social,\n", "  /// AI + community view: an AI insight, a logged trade, a community post.\n  social,\n")
content = content.replace("this.scene = AuthScene.markets,", "this.scene = AuthScene.social,")
content = content.replace("widget.scene == AuthScene.markets\n                  ? _MarketsScene(\n                      data: widget.dataSource,\n                      animation: _animation,\n                    )\n                  : _SocialScene(", "_SocialScene(")

bad_markets_scene = r"class _MarketsScene extends StatelessWidget \{.*?\}\n\n"
content = re.sub(bad_markets_scene, '', content, flags=re.DOTALL)

with open('lib/features/auth/widgets/auth_window_graphics.dart', 'w') as f:
    f.write(content)
