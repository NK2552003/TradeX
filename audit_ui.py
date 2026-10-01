import os
import re

directories_to_scan = [
    '/Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/notes/ui/',
    '/Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/journal/ui/',
    '/Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/strategies/ui/',
    '/Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/core/app-ui/cards/',
    '/Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/core/app-ui/blocks/'
]

patterns = {
    'FORBIDDEN WIDGETS': [
        (r'\bElevatedButton\(', 'UiButton'),
        (r'\bTextButton\(', 'UiButton'),
        (r'\bOutlinedButton\(', 'UiButton'),
        (r'\bTextField\(', 'UiInput'),
        (r'\bTextFormField\(', 'UiInput'),
        (r'\bCard\(', 'UiCard'),
        (r'\bCircularProgressIndicator\(', 'UiProgressCircle'),
        (r'\bLinearProgressIndicator\(', 'UiProgressBar'),
        (r'(?<!Ui)Switch\(', 'UiToggle / UiSwitch'),
        (r'(?<!Ui)Checkbox\(', 'UiCheckbox'),
        (r'\bDropdownButton\(', 'UiSelect'),
        (r'\bAlertDialog\(', 'UiDialog'),
        (r'\bshowDialog\(', 'UiDialog'),
        (r'\bDrawer\(', 'UiDrawer'),
        (r'\bTabBar\(', 'UiTabs'),
        (r'\bTabBarView\(', 'UiTabNavigation'),
        (r'\bSnackBar\(', 'UiToast'),
        (r'\bScaffoldMessenger\(', 'UiToast')
    ],
    'RAW STYLING': [
        (r'\bTextStyle\(', 'context.uiText tokens'),
        (r'\bColors\.[a-zA-Z0-9_]+', 'context.ui.colors tokens'),
        (r'\bColor\(0x[a-fA-F0-9]+\)', 'context.ui.colors tokens'),
        (r'\bEdgeInsets\.(all|symmetric|only|fromLTRB)\(', 'context.sp(theme.spacing.xx)'),
        (r'\bBorderRadius\.circular\(', 'context.radius(theme.radii.xx)'),
        (r'\bBoxShadow\(', 'design tokens'),
        (r'\bContainer\(\s*(?://.*?\n\s*)*decoration:\s*BoxDecoration\(', 'UiCard, UiBadge, or design tokens'),
        (r'\bContainer\(', 'UiCard, UiBadge, or design tokens (if used for styling)')
    ]
}

report = "# UI Audit Report\n\n"

def process_file(filepath):
    global report
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
            
        file_issues = []
        for i, line in enumerate(lines):
            line_num = i + 1
            for category, rules in patterns.items():
                for regex, replacement in rules:
                    if re.search(regex, line):
                        # Filter out some false positives like UiSwitch matching Switch if regex not careful, but handled via (?<!Ui)
                        snippet = line.strip()
                        file_issues.append((line_num, category, regex, replacement, snippet))
        
        if file_issues:
            report += f"## `{filepath}`\n\n"
            for issue in file_issues:
                line_num, category, regex, replacement, snippet = issue
                report += f"- **Line {line_num}** ({category}): Found matching `{regex}`\n"
                report += f"  - **Snippet**: `{snippet}`\n"
                report += f"  - **Fix**: Use `{replacement}` instead.\n\n"
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

for d in directories_to_scan:
    if not os.path.exists(d):
        continue
    for root, dirs, files in os.walk(d):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))

with open('/Users/nitishkumar/.gemini/antigravity/brain/7e9e05c6-1695-449e-857a-535b1177ecad/ui_audit_report.md', 'w') as f:
    f.write(report)

print("Report generated.")
