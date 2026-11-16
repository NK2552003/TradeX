# Copilot: 60 ready-to-use research prompts

Replace `[YOUR TOPIC OR SUPPLIED RECORDS]` before sending. These are the exact prompt templates used by Research studio.

## 1. Evidence map (Evidence)

```text
Create a Evidence map for: [YOUR TOPIC OR SUPPLIED RECORDS].
Map each material claim to the exact supporting source and explain what that source does and does not establish.
Start with a direct answer. Use a research_panel JSON fence with format "evidence_map", title, summary, columns "Claim", "Evidence", "Source", "Limitation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 2. Claim check (Evidence)

```text
Create a Claim check for: [YOUR TOPIC OR SUPPLIED RECORDS].
Audit the main claims; distinguish supported, contradicted, and unverified statements with reasons.
Start with a direct answer. Use a research_panel JSON fence with format "claim_check", title, summary, columns "Claim", "Assessment", "Reason", "Source", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 3. Source conflicts (Evidence)

```text
Create a Source conflicts for: [YOUR TOPIC OR SUPPLIED RECORDS].
Find disagreements between sources and explain differences in dates, definitions, scope, and incentives.
Start with a direct answer. Use a research_panel JSON fence with format "source_conflicts", title, summary, columns "Disagreement", "Source A", "Source B", "Resolution", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 4. Source quality audit (Evidence)

```text
Create a Source quality audit for: [YOUR TOPIC OR SUPPLIED RECORDS].
Evaluate provenance, first-hand access, methodology, conflicts of interest, and limitations without inventing quality scores.
Start with a direct answer. Use a research_panel JSON fence with format "source_quality", title, summary, columns "Source", "Provenance", "Strength", "Limitation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 5. Freshness audit (Evidence)

```text
Create a Freshness audit for: [YOUR TOPIC OR SUPPLIED RECORDS].
Check publication date, event date, and underlying data period separately; identify stale information and newer replacements.
Start with a direct answer. Use a research_panel JSON fence with format "freshness_audit", title, summary, columns "Claim", "Published", "Data period", "Freshness", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 6. Primary-source brief (Evidence)

```text
Create a Primary-source brief for: [YOUR TOPIC OR SUPPLIED RECORDS].
Prioritize original filings, official releases, datasets, and first-hand statements; label secondary reporting.
Start with a direct answer. Use a research_panel JSON fence with format "primary_sources", title, summary, columns "Finding", "Primary source", "Date", "Caveat", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 7. Assumption ledger (Evidence)

```text
Create a Assumption ledger for: [YOUR TOPIC OR SUPPLIED RECORDS].
Expose assumptions underlying the conclusion, explain sensitivity, and state how each assumption could be tested.
Start with a direct answer. Use a research_panel JSON fence with format "assumptions", title, summary, columns "Assumption", "Why needed", "If wrong", "How to test", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 8. Unknowns register (Evidence)

```text
Create a Unknowns register for: [YOUR TOPIC OR SUPPLIED RECORDS].
Identify missing facts, why they matter, and the specific evidence needed to resolve them.
Start with a direct answer. Use a research_panel JSON fence with format "unknowns", title, summary, columns "Unknown", "Impact", "Evidence needed", "Next step", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 9. Counterevidence review (Evidence)

```text
Create a Counterevidence review for: [YOUR TOPIC OR SUPPLIED RECORDS].
Seek the strongest evidence against the leading interpretation and explain whether it changes the conclusion.
Start with a direct answer. Use a research_panel JSON fence with format "counterevidence", title, summary, columns "Thesis", "Counterevidence", "Strength", "Implication", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 10. Research plan (Evidence)

```text
Create a Research plan for: [YOUR TOPIC OR SUPPLIED RECORDS].
Turn the question into an ordered investigation with subquestions, evidence requirements, and completion criteria.
Start with a direct answer. Use a research_panel JSON fence with format "research_plan", title, summary, columns "Step", "Question", "Evidence needed", "Done when", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 11. Trading-session brief (Markets)

```text
Create a Trading-session brief for: [YOUR TOPIC OR SUPPLIED RECORDS].
Summarize the latest completed or active market session, market timezone, main drivers, and next catalysts. Label delayed quotes.
Start with a direct answer. Use a research_panel JSON fence with format "session_brief", title, summary, columns "Asset", "Observation", "As of", "Driver", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 12. Overnight changes (Markets)

```text
Create a Overnight changes for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare the most recent session with the previous close using dated evidence and explain what changed overnight.
Start with a direct answer. Use a research_panel JSON fence with format "overnight_changes", title, summary, columns "Market", "Prior close", "Latest observation", "Catalyst", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 13. Catalyst radar (Markets)

```text
Create a Catalyst radar for: [YOUR TOPIC OR SUPPLIED RECORDS].
Identify upcoming company and macro catalysts with confirmed dates, event timezone, transmission mechanism, and uncertainty.
Start with a direct answer. Use a research_panel JSON fence with format "catalyst_radar", title, summary, columns "Catalyst", "When / timezone", "Affected assets", "What to watch", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 14. Sector rotation (Markets)

```text
Create a Sector rotation for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare sector relative performance over a consistent window; distinguish price evidence from speculative explanations.
Start with a direct answer. Use a research_panel JSON fence with format "sector_rotation", title, summary, columns "Sector", "Period", "Relative performance", "Interpretation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 15. Cross-asset pulse (Markets)

```text
Create a Cross-asset pulse for: [YOUR TOPIC OR SUPPLIED RECORDS].
Connect stocks, rates, currencies, commodities, and credit using comparable timestamps and explicit causal caveats.
Start with a direct answer. Use a research_panel JSON fence with format "cross_asset", title, summary, columns "Asset class", "Observed move", "Timestamp", "Possible link", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 16. Liquidity conditions (Markets)

```text
Create a Liquidity conditions for: [YOUR TOPIC OR SUPPLIED RECORDS].
Assess spreads, depth, volume, financing, and relevant liquidity constraints with timestamps and data gaps.
Start with a direct answer. Use a research_panel JSON fence with format "liquidity", title, summary, columns "Measure", "Observation", "Period", "Constraint", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 17. Volatility regime (Markets)

```text
Create a Volatility regime for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare realized and implied volatility where supplied or retrieved; explain horizon and estimation methods.
Start with a direct answer. Use a research_panel JSON fence with format "volatility", title, summary, columns "Measure", "Horizon", "Value", "Interpretation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 18. Market breadth (Markets)

```text
Create a Market breadth for: [YOUR TOPIC OR SUPPLIED RECORDS].
Assess participation, concentration, advance-decline measures, and coverage of the available universe.
Start with a direct answer. Use a research_panel JSON fence with format "breadth", title, summary, columns "Indicator", "Universe", "As of", "Interpretation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 19. Event reaction (Markets)

```text
Create a Event reaction for: [YOUR TOPIC OR SUPPLIED RECORDS].
Separate pre-event expectations, actual release, immediate price response, and later interpretation.
Start with a direct answer. Use a research_panel JSON fence with format "event_reaction", title, summary, columns "Stage", "Evidence", "Timestamp", "Implication", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 20. Week-ahead outlook (Markets)

```text
Create a Week-ahead outlook for: [YOUR TOPIC OR SUPPLIED RECORDS].
Prepare a dated week-ahead watchlist with scheduled events, scenarios, and conditions to monitor.
Start with a direct answer. Use a research_panel JSON fence with format "weekly_outlook", title, summary, columns "Date", "Event", "Scenario", "Watch condition", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 21. Business model canvas (Fundamentals)

```text
Create a Business model canvas for: [YOUR TOPIC OR SUPPLIED RECORDS].
Explain customers, revenue streams, cost drivers, competitive positioning, and dependencies from primary evidence.
Start with a direct answer. Use a research_panel JSON fence with format "business_model", title, summary, columns "Dimension", "Finding", "Evidence", "Dependency", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 22. Revenue bridge (Fundamentals)

```text
Create a Revenue bridge for: [YOUR TOPIC OR SUPPLIED RECORDS].
Decompose growth into disclosed segment, volume, pricing, mix, and currency effects; do not invent missing contributions.
Start with a direct answer. Use a research_panel JSON fence with format "revenue_bridge", title, summary, columns "Driver", "Contribution", "Period", "Disclosure", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 23. Margin bridge (Fundamentals)

```text
Create a Margin bridge for: [YOUR TOPIC OR SUPPLIED RECORDS].
Explain changes in gross and operating margins using disclosed cost and mix drivers; reconcile units and periods.
Start with a direct answer. Use a research_panel JSON fence with format "margin_bridge", title, summary, columns "Driver", "Margin impact", "Period", "Evidence", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 24. Cash-flow quality (Fundamentals)

```text
Create a Cash-flow quality for: [YOUR TOPIC OR SUPPLIED RECORDS].
Reconcile earnings to operating cash flow and free cash flow, including working capital and one-offs.
Start with a direct answer. Use a research_panel JSON fence with format "cash_quality", title, summary, columns "Item", "Amount / units", "Period", "Quality implication", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 25. Balance-sheet resilience (Fundamentals)

```text
Create a Balance-sheet resilience for: [YOUR TOPIC OR SUPPLIED RECORDS].
Evaluate liquidity, debt maturities, covenants, and cash runway using reported dates and explicit assumptions.
Start with a direct answer. Use a research_panel JSON fence with format "balance_sheet", title, summary, columns "Measure", "Reported value", "As of", "Risk", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 26. Valuation sensitivity (Fundamentals)

```text
Create a Valuation sensitivity for: [YOUR TOPIC OR SUPPLIED RECORDS].
Present a valuation sensitivity grid with explicit inputs and scenarios; label hypothetical values and avoid unsupported targets.
Start with a direct answer. Use a research_panel JSON fence with format "valuation_sensitivity", title, summary, columns "Scenario", "Assumptions", "Implied value", "Sensitivity", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 27. Peer benchmark (Fundamentals)

```text
Create a Peer benchmark for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare genuinely comparable peers using consistent accounting periods, metric definitions, and currency.
Start with a direct answer. Use a research_panel JSON fence with format "peer_benchmark", title, summary, columns "Company", "Metric / period", "Value", "Comparability caveat", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 28. Capital allocation (Fundamentals)

```text
Create a Capital allocation for: [YOUR TOPIC OR SUPPLIED RECORDS].
Review investment, acquisitions, dividends, buybacks, and financing with evidence of returns and tradeoffs.
Start with a direct answer. Use a research_panel JSON fence with format "capital_allocation", title, summary, columns "Use of capital", "Amount / period", "Rationale", "Tradeoff", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 29. Management execution (Fundamentals)

```text
Create a Management execution for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare prior management commitments with reported outcomes, including misses and unresolved commitments.
Start with a direct answer. Use a research_panel JSON fence with format "management_execution", title, summary, columns "Commitment", "Date promised", "Outcome", "Evidence", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 30. Filing changes (Fundamentals)

```text
Create a Filing changes for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare supplied or retrieved filings and identify material changes in risks, policies, segments, and commitments.
Start with a direct answer. Use a research_panel JSON fence with format "filing_changes", title, summary, columns "Section", "Previous disclosure", "New disclosure", "Why it matters", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 31. Risk register (Risk)

```text
Create a Risk register for: [YOUR TOPIC OR SUPPLIED RECORDS].
List material risks with causal mechanisms, exposure, warning indicators, and practical mitigations.
Start with a direct answer. Use a research_panel JSON fence with format "risk_register", title, summary, columns "Risk", "Mechanism", "Warning indicator", "Mitigation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 32. Scenario tree (Risk)

```text
Create a Scenario tree for: [YOUR TOPIC OR SUPPLIED RECORDS].
Build base, upside, and downside scenarios with explicit triggers and assumptions; do not invent probabilities.
Start with a direct answer. Use a research_panel JSON fence with format "scenario_tree", title, summary, columns "Scenario", "Trigger", "Assumptions", "Consequence", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 33. Stress-test worksheet (Risk)

```text
Create a Stress-test worksheet for: [YOUR TOPIC OR SUPPLIED RECORDS].
Stress supplied exposures under explicit hypothetical shocks and show formulas, units, and missing inputs.
Start with a direct answer. Use a research_panel JSON fence with format "stress_test", title, summary, columns "Shock", "Exposure", "Calculation", "Estimated impact", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 34. Thesis invalidation (Risk)

```text
Create a Thesis invalidation for: [YOUR TOPIC OR SUPPLIED RECORDS].
State observable conditions that would invalidate the thesis and distinguish hard failures from noisy signals.
Start with a direct answer. Use a research_panel JSON fence with format "invalidation", title, summary, columns "Thesis component", "Invalidation condition", "Evidence to track", "Response", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 35. Position-sizing worksheet (Risk)

```text
Create a Position-sizing worksheet for: [YOUR TOPIC OR SUPPLIED RECORDS].
Use supplied capital, risk budget, entry, stop, fees, and contract multiplier to show sizing math; request missing values.
Start with a direct answer. Use a research_panel JSON fence with format "position_sizing", title, summary, columns "Input", "Value / units", "Formula", "Constraint", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 36. Concentration review (Risk)

```text
Create a Concentration review for: [YOUR TOPIC OR SUPPLIED RECORDS].
Assess supplied holdings for issuer, sector, currency, geography, and common-factor concentration.
Start with a direct answer. Use a research_panel JSON fence with format "concentration", title, summary, columns "Exposure", "Weight", "Shared driver", "Risk implication", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 37. Drawdown review (Risk)

```text
Create a Drawdown review for: [YOUR TOPIC OR SUPPLIED RECORDS].
Analyze supplied equity-curve drawdowns, recovery periods, and sequence risk without fabricating observations.
Start with a direct answer. Use a research_panel JSON fence with format "drawdown", title, summary, columns "Episode", "Peak / trough dates", "Drawdown", "Recovery", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 38. Correlation caveats (Risk)

```text
Create a Correlation caveats for: [YOUR TOPIC OR SUPPLIED RECORDS].
Evaluate diversification using available aligned returns and explain window, instability, and crisis correlations.
Start with a direct answer. Use a research_panel JSON fence with format "correlation", title, summary, columns "Pair / factor", "Window", "Observed relation", "Limitation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 39. Hedge tradeoffs (Risk)

```text
Create a Hedge tradeoffs for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare potential hedges by exposure addressed, cost, basis risk, liquidity, and failure conditions.
Start with a direct answer. Use a research_panel JSON fence with format "hedge_tradeoffs", title, summary, columns "Hedge", "Risk addressed", "Cost / tradeoff", "Failure mode", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 40. Trade pre-mortem (Risk)

```text
Create a Trade pre-mortem for: [YOUR TOPIC OR SUPPLIED RECORDS].
Imagine the thesis fails and enumerate plausible failure paths, early signals, and preventive checks.
Start with a direct answer. Use a research_panel JSON fence with format "pre_mortem", title, summary, columns "Failure path", "Early signal", "Preventive check", "Residual risk", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 41. Trade debrief (Journal)

```text
Create a Trade debrief for: [YOUR TOPIC OR SUPPLIED RECORDS].
Review supplied trade context, thesis, entry, management, exit, and process quality independently of PnL.
Start with a direct answer. Use a research_panel JSON fence with format "trade_debrief", title, summary, columns "Stage", "Observed behavior", "Process assessment", "Improvement", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 42. Execution audit (Journal)

```text
Create a Execution audit for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare planned and actual execution using supplied fills, timestamps, fees, and available benchmark data.
Start with a direct answer. Use a research_panel JSON fence with format "execution_audit", title, summary, columns "Execution", "Plan", "Actual", "Deviation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 43. Mistake patterns (Journal)

```text
Create a Mistake patterns for: [YOUR TOPIC OR SUPPLIED RECORDS].
Group repeated process errors in supplied journal records and quantify only supported frequencies.
Start with a direct answer. Use a research_panel JSON fence with format "mistake_patterns", title, summary, columns "Pattern", "Examples", "Frequency / sample", "Correction", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 44. Discipline scorecard (Journal)

```text
Create a Discipline scorecard for: [YOUR TOPIC OR SUPPLIED RECORDS].
Assess adherence to the user's actual written rules; mark rules not assessable rather than inventing scores.
Start with a direct answer. Use a research_panel JSON fence with format "discipline", title, summary, columns "Rule", "Observed evidence", "Adherence", "Action", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 45. Setup playbook (Journal)

```text
Create a Setup playbook for: [YOUR TOPIC OR SUPPLIED RECORDS].
Convert the described setup into observable prerequisites, trigger, invalidation, management, and review rules.
Start with a direct answer. Use a research_panel JSON fence with format "setup_playbook", title, summary, columns "Stage", "Rule", "Evidence required", "Exception", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 46. Pre-entry checklist (Journal)

```text
Create a Pre-entry checklist for: [YOUR TOPIC OR SUPPLIED RECORDS].
Create a practical pre-entry checklist with thesis, liquidity, event risk, sizing, and invalidation checks.
Start with a direct answer. Use a research_panel JSON fence with format "entry_checklist", title, summary, columns "Check", "Required evidence", "Pass condition", "Stop condition", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 47. Exit-plan worksheet (Journal)

```text
Create a Exit-plan worksheet for: [YOUR TOPIC OR SUPPLIED RECORDS].
Structure exits around supplied strategy rules, invalidation, time horizon, and risk limits.
Start with a direct answer. Use a research_panel JSON fence with format "exit_plan", title, summary, columns "Condition", "Action to consider", "Rationale", "Missing input", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 48. Weekly journal review (Journal)

```text
Create a Weekly journal review for: [YOUR TOPIC OR SUPPLIED RECORDS].
Summarize the supplied week of trades with sample size, supported metrics, process lessons, and next-week experiments.
Start with a direct answer. Use a research_panel JSON fence with format "weekly_review", title, summary, columns "Theme", "Evidence", "Lesson", "Next experiment", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 49. Behavioral-bias review (Journal)

```text
Create a Behavioral-bias review for: [YOUR TOPIC OR SUPPLIED RECORDS].
Identify possible behavioral patterns from journal evidence without diagnosing; include alternative explanations.
Start with a direct answer. Use a research_panel JSON fence with format "behavior_bias", title, summary, columns "Pattern", "Evidence", "Alternative explanation", "Practical check", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 50. Strategy experiment (Journal)

```text
Create a Strategy experiment for: [YOUR TOPIC OR SUPPLIED RECORDS].
Turn a trading hypothesis into a falsifiable test with data requirements, benchmark, costs, and out-of-sample plan.
Start with a direct answer. Use a research_panel JSON fence with format "experiment_design", title, summary, columns "Hypothesis", "Test design", "Success criterion", "Bias control", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 51. Executive brief (Explain)

```text
Create a Executive brief for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compress the research into the main answer, three strongest findings, implications, and unresolved questions.
Start with a direct answer. Use a research_panel JSON fence with format "executive_brief", title, summary, columns "Finding", "Evidence", "Implication", "Uncertainty", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 52. Beginner guide (Explain)

```text
Create a Beginner guide for: [YOUR TOPIC OR SUPPLIED RECORDS].
Explain the topic from first principles using plain language, a labeled hypothetical example, and common pitfalls.
Start with a direct answer. Use a research_panel JSON fence with format "beginner_guide", title, summary, columns "Concept", "Plain meaning", "Example", "Pitfall", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 53. Expert brief (Explain)

```text
Create a Expert brief for: [YOUR TOPIC OR SUPPLIED RECORDS].
Provide a technical synthesis with definitions, methods, limitations, and the evidence needed to challenge it.
Start with a direct answer. Use a research_panel JSON fence with format "expert_brief", title, summary, columns "Dimension", "Method / evidence", "Conclusion", "Limitation", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 54. Decision matrix (Explain)

```text
Create a Decision matrix for: [YOUR TOPIC OR SUPPLIED RECORDS].
Compare choices against explicit user priorities; show tradeoffs and avoid invented preference weights.
Start with a direct answer. Use a research_panel JSON fence with format "decision_matrix", title, summary, columns "Choice", "Strength", "Tradeoff", "Best fit", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 55. Contextual glossary (Explain)

```text
Create a Contextual glossary for: [YOUR TOPIC OR SUPPLIED RECORDS].
Define the essential terms in context, explain why they matter, and distinguish commonly confused concepts.
Start with a direct answer. Use a research_panel JSON fence with format "concept_glossary", title, summary, columns "Term", "Meaning", "Why it matters", "Common confusion", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 56. Worked example (Explain)

```text
Create a Worked example for: [YOUR TOPIC OR SUPPLIED RECORDS].
Show a reproducible step-by-step example with inputs, units, formulas, assumptions, and checks.
Start with a direct answer. Use a research_panel JSON fence with format "worked_example", title, summary, columns "Step", "Input", "Calculation", "Result / units", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 57. Myth versus evidence (Explain)

```text
Create a Myth versus evidence for: [YOUR TOPIC OR SUPPLIED RECORDS].
Test common misconceptions against evidence, clarify scope, and avoid presenting nuanced claims as absolutes.
Start with a direct answer. Use a research_panel JSON fence with format "myth_fact", title, summary, columns "Claim", "Evidence-based correction", "Context", "Source", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 58. Cause-and-effect map (Explain)

```text
Create a Cause-and-effect map for: [YOUR TOPIC OR SUPPLIED RECORDS].
Trace the proposed causal mechanism, distinguish correlation from causation, and identify confounders.
Start with a direct answer. Use a research_panel JSON fence with format "cause_effect", title, summary, columns "Cause", "Mechanism", "Potential effect", "Confounder", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 59. Action brief (Explain)

```text
Create a Action brief for: [YOUR TOPIC OR SUPPLIED RECORDS].
Translate the research into optional next steps, required inputs, dependencies, and observable completion criteria.
Start with a direct answer. Use a research_panel JSON fence with format "action_brief", title, summary, columns "Next step", "Input needed", "Dependency", "Completion criterion", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

## 60. Questions worth asking (Explain)

```text
Create a Questions worth asking for: [YOUR TOPIC OR SUPPLIED RECORDS].
Surface the most valuable unresolved questions and explain what answering each would change.
Start with a direct answer. Use a research_panel JSON fence with format "questions_to_ask", title, summary, columns "Question", "Why it matters", "Evidence needed", "Decision affected", rows (arrays of strings), evidence (objects with claim, sourceUrl, sourceTitle, publishedAt, eventDate), caveats (strings), and nextSteps (strings). Use up to 12 useful rows. Cite exact supporting links next to factual claims. State missing data explicitly. For current facts, search the web as of the current request date; compare publication, event, and data dates. Never treat an old source or an undated quote as live. Label estimates and hypothetical examples. Finish with three specific follow-up questions in a followups JSON fence.
```

