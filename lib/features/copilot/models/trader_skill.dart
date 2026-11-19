/// Built-in trading workflows shared by the chat, hosted gateway and worker.
enum TraderSkill {
  copycat(
    'Look up an investor’s 13F holdings and changes',
    'Read SEC 13F-HR filings. Compare reporting periods, resolve tickers and normalize selected weights. Report the filing date and unmapped holdings. Hand target weights to budget.',
  ),
  news(
    'Check headlines and filings for your stocks',
    'Use tickers or supplied holdings. Check dated headlines and SEC 8-Ks, cite sources and deduplicate against earlier results.',
  ),
  pelosi(
    'Find publicly disclosed congressional trades',
    'Use House Clerk PTRs. Separate trade and disclosure dates, report owner, instrument, side and disclosed amount range. Identify amendments and flag matching holdings.',
  ),
  analyst(
    'Compare earnings, margins and revenue growth',
    'Read 10-K/10-Q XBRL facts and earnings releases. Compare like fiscal quarters, label derived Q4 and TTM metrics, and hand sourced metrics to screener.',
  ),
  screener(
    'Filter and rank stocks using your rules',
    'Use analyst metrics or a supplied table. Specify universe, thresholds, missing-data treatment and ranking. Show each rule result and pass the shortlist to budget only if allocation is requested.',
  ),
  budget(
    'Size positions to a budget and cash buffer',
    'Use budget, targets, cash reserve, position caps and order minimums. Redistribute capped weights, apply share rounding, reconcile cash and hand proposed orders to risk.',
  ),
  rebalance(
    'Compare your holdings with their target weights',
    'Value holdings and cash at dated prices. Calculate drift in percentage points, apply the band and caps, show sells before buys and check lots before selling. Hand proposals to risk.',
  ),
  tax(
    'Review tax lots, gains and wash-sale windows',
    'Ask for jurisdiction, dated lots and prices. For US lots compare FIFO, HIFO or specified lots, holding periods and realized/unrealized gains. Check purchases before and after a loss sale, including planned buys. Flag future uncertainty.',
  ),
  alerts(
    'Check price levels, stops and the opening bell',
    'Use a ticker, rule, timestamp and dated quote or exchange calendar. Evaluate above/below, stop, percent move or opening bell. Distinguish a one-time check from a registered recurring alert.',
  ),
  risk(
    'Check proposed orders against your limits',
    'Evaluate the whole batch sequentially against available cash, position and order caps, blocked assets, duplicate orders and daily limits. Report PASS or BLOCK and reasons per exact order. Missing required data leaves it unverified.',
  ),
  broker(
    'Prepare a paper order ticket for review',
    'Use only exact orders that passed risk today. Recheck changed orders. Show symbol, side, quantity or notional, order type and time in force. Prepare a draft only.',
  );

  const TraderSkill(this.description, this.method);
  final String description;
  final String method;
  String get command => '/trader-$name';

  static TraderSkill? fromCommand(String prompt) {
    final token = prompt.trimLeft().split(RegExp(r'\s+')).first.toLowerCase();
    return values
        .where((s) => token == s.command || token == '/${s.name}')
        .firstOrNull;
  }

  static String instructions(String prompt) {
    final command = fromCommand(prompt);
    return '''
Trader skills
${command == null ? 'Choose the most relevant skill from the meaning of the request, conversation and attachments. Answer unrelated questions normally. For an unknown slash command, explain how to browse Trader skills.' : 'The user explicitly selected ${command.command}. Start with that skill.'}
For a skill request, identify the skill(s) used. Run only the stages needed for the requested outcome, in dependency order. Use open_trader_skill when available to run the supplied toolkit. Otherwise use these methods with the available evidence and tools. Cite dated sources, ask for missing inputs, and distinguish computations from estimates. Never use example portfolios as user data.
For a sized copy portfolio, pass copycat targets to budget and proposed orders to risk. For stock selection, pass analyst metrics to screener. For rebalancing or harvesting, pass proposed orders to risk. Broker requires a current risk pass for the exact ticket. Carry intermediate values through the conversation and show enough inputs and results to resume. Stop at a blocked or incomplete stage.
AlphaJournal prepares tickets for review only. Never submit an order, record an approval or fill, connect a broker, or claim ongoing monitoring as part of these skills.
${values.map((s) => '${s.command} — ${s.method}').join('\n')}
''';
  }

  static const toolkitGuidance =
      'Use the Python tool to extract the bundled *trader-skills.zip from /mnt/data. '
      'Read the selected trader-*/SKILL.md as a workflow reference and run its supplied Python script with the actual inputs. '
      'Use a common working directory and pass resulting trader/ files to downstream skills. '
      'Use web search or user-supplied dated data for public inputs when network access is unavailable. '
      'Show results and required handoff data in the reply. Broker supports ticket previews only.';
}
