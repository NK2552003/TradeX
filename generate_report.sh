#!/bin/bash
OUTPUT_FILE="/Users/nitishkumar/.gemini/antigravity/brain/2723757f-7c07-4b3e-967b-0daa097d4dea/design_audit_report.md"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "# AlphaJournal Design & UI Rule Audit Report" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## 1. Forbidden Widget Usage" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
grep -rnE 'ElevatedButton|TextButton|OutlinedButton|TextField|TextFormField|Card\(|CircularProgressIndicator|LinearProgressIndicator|Switch\(|Checkbox\(|DropdownButton|AlertDialog|showDialog|Drawer\(|TabBar|SnackBar|ScaffoldMessenger' "$PROJECT_ROOT/lib/features/community/presentation/" "$PROJECT_ROOT/lib/features/messages/presentation/" "$PROJECT_ROOT/lib/features/ai_assistant/presentation/" >> "$OUTPUT_FILE" 2>/dev/null
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## 2. Raw Styling Violations" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
grep -rnE 'TextStyle\(|Colors\.|EdgeInsets\.|BorderRadius\.circular|SizedBox\(width:|SizedBox\(height:|BoxShadow\(' "$PROJECT_ROOT/lib/features/community/presentation/" "$PROJECT_ROOT/lib/features/messages/presentation/" "$PROJECT_ROOT/lib/features/ai_assistant/presentation/" >> "$OUTPUT_FILE" 2>/dev/null
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## 3. Core Widgets Styling Violations" >> "$OUTPUT_FILE"
echo "\`\`\`" >> "$OUTPUT_FILE"
grep -rnE 'Container\(|BoxDecoration\|TextStyle\(|Colors\.' "$PROJECT_ROOT/lib/core/widgets/" "$PROJECT_ROOT/lib/core/app-ui/shell/" >> "$OUTPUT_FILE" 2>/dev/null
echo "\`\`\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Report generated successfully."
