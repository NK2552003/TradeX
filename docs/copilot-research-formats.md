# Copilot research formats

60 curated output workflows. Each uses the research_panel contract with a specific instruction and column schema. Selecting a format creates an editable prompt; sending it uses the existing authenticated AI pipeline. These are research formats, not 60 independent integrations.

## 1. Evidence map (Evidence)

Map each material claim to the exact supporting source and explain what that source does and does not establish.

Output columns: Claim · Evidence · Source · Limitation.

## 2. Claim check (Evidence)

Audit the main claims; distinguish supported, contradicted, and unverified statements with reasons.

Output columns: Claim · Assessment · Reason · Source.

## 3. Source conflicts (Evidence)

Find disagreements between sources and explain differences in dates, definitions, scope, and incentives.

Output columns: Disagreement · Source A · Source B · Resolution.

## 4. Source quality audit (Evidence)

Evaluate provenance, first-hand access, methodology, conflicts of interest, and limitations without inventing quality scores.

Output columns: Source · Provenance · Strength · Limitation.

## 5. Freshness audit (Evidence)

Check publication date, event date, and underlying data period separately; identify stale information and newer replacements.

Output columns: Claim · Published · Data period · Freshness.

## 6. Primary-source brief (Evidence)

Prioritize original filings, official releases, datasets, and first-hand statements; label secondary reporting.

Output columns: Finding · Primary source · Date · Caveat.

## 7. Assumption ledger (Evidence)

Expose assumptions underlying the conclusion, explain sensitivity, and state how each assumption could be tested.

Output columns: Assumption · Why needed · If wrong · How to test.

## 8. Unknowns register (Evidence)

Identify missing facts, why they matter, and the specific evidence needed to resolve them.

Output columns: Unknown · Impact · Evidence needed · Next step.

## 9. Counterevidence review (Evidence)

Seek the strongest evidence against the leading interpretation and explain whether it changes the conclusion.

Output columns: Thesis · Counterevidence · Strength · Implication.

## 10. Research plan (Evidence)

Turn the question into an ordered investigation with subquestions, evidence requirements, and completion criteria.

Output columns: Step · Question · Evidence needed · Done when.

## 11. Trading-session brief (Markets)

Summarize the latest completed or active market session, market timezone, main drivers, and next catalysts. Label delayed quotes.

Output columns: Asset · Observation · As of · Driver.

## 12. Overnight changes (Markets)

Compare the most recent session with the previous close using dated evidence and explain what changed overnight.

Output columns: Market · Prior close · Latest observation · Catalyst.

## 13. Catalyst radar (Markets)

Identify upcoming company and macro catalysts with confirmed dates, event timezone, transmission mechanism, and uncertainty.

Output columns: Catalyst · When / timezone · Affected assets · What to watch.

## 14. Sector rotation (Markets)

Compare sector relative performance over a consistent window; distinguish price evidence from speculative explanations.

Output columns: Sector · Period · Relative performance · Interpretation.

## 15. Cross-asset pulse (Markets)

Connect stocks, rates, currencies, commodities, and credit using comparable timestamps and explicit causal caveats.

Output columns: Asset class · Observed move · Timestamp · Possible link.

## 16. Liquidity conditions (Markets)

Assess spreads, depth, volume, financing, and relevant liquidity constraints with timestamps and data gaps.

Output columns: Measure · Observation · Period · Constraint.

## 17. Volatility regime (Markets)

Compare realized and implied volatility where supplied or retrieved; explain horizon and estimation methods.

Output columns: Measure · Horizon · Value · Interpretation.

## 18. Market breadth (Markets)

Assess participation, concentration, advance-decline measures, and coverage of the available universe.

Output columns: Indicator · Universe · As of · Interpretation.

## 19. Event reaction (Markets)

Separate pre-event expectations, actual release, immediate price response, and later interpretation.

Output columns: Stage · Evidence · Timestamp · Implication.

## 20. Week-ahead outlook (Markets)

Prepare a dated week-ahead watchlist with scheduled events, scenarios, and conditions to monitor.

Output columns: Date · Event · Scenario · Watch condition.

## 21. Business model canvas (Fundamentals)

Explain customers, revenue streams, cost drivers, competitive positioning, and dependencies from primary evidence.

Output columns: Dimension · Finding · Evidence · Dependency.

## 22. Revenue bridge (Fundamentals)

Decompose growth into disclosed segment, volume, pricing, mix, and currency effects; do not invent missing contributions.

Output columns: Driver · Contribution · Period · Disclosure.

## 23. Margin bridge (Fundamentals)

Explain changes in gross and operating margins using disclosed cost and mix drivers; reconcile units and periods.

Output columns: Driver · Margin impact · Period · Evidence.

## 24. Cash-flow quality (Fundamentals)

Reconcile earnings to operating cash flow and free cash flow, including working capital and one-offs.

Output columns: Item · Amount / units · Period · Quality implication.

## 25. Balance-sheet resilience (Fundamentals)

Evaluate liquidity, debt maturities, covenants, and cash runway using reported dates and explicit assumptions.

Output columns: Measure · Reported value · As of · Risk.

## 26. Valuation sensitivity (Fundamentals)

Present a valuation sensitivity grid with explicit inputs and scenarios; label hypothetical values and avoid unsupported targets.

Output columns: Scenario · Assumptions · Implied value · Sensitivity.

## 27. Peer benchmark (Fundamentals)

Compare genuinely comparable peers using consistent accounting periods, metric definitions, and currency.

Output columns: Company · Metric / period · Value · Comparability caveat.

## 28. Capital allocation (Fundamentals)

Review investment, acquisitions, dividends, buybacks, and financing with evidence of returns and tradeoffs.

Output columns: Use of capital · Amount / period · Rationale · Tradeoff.

## 29. Management execution (Fundamentals)

Compare prior management commitments with reported outcomes, including misses and unresolved commitments.

Output columns: Commitment · Date promised · Outcome · Evidence.

## 30. Filing changes (Fundamentals)

Compare supplied or retrieved filings and identify material changes in risks, policies, segments, and commitments.

Output columns: Section · Previous disclosure · New disclosure · Why it matters.

## 31. Risk register (Risk)

List material risks with causal mechanisms, exposure, warning indicators, and practical mitigations.

Output columns: Risk · Mechanism · Warning indicator · Mitigation.

## 32. Scenario tree (Risk)

Build base, upside, and downside scenarios with explicit triggers and assumptions; do not invent probabilities.

Output columns: Scenario · Trigger · Assumptions · Consequence.

## 33. Stress-test worksheet (Risk)

Stress supplied exposures under explicit hypothetical shocks and show formulas, units, and missing inputs.

Output columns: Shock · Exposure · Calculation · Estimated impact.

## 34. Thesis invalidation (Risk)

State observable conditions that would invalidate the thesis and distinguish hard failures from noisy signals.

Output columns: Thesis component · Invalidation condition · Evidence to track · Response.

## 35. Position-sizing worksheet (Risk)

Use supplied capital, risk budget, entry, stop, fees, and contract multiplier to show sizing math; request missing values.

Output columns: Input · Value / units · Formula · Constraint.

## 36. Concentration review (Risk)

Assess supplied holdings for issuer, sector, currency, geography, and common-factor concentration.

Output columns: Exposure · Weight · Shared driver · Risk implication.

## 37. Drawdown review (Risk)

Analyze supplied equity-curve drawdowns, recovery periods, and sequence risk without fabricating observations.

Output columns: Episode · Peak / trough dates · Drawdown · Recovery.

## 38. Correlation caveats (Risk)

Evaluate diversification using available aligned returns and explain window, instability, and crisis correlations.

Output columns: Pair / factor · Window · Observed relation · Limitation.

## 39. Hedge tradeoffs (Risk)

Compare potential hedges by exposure addressed, cost, basis risk, liquidity, and failure conditions.

Output columns: Hedge · Risk addressed · Cost / tradeoff · Failure mode.

## 40. Trade pre-mortem (Risk)

Imagine the thesis fails and enumerate plausible failure paths, early signals, and preventive checks.

Output columns: Failure path · Early signal · Preventive check · Residual risk.

## 41. Trade debrief (Journal)

Review supplied trade context, thesis, entry, management, exit, and process quality independently of PnL.

Output columns: Stage · Observed behavior · Process assessment · Improvement.

## 42. Execution audit (Journal)

Compare planned and actual execution using supplied fills, timestamps, fees, and available benchmark data.

Output columns: Execution · Plan · Actual · Deviation.

## 43. Mistake patterns (Journal)

Group repeated process errors in supplied journal records and quantify only supported frequencies.

Output columns: Pattern · Examples · Frequency / sample · Correction.

## 44. Discipline scorecard (Journal)

Assess adherence to the user's actual written rules; mark rules not assessable rather than inventing scores.

Output columns: Rule · Observed evidence · Adherence · Action.

## 45. Setup playbook (Journal)

Convert the described setup into observable prerequisites, trigger, invalidation, management, and review rules.

Output columns: Stage · Rule · Evidence required · Exception.

## 46. Pre-entry checklist (Journal)

Create a practical pre-entry checklist with thesis, liquidity, event risk, sizing, and invalidation checks.

Output columns: Check · Required evidence · Pass condition · Stop condition.

## 47. Exit-plan worksheet (Journal)

Structure exits around supplied strategy rules, invalidation, time horizon, and risk limits.

Output columns: Condition · Action to consider · Rationale · Missing input.

## 48. Weekly journal review (Journal)

Summarize the supplied week of trades with sample size, supported metrics, process lessons, and next-week experiments.

Output columns: Theme · Evidence · Lesson · Next experiment.

## 49. Behavioral-bias review (Journal)

Identify possible behavioral patterns from journal evidence without diagnosing; include alternative explanations.

Output columns: Pattern · Evidence · Alternative explanation · Practical check.

## 50. Strategy experiment (Journal)

Turn a trading hypothesis into a falsifiable test with data requirements, benchmark, costs, and out-of-sample plan.

Output columns: Hypothesis · Test design · Success criterion · Bias control.

## 51. Executive brief (Explain)

Compress the research into the main answer, three strongest findings, implications, and unresolved questions.

Output columns: Finding · Evidence · Implication · Uncertainty.

## 52. Beginner guide (Explain)

Explain the topic from first principles using plain language, a labeled hypothetical example, and common pitfalls.

Output columns: Concept · Plain meaning · Example · Pitfall.

## 53. Expert brief (Explain)

Provide a technical synthesis with definitions, methods, limitations, and the evidence needed to challenge it.

Output columns: Dimension · Method / evidence · Conclusion · Limitation.

## 54. Decision matrix (Explain)

Compare choices against explicit user priorities; show tradeoffs and avoid invented preference weights.

Output columns: Choice · Strength · Tradeoff · Best fit.

## 55. Contextual glossary (Explain)

Define the essential terms in context, explain why they matter, and distinguish commonly confused concepts.

Output columns: Term · Meaning · Why it matters · Common confusion.

## 56. Worked example (Explain)

Show a reproducible step-by-step example with inputs, units, formulas, assumptions, and checks.

Output columns: Step · Input · Calculation · Result / units.

## 57. Myth versus evidence (Explain)

Test common misconceptions against evidence, clarify scope, and avoid presenting nuanced claims as absolutes.

Output columns: Claim · Evidence-based correction · Context · Source.

## 58. Cause-and-effect map (Explain)

Trace the proposed causal mechanism, distinguish correlation from causation, and identify confounders.

Output columns: Cause · Mechanism · Potential effect · Confounder.

## 59. Action brief (Explain)

Translate the research into optional next steps, required inputs, dependencies, and observable completion criteria.

Output columns: Next step · Input needed · Dependency · Completion criterion.

## 60. Questions worth asking (Explain)

Surface the most valuable unresolved questions and explain what answering each would change.

Output columns: Question · Why it matters · Evidence needed · Decision affected.

