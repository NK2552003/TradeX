import re
with open('lib/features/linking/record_link_picker.dart', 'r') as f:
    content = f.read()

bad = r'''  @override
  void initState\(\) \{
    super\.initState\(\);
    MarketWorkspaceStore\.instance\.initialize\(\);
  \}'''
content = re.sub(bad, '', content)

with open('lib/features/linking/record_link_picker.dart', 'w') as f:
    f.write(content)
