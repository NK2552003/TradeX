import re

with open('lib/features/linking/record_link_picker.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'package:tradex/features/markets/data/market_repository.dart';\n", "")

bad_init = r"""  @override
  void initState() \{
    super\.initState\(\);
    MarketWorkspaceStore\.instance\.initialize\(\);
  \}"""
content = re.sub(bad_init, '', content)

bad_builder = r"""    builder: \(context, snapshot\) => ListenableBuilder\(
      listenable: MarketWorkspaceStore\.instance,
      builder: \(context, _\) \{"""
content = re.sub(bad_builder, '    builder: (context, snapshot) {', content)

bad_instruments = r"""        for \(final q
            in MarketWorkspaceStore\.instance\.snapshot\?\.instruments \?\?
                <MarketInstrument>\[\]\) \{
          if \('\$\{q\.symbol\} \$\{q\.name\}'\.toLowerCase\(\)\.contains\(
            query\.toLowerCase\(\),
          \)\) \{
            refs\['ticker:\$\{q\.symbol\}'\] = AppLinkRef\(
              kind: AppLinkKind\.ticker,
              id: q\.symbol,
              title: q\.symbol,
              subtitle: q\.name,
            \);
          \}
        \}"""
content = re.sub(bad_instruments, '', content)

# Fix the closing braces for builder
content = content.replace("        );\n      },\n    ),\n  );", "        );\n    },\n  );")

with open('lib/features/linking/record_link_picker.dart', 'w') as f:
    f.write(content)
