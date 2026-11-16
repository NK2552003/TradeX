/// Server-side research instructions; compute the clock for each request.
class ResearchPolicy {
  const ResearchPolicy._();
  static bool needsFreshResearch(String prompt) => RegExp(
    r'\b(latest|today|tonight|now|current(?:ly)?|recent|breaking|live|up[- ]to[- ]date|this\s+(?:week|month|year)|as\s+of|news|price|weather)\b',
    caseSensitive: false,
  ).hasMatch(prompt);

  static String freshnessInstructions([DateTime? clock]) =>
      '''
CURRENT RESEARCH CLOCK: ${(clock ?? DateTime.now()).toUtc().toIso8601String()} (UTC). This is request time, not a publication date.
Resolve today, yesterday, this week, latest, and upcoming against this clock. Use the user's specified timezone when available; otherwise label UTC. Never use the training cutoff as today's date.
For time-sensitive facts use live web search when available, include the current date/year in relevant queries, and check publication date, event date, and underlying data period separately. Check primary sources, corrections, and newer releases. Recently crawled or republished does not mean new. Respect explicit historical date ranges.
For latest news prefer the last 24 hours, widening to 7 days if needed and disclose that window. For filings and economic releases use the latest actual reporting period. For prices state currency, exchange timezone, actual data timestamp, and delayed or market-closed status. Never invent dates, live prices, or search activity.
Show an As of line for current-information answers. Label older evidence as background. Separate confirmed events from estimates and schedules. If tools are unavailable or freshness cannot be verified, explicitly say current information could not be verified. Do not describe remembered facts as latest.
''';

  static const panelProtocol = '''
For a requested research output format use a fenced research_panel JSON object:
{"format":"requested id","title":"Specific title","summary":"Direct answer","asOf":"Actual data timestamp; omit if unknown","columns":["Dimension","Finding","Evidence","Limitation"],"rows":[["...","...","...","..."]],"evidence":[{"claim":"...","sourceUrl":"https://exact-retrieved-url","sourceTitle":"...","publishedAt":"actual date or Unknown","eventDate":"actual date or Unknown"}],"caveats":["Specific gaps"],"nextSteps":["Concrete follow-up"]}.
Use the requested columns. Rows must match column count. Maximum 6 columns and 12 useful rows, with plain string values. Cite only supplied or retrieved sources, including clickable inline citations in surrounding prose. Never invent missing data or confidence percentages. Finish exploratory answers with three concrete followups in a JSON-array fence.
''';
}
