with open('lib/core/app-ui/blocks/dashboard_blocks.dart', 'r') as f:
    content = f.read()

content = content.replace("  }\n}\n\n}\n\n/// Allocation donut", "  }\n}\n\n/// Allocation donut")

with open('lib/core/app-ui/blocks/dashboard_blocks.dart', 'w') as f:
    f.write(content)
