# Product Requirements Document (PRD): Consumer Features & Legal Compliance Review
**Platform**: AlphaJournal (`alphajournal.in`)  
**Document Version**: 1.0 (Production Go-Live Scope)  
**Target Audience**: Legal Counsel, Chief Compliance Officer, Regulatory Advisors, Product & Engineering Leadership  
**Primary Jurisdictions**: India (Primary / Initial Launch), United States & Global (Secondary / Cross-Border)  
**Date of Assessment**: October 2026  

---

## Executive Summary & Legal Model Overview

### 1.1 Purpose of this Document
This Product Requirements Document (PRD) provides legal, regulatory, and compliance counsel with a comprehensive, exhaustive inventory of **all consumer-facing features** implemented in the **AlphaJournal** application (`alphajournal.in`). 

This document serves as the foundational technical and functional reference for:
1. Drafting and finalizing statutory documents (Terms of Service, Privacy Policy, Risk Disclosures, EULA, Community Guidelines, and Affiliate Agreements).
2. Verifying regulatory exemptions (e.g., non-advisory, non-brokerage SaaS classifications under SEBI and SEC frameworks).
3. Ensuring end-to-end statutory compliance with the **Digital Personal Data Protection Act, 2023 (DPDP Act)**, the **Digital Personal Data Protection Rules, 2025**, the **Information Technology Act, 2000 (and 2021 Intermediary Rules)**, the **Consumer Protection (E-Commerce) Rules, 2020**, and **RBI recurring mandate guidelines**.
4. Satisfying app store review mandates under **Apple App Store Review Guidelines** and **Google Play Developer Policies**.

---

### 1.2 Core Legal Operational Assertion & Regulatory Positioning

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                     AlphaJournal Legal Operational Boundary                            │
├────────────────────────────────────────┬───────────────────────────────────────────────┤
│        WHAT ALPHAJOURNAL IS            │           WHAT ALPHAJOURNAL IS NOT            │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ • Self-directed quantitative SaaS tool │ • NOT an Investment Adviser (SEBI RIA/SEC RIA)│
│ • Private trading journal & notebook   │ • NOT a Research Analyst (SEBI RA)            │
│ • Mathematical & financial calculator  │ • NOT a Broker-Dealer or Sub-broker           │
│ • Generative AI writing/study copilot  │ • NOT a Portfolio Manager / Asset Manager     │
│ • Community social & discussion forum  │ • NOT an Execution Venue / Order Router       │
│ • Educational market visualizer        │ • DOES NOT hold customer funds or securities  │
└────────────────────────────────────────┴───────────────────────────────────────────────┘
```

> [!IMPORTANT]
> **Strict Operational Boundary**: AlphaJournal is exclusively a technology and software platform designed to assist self-directed traders in logging, organizing, and analyzing their personal trading data. AlphaJournal does **not** execute trades, does **not** interface with live broker order APIs for automated execution, does **not** provide bespoke portfolio management, and does **not** issue personalized investment advice or buy/sell price targets.

---

### 1.3 System Architecture & Client Platforms

AlphaJournal is delivered across five client platforms via a single Flutter codebase:
- **Mobile Applications**: Apple iOS (App Store) and Google Android (Google Play Store).
- **Desktop Applications**: macOS and Windows Desktop.
- **Web Application**: Responsive Web application hosted at `alphajournal.in`.
- **Backend Infrastructure**: Supabase (PostgreSQL 15 with Row-Level Security, GoTrue Auth, Realtime WebSockets, Storage Buckets) augmented by Supabase Edge Functions (Deno/TypeScript) for webhook processing, AI proxying, and payment reconciliation.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   Client Layer                                         │
│                [iOS & Android Apps]                [Web & Desktop Clients]             │
├────────────────────────────────────────┬───────────────────────────────────────────────┤
│            Mobile Payments             │                 Web Payments                  │
│       RevenueCat SDK (In-App)          │            Razorpay Subscriptions             │
│   • Apple StoreKit 2 (Guideline 3.1.1) │        • UPI AutoPay (e-Mandate)              │
│   • Google Play Billing v7             │        • RuPay, Debit/Credit Cards            │
├────────────────────────────────────────┴───────────────────────────────────────────────┤
│                                Application Features                                    │
│  1. Auth & Profiles   2. Writing Desk (Journal, Strategies, Notes)  3. Calculators     │
│  4. Market Data       5. AI Assistant Copilot   6. Community Hub    7. Direct Messages │
│  8. Affiliate Program 9. Subscription & Billing 10. Privacy & Account Deletion        │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                 Backend Services                                       │
│  • Supabase Auth (JWT, Row-Level Security)   • Supabase Storage (Private/Public CDN)   │
│  • Edge Functions (Billing Webhooks, Gemini 1.5 AI Proxy, Quotas, RazorpayX Payouts)  │
│  • PostgreSQL Database (Encrypted at Rest, Strict Foreign Key & Quota Triggers)        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Consumer Feature Specifications & Legal Assessment

The consumer-facing features are organized into **12 distinct functional modules**. Each module is analyzed across:
- **Functional Description**: What the user sees and does.
- **Data Collected & Processed**: User inputs, system outputs, and persistence.
- **Third-Party Services & APIs**: External data processors.
- **Legal, Regulatory & Compliance Considerations**: Applicable laws and exposure.
- **Required Contractual Terms & Disclaimers**: Specific mitigations.

---

### Module 1: User Onboarding, Authentication & Account Lifecycle

#### 1.1 Functional Description
- **Self-Service Registration & Login**: Users register using Email and Password (`signup_page.dart`, `login_page.dart`).
- **OTP Verification**: Email-based One-Time Password (OTP) verification for account confirmation and password reset (`otp_verification_page.dart`, `forgot_password_page.dart`).
- **Role & Profile Modes**: User accounts default to the `customer` (Trader) role. Eligible users can request or toggle into `affiliate` partner mode (`UserProfileMode`).
- **Session Management**: Authenticated JWT tokens stored securely on device (iOS Keychain, Android EncryptedSharedPreferences, browser LocalStorage/HttpOnly cookies).
- **Self-Service Account Deletion**: Dedicated in-app account deletion flow (`delete_account_page.dart`) allowing permanent user initiated account and data eradication.

#### 1.2 Data Collected & Processed
- **Identity Data**: Email address, encrypted password hash (Argon2id/bcrypt handled by Supabase Auth), unique user UUID (`auth.uid()`).
- **Profile Data**: Display name, public handle/username, bio, avatar image (`avatars` storage bucket).
- **Metadata**: IP address, device user-agent, operating system, last sign-in timestamp.

#### 1.3 Third-Party Services Involved
- **Supabase Auth**: Authentication infrastructure, token issuance, and password recovery mailers.
- **Resend / SMTP Mail Relay**: Transactional OTP and verification email delivery.

#### 1.4 Legal & Regulatory Considerations
- **Age Requirement (Protection of Minors)**: 
  - *DPDP Act 2023 (Section 9)* prohibits processing of personal data of a child (under 18 years) that is likely to cause detrimental effect, and forbids tracking, behavioral monitoring, or targeted advertising directed at children.
  - *Contract Law*: Under the Indian Contract Act, 1872, agreements entered into by minors are void *ab initio*. Trading and financial tools must strictly require users to be at least 18 years of age.
- **Account Deletion Compliance**:
  - *Apple App Store Guideline 5.1.1(v)*: If an app supports account creation, it **must** offer account deletion within the app, including all associated personal data.
  - *Google Play Policy*: Apps that allow account creation must provide an in-app path AND an external web-based deletion link.
  - *DPDP Act 2023 (Section 12)* & *GDPR (Art. 17)*: Right to erasure of personal data upon request, unless retention is mandated by law.

#### 1.5 Required Disclaimers & Mitigations
- Checkbox affirmative consent at sign-up: *"I confirm I am at least 18 years of age and agree to the Terms of Service, Privacy Policy, and Trading Risk Disclaimer."*
- Explicit notice on Account Deletion screen detailing that deletion permanently deletes all private journal entries and notes, but transaction invoice records are retained for 8 years to comply with statutory accounting and tax regulations.

---

### Module 2: Writing Desk — Quantitative Trade Journaling & Analytics

#### 2.1 Functional Description
- **Manual Trade Execution Logging**: Users manually input trade records (`journal_editor_screen.dart`, `journal_page.dart`). Supported parameters:
  - Instrument/Symbol (e.g., NIFTY 50, RELIANCE, AAPL, BTC-USD).
  - Asset Class: Equities, Futures, Options, Currencies, Crypto, Commodities.
  - Direction: Long vs. Short.
  - Execution Parameters: Entry date/time, Exit date/time, Entry price, Exit price, Quantity/Lots, Stop Loss, Target price.
  - Financial Metrics: Gross PnL, Fees/Brokerage, Net PnL, Return on Investment (ROI %).
  - Qualitative Tags: Strategy setup tag, psychological/emotional state tag (e.g., Disciplined, FOMO, Revenge, Hesitant), execution grade (A/B/C).
  - Rich Markdown Notes: Post-trade review and trade thesis.
- **Chart Screenshot Attachments**: Uploading technical chart screenshots directly into trade records. Stored in private bucket `journal-attachments`.
- **Performance Dashboards**: Quantitative aggregations including Net Profit/Loss, Win Rate (%), Profit Factor, Expectancy, Average Risk-Reward Ratio, Maximum Drawdown, and interactive Calendar Heatmaps (`dashboard_page.dart`).
- **Quota Enforcements**:
  - *Free Tier*: Capped at 100 journal entries per month.
  - *Pro Tier*: Unlimited journal entries.

#### 2.2 Data Collected & Processed
- User financial trading logs, transaction prices, capital amounts, execution timestamps, chart images, trade psychology notes.
- Private storage links (`local-image://<user_id>/<entry_id>/<uuid>.webp`).

#### 2.3 Third-Party Services Involved
- **Supabase Storage**: Private image hosting with temporary signed URL resolution (1-hour expiry).

#### 2.4 Legal & Regulatory Considerations
- **No Automated Broker Execution / Custody**:
  - AlphaJournal does **not** link to broker execution APIs (e.g., Zerodha Kite Connect, Angel One SmartAPI, Interactive Brokers API) for automatic trade placement.
  - The platform does not hold broker API trading secrets or trade credentials, eliminating regulatory exposure under SEBI algorithmic trading guidelines or broker-dealer licensing rules.
- **Confidentiality of Financial Data**:
  - Trading logs represent proprietary trading intellectual property and confidential financial records of the user.
  - Enforced via PostgreSQL Row-Level Security (RLS): `auth.uid() = user_id`. No other user, including subscribers, can view private journal records.
- **Tax & Audit Disclaimers**:
  - Users may mistakenly believe AlphaJournal journal reports can be submitted directly as statutory tax returns.
  - PnL calculations do not account for individual tax deductions, carried-forward losses, or broker contract note reconciliations.

#### 2.5 Required Disclaimers & Mitigations
- In-app footer and export watermark: *"Trading journal logs and PnL metrics are computed based solely on user-entered values. They do not constitute official broker contract notes, audited financial statements, or tax advice. Reconcile all data with your registered broker."*

---

### Module 3: Writing Desk — Strategy Playbooks & Versioning

#### 3.1 Functional Description
- **Playbook Builder**: Structured creation of trading strategy frameworks (`strategy_editor_screen.dart`, `strategies_page.dart`).
- **Standardized Strategy Sections**: Setup preconditions, entry triggers, stop-loss rules, take-profit scaling, risk allocation limits, and historical market conditions.
- **Version Tracking**: Audit trail of strategy revisions over time (`strategy_versions` table) to observe rule modifications.
- **Trade-Strategy Linking**: Linking individual trade journal entries to a strategy to generate empirical performance metrics (e.g., "Breakout Strategy Win Rate: 64% over 45 trades").
- **Visibility Control**: Strategies remain strictly **Private** in the user's workspace unless the user explicitly marks them as **Public** and attaches them to a public Community post (`CONTEXT.md`).
- **Plan Limits**: Free tier limited to 1 live playbook; Pro tier allows unlimited playbooks with revision history.

#### 3.2 Data Collected & Processed
- Strategy rules, descriptive criteria, entry/exit checklists, version logs, aggregated performance numbers.

#### 3.3 Third-Party Services Involved
- Supabase Database & Storage.

#### 3.4 Legal & Regulatory Considerations
- **SEBI Unregistered Advisory & Algorithmic Trading Rules**:
  - Under SEBI (Investment Advisers) Regulations, 2013, publicly recommending a specific strategy with promised returns or systematic buy/sell signals without registration is illegal.
  - Strategy playbooks in AlphaJournal are user-defined checklists, not algorithmic trading scripts or black-box automated signal engines.
- **User-Generated Strategy Sharing Risk**:
  - When users publish strategies publicly to the Community, they might make unsubstantiated claims (e.g., "Guaranteed 40% monthly returns").
  - Under SEBI circulars and advertising standards, platforms that facilitate the dissemination of unverified performance metrics face regulatory scrutiny.

#### 3.5 Required Disclaimers & Mitigations
- Prominent banner on all Strategy screens and public views: *"Strategy playbooks represent self-directed trading hypotheses and qualitative checklists. Historical win rates and performance metrics reflect past user logs and are not predictive of future market returns. AlphaJournal does not endorse, verify, or audit any strategy."*
- Prohibit misleading performance promises in Community Guidelines.

---

### Module 4: Writing Desk — Research Notes & Rich Markdown Studio

#### 4.1 Functional Description
- **Markdown Writing Studio**: Full-featured note-taking environment for fundamental and technical market research (`note_editor_screen.dart`, `notes_screen.dart`).
- **Advanced Markdown Elements**: Integration of LaTeX mathematical equations (via KaTeX), Mermaid diagrams (flowcharts, sequence charts), inline chart blocks, and code snippets.
- **Template Gallery**: Pre-built research templates (Macro Analysis, Earnings Breakdown, Sector Rotation, Post-Mortem Review).
- **Document & PDF Export**: Client-side generation of branded PDF and Markdown exports (`MarkdownPdfExporter`) for personal printing or archiving.
- **Attachment Pipeline**: Drag-and-drop or file upload of chart images, compressed client-side to WebP (80% quality, max 1920×1080) and stored in `note-attachments`.
- **Plan Limits**: Free tier capped at 50 notes and 1 MB attachments; Pro tier has unlimited notes and 10 MB attachments.

#### 4.2 Data Collected & Processed
- User text, market theses, uploaded charts, tags, timestamps.

#### 4.3 Third-Party Services Involved
- Supabase Storage, local PDF rendering engine.

#### 4.4 Legal & Regulatory Considerations
- **Intellectual Property & Copyright Infringement**:
  - Users frequently copy-paste proprietary third-party research reports (e.g., Goldman Sachs, Morgan Stanley, Motilal Oswal) or paid newsletters into their private or public notes.
  - The platform must maintain clear copyright policies, prohibiting infringement, and establish safe harbor mechanisms under Section 79 of the IT Act and the DMCA.
- **Exported Document Disclaimers**:
  - If a user exports an AlphaJournal research note to PDF and distributes it externally (e.g., on Telegram, WhatsApp, or Twitter) to solicit money, the AlphaJournal brand could be misrepresented as the research author.

#### 4.5 Required Disclaimers & Mitigations
- All generated PDF exports automatically embed an un-editable footer: *"Created with AlphaJournal (alphajournal.in) for private personal study. Not an investment recommendation or institutional research report."*
- Terms of Service explicitly assign full liability to the user for any third-party copyrighted materials uploaded to the service.

---

### Module 5: Financial & Quantitative Calculators Suite (22 Calculators)

#### 5.1 Functional Description
AlphaJournal implements 22 specialized financial calculators (`lib/features/calculators/logic` and `ui`) across four domains:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                     AlphaJournal Financial Calculators Suite                           │
├─────────────────────┬──────────────────────┬────────────────────┬──────────────────────┤
│ 1. Trading & Risk   │ 2. Derivatives/Quant │ 3. Wealth/Personal │ 4. Indian Tax/Levies │
├─────────────────────┼──────────────────────┼────────────────────┼──────────────────────┤
│ • Position Size     │ • Black-Scholes      │ • SIP Compound     │ • Indian Brokerage   │
│ • Risk-to-Reward    │   Options Pricing    │ • Lumpsum Growth   │   (STT, CTT, GST,    │
│ • Margin Required   │ • Options Greeks     │ • PPF Accumulator  │   SEBI, Stamp Duty)  │
│ • PnL & Target      │   (Δ, Γ, Θ, ν, ρ)    │ • Fixed Deposit    │ • STCG (Sec. 111A)   │
│ • Pip Value (Forex) │ • Options PnL Matrix │ • Inflation Drag   │ • LTCG (Sec. 112A)   │
│ • Contract Value    │ • Pivot Points (5)   │ • Loan EMI Amort.  │ • Turnover Calculator│
│ • Fibonacci Ratios  │                      │ • CAGR Benchmark   │   (Tax Audit Limits) │
└─────────────────────┴──────────────────────┴────────────────────┴──────────────────────┘
```

1. **Trading & Risk**:
   - *Position Size Calculator*: Determines exact share/contract quantity based on account equity, maximum risk percentage (e.g., 1%), entry price, and stop loss.
   - *Risk-Reward Calculator*: Computes R:R ratio, required win-rate breakeven percentage, and risk per share.
   - *Margin Calculator*: Calculates leverage requirements across intraday and carryforward positions.
2. **Derivatives & Quantitative Models**:
   - *Black-Scholes Options Pricing Model*: Calculates theoretical pricing and Greeks for European call/put options:
     $$\text{Call} = S_0 N(d_1) - K e^{-rT} N(d_2), \quad \text{Put} = K e^{-rT} N(-d_2) - S_0 N(-d_1)$$
   - *Options PnL Matrix*: Multi-strike payoff tables mapping volatility and days-to-expiry changes.
   - *Technical Tools*: Fibonacci Retracement/Extension, 5 Pivot Point systems (Standard, Fibonacci, Camarilla, Woodie, Classic).
3. **Personal Wealth & Investment Planning**:
   - *SIP & Lumpsum Calculators*: Future value compounding projections.
   - *PPF & Fixed Deposit Calculators*: Statutory interest accrual models.
   - *Inflation & EMI Amortization*: Purchasing power decay and debt repayment schedules.
4. **Indian Statutory & Regulatory Tax Levies**:
   - *Brokerage & Regulatory Turnover Calculator*: Computes full transaction costs under Indian exchange and statutory rules: Securities Transaction Tax (STT / CTT), Exchange Transaction Charges (NSE/BSE), SEBI Turnover Fees, 18% GST on brokerage + transaction charges, and State Stamp Duty.
   - *Short-Term Capital Gains (STCG)*: Computes tax under Section 111A (15% / revised 20% Budget 2024 rates).
   - *Long-Term Capital Gains (LTCG)*: Computes tax under Section 112A (10% / revised 12.5% rates above statutory exemptions).
   - *Income Tax Turnover Calculator*: Computes presumptive taxation turnover under Section 44AD / 44ADA for F&O traders.

#### 5.2 Data Collected & Processed
- Numeric calculation parameters (account size, strike prices, purchase prices, risk limits). Data is computed client-side in memory; optional draft saving to journal.

#### 5.3 Third-Party Services Involved
- None. All calculations are executed locally via client-side Dart mathematical libraries.

#### 5.4 Legal & Regulatory Considerations
- **No Professional Financial or Tax Advice**:
  - Providing tax liability estimates (STCG, LTCG, Section 44AD turnover) could be construed as unauthorized tax preparation or accounting advice.
  - Statutory rates change frequently (e.g., Union Budget 2024 revisions to STT, STCG, and LTCG). Calculations may diverge from final tax returns.
- **Model Risk & Limitations (Black-Scholes & Greeks)**:
  - The Black-Scholes model relies on theoretical assumptions (log-normal distribution of returns, constant volatility, frictionless markets, European exercise style). Real-world equity options in India are European on indices (NIFTY) but American-style on stock options; volatility skews and dividend distributions alter real-world pricing.
  - Traders relying blindly on calculator outputs who incur losses could allege misrepresentation.

#### 5.5 Required Disclaimers & Mitigations
- Dedicated permanent disclaimer embedded at the bottom of every calculator view:
  > **Statutory Disclaimer**: *"All calculations, outputs, and projections provided herein are for educational and illustrative purposes only. They are based on mathematical formulas and user-supplied parameters. Black-Scholes values reflect theoretical models and may diverge significantly from live market pricing. Tax and turnover estimates do not constitute certified tax advice under the Income Tax Act, 1961. Consult a licensed Chartered Accountant (CA) or certified financial planner before acting on any calculation."*

---

### Module 6: Market Intelligence, Screeners & Data Visualizations

#### 6.1 Functional Description
- **Market Overview & Visualizations**: Displays world index cards (S&P 500, Nasdaq, Nifty 50, Sensex, Gold, Bitcoin), market sector heatmaps, top gainers and losers, and symbol snapshots (`market_overview_view.dart`, `market_root_screen.dart`).
- **Watchlists**: User-curated lists of tracked financial instruments with price and change indicators (`watchlists_page.dart`).
- **Screeners**: Pre-filtered multi-asset screeners (e.g., high volatility, 52-week highs/lows).
- **News Aggregator**: Headlines and summary snippets of financial market news (`market_news_widgets.dart`).
- **Data Source**: Integrated via `YahooFinanceService` (`yahoo_finance_service.dart`) and client visualizers (`yahoo_market_ribbon.dart`).

#### 6.2 Data Collected & Processed
- User watchlist symbol selections, search queries. Market quotes (OHLC, volume, percentage change) streamed or polled.

#### 6.3 Third-Party Services Involved
- **Yahoo Finance API / Public Endpoints**: Market quotes, historical candles, and news feeds.

#### 6.4 Legal & Regulatory Considerations
- **Exchange Data Licensing Terms**:
  - Major stock exchanges (NSE, BSE, NASDAQ, NYSE, CME, LSE) enforce strict intellectual property rights over market data feeds. Commercial redistribution of real-time quotes requires an official data vendor redistribution license.
  - Public web endpoints (such as Yahoo Finance) provide quotes that are typically delayed by 15 minutes and restricted to non-commercial personal viewing.
  - Advertising "real-time tick data" or "live broker execution feeds" without valid commercial exchange redistribution agreements creates severe legal and financial liability.
- **Copyright in News Aggregation**:
  - Displaying news headlines and brief summaries is generally permissible under doctrine of fair use/fair dealing, provided source attribution is explicit and links direct users to the original publisher. Full-text scraping of articles without a licensing agreement constitutes copyright infringement.

#### 6.5 Required Disclaimers & Mitigations
- Prominent persistent banner on all Market pages and quotes: *"Market data and quotes may be delayed up to 15-20 minutes in accordance with exchange reporting rules. Data is provided by third-party sources 'as-is' for informational reference only, and not for live trading execution. AlphaJournal is not an authorized exchange data feed vendor."*
- Ensure news widgets only display the original headline, publication name, timestamp, and a hyperlink opening the article in the publisher's external web browser.

---

### Module 7: AI Copilot & Creation Studio (Generative AI Assistant)

#### 7.1 Functional Description
- **Conversational Trading Assistant**: Multi-turn chat interface (`ai_chat_view.dart`) allowing users to ask trading theory questions, risk management strategies, and quantitative math explanations.
- **Specialized Trading Personas**: User-selectable persona models (`ai_persona_selector.dart`):
  1. *Momentum Scalper*: Focused on high-speed intraday execution, tape reading, and order flow theory.
  2. *Swing Strategist*: Multi-day setups, chart patterns, and support/resistance zones.
  3. *Macro Economist*: Interest rates, central bank policies, inflation, and global yield curves.
  4. *Options Quant*: Volatility spreads, Greeks, hedging, and mathematical expectancy.
- **Creation Studio (5 Structured Workflows)**: Dedicated AI generators (`ai_create_view.dart`):
  1. *Draft Research Note*: Converts raw market thoughts into structured markdown notes.
  2. *Draft Journal Entry*: Parses trade numbers into a comprehensive post-trade reflection.
  3. *Draft Strategy Playbook*: Structures trading rules into an actionable checklist.
  4. *Draft Community Post*: Generates public discussion posts summarizing trade ideas.
  5. *Technical Chart Analysis*: Analyzes user-described chart patterns and price action.
- **Inline Editor Copilot**: Selection toolbar in Markdown editors allowing instant text expansion, summarization, proofreading, and risk audits.
- **Rate Limiting & Tier Quotas**:
  - *Free Tier*: Capped at 2 queries per day, maximum 20 queries per month.
  - *Pro Tier*: 500 queries per month. Enforced atomically via Supabase PostgreSQL function `check_and_deduct_ai_quota`.

#### 7.2 Data Collected & Processed
- User text prompts, draft notes, selected persona, conversation history (`ai_messages` table), monthly quota usage (`ai_quotas` table).
- Data transmitted securely via authenticated HTTPS POST (`/functions/v1/ai-copilot`) using user Supabase JWT.

#### 7.3 Third-Party Services Involved
- **Google Cloud / Google Gemini API (Gemini 1.5 Flash / Pro)**: Foundation LLM processing prompts and returning streaming Server-Sent Events (SSE).

#### 7.4 Legal & Regulatory Considerations
- **SEBI & Global Ban on Unregistered Automated Investment Advice**:
  - Regulators worldwide (SEBI in India, SEC/FINRA in the US, ESMA in Europe) strictly regulate algorithmic or AI-driven investment advice.
  - If the AI Copilot outputs specific buy/sell calls (e.g., *"Buy NIFTY 24500 Call at ₹120, target ₹180, stop loss ₹95"*), it crosses the legal line into **unregistered Investment Advisory** or **unregistered Research Analysis**, exposing the company to regulatory prosecution, hefty fines, and platform bans.
  - The AI must be constrained via strict system prompts to act strictly as an educational assistant and writing tool.
- **AI Hallucinations, Errors & Fiduciary Disclaimers**:
  - Generative LLMs hallucinate financial facts, misquote prices, calculate mathematical errors, and misinterpret market conditions.
  - If a user suffers financial bankruptcy following an AI recommendation, the platform must have robust liability shields.
- **Privacy & Data Protection with Third-Party LLMs**:
  - Under the DPDP Act 2023 and GDPR, transferring user trade logs and notes to third-party AI sub-processors (Google) requires explicit notice.
  - Confidential trading data must not be ingested into public models to train future commercial AI without consent.

#### 7.5 Required Disclaimers & Mitigations
- **Hardcoded System Prompt Enforcements**:
  > *"You are an educational assistant and writing tool for self-directed traders. You NEVER provide financial investment advice, personal portfolio recommendations, buy/sell calls, price targets, or financial guarantees. Always instruct users to conduct their own independent due diligence."*
- **In-App Visual Warning**: Banner displayed above AI chat input: *"AI output is computer-generated for educational brainstorming only. AI may produce inaccurate or biased information. Never execute financial trades based on AI outputs."*
- **Contractual Liability Exclusion**: Explicit waiver in Terms of Service holding AlphaJournal harmless from any direct, indirect, or consequential losses arising from AI-generated text or analysis.

---

### Module 8: Community Social Network, Public Feeds & User-Generated Content (UGC)

#### 8.1 Functional Description
- **Community Feed & Discovery**: Public activity feed displaying posts, polls, trade setups, and market commentary (`community_feed_view.dart`, `community_explore_view.dart`).
- **Post Attachments**: Users can attach a single **Public Writing Record** (a public Note, Trade Journal, or Strategy Playbook) to their post (`CONTEXT.md`).
- **Social Engagement**: Likes, comment threads, post bookmarking, user following/follower graphs, and hashtag indexing (`#nifty`, `#priceaction`).
- **User Profiles**: Public trader profile showing public posts, verified tier badge, follower counts, and shared public records (`community_profile_view.dart`).
- **Moderation Architecture**:
  - Content workflow: Posts and comments enter a `pending` status upon creation.
  - Public visibility requires `approved` status, reviewable via Admin Console (`community_moderation_list_page.dart`).
  - User controls: Block user (`blocked_users_page.dart`), report offensive content, hide posts.

#### 8.2 Data Collected & Processed
- Public post text, poll options, votes, comments, user follow relationships, block lists, reports, uploaded public images (`community-attachments` storage bucket).

#### 8.3 Third-Party Services Involved
- Supabase Database (PostgreSQL RLS), Supabase Storage (Public CDN bucket).

#### 8.4 Legal & Regulatory Considerations
- **Intermediary Liability Safe Harbor**:
  - Under **Section 79 of the Indian Information Technology Act, 2000**, an intermediary is protected from liability for third-party UGC *only if* it observes statutory due diligence and complies with the **IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021**.
  - Under **Section 230 of the US Communications Decency Act (CDA)** and **EU Digital Services Act (DSA)**, similar safe harbor protections require proactive notice-and-takedown systems.
- **Market Manipulation, 'Finfluencers', & Pump-and-Dump Schemes**:
  - Bad actors frequently exploit financial community forums to coordinate "pump-and-dump" schemes, disseminate false rumors regarding penny stocks, or run illegal "stock tip" advisory services.
  - SEBI's 2024–2025 regulatory crackdowns on unregistered financial influencers ("finfluencers") place direct pressure on platforms hosting financial discussions.
- **Statutory Takedown Timelines (India IT Rules 2021)**:
  - The platform must appoint a named **Grievance Officer** resident in India.
  - Complaints must be acknowledged within **24 hours** and resolved within **15 days** (or **36 hours** for court/government takedown orders regarding prohibited content).
- **Prohibited Content Categories**:
  - Defamation, hate speech, obscenity, copyright infringement, financial fraud, impersonation, content threatening national security or public order.

#### 8.5 Required Disclaimers & Mitigations
- Mandatory acceptance of **Community Guidelines & Content Policy** prior to first post.
- In-feed disclaimer: *"Community posts reflect the personal opinions of individual users and do not represent the views or recommendations of AlphaJournal. Beware of unauthorized stock tips, pump-and-dump schemes, and unsolicited investment solicitations. Verify all ideas independently."*
- Implement pre-moderation / automated keyword filtering for common spam/fraud phrases (e.g., "100% guaranteed profit", "join private WhatsApp/Telegram for calls").

---

### Module 9: Direct Messaging & Real-Time Communications

#### 9.1 Functional Description
- **1-on-1 Trader Chat**: Private real-time messaging between mutual followers (`messages_thread_view.dart`, `messages_inbox_view.dart`).
- **Rich Interaction**: Text messaging, emoji reactions, in-chat record sharing (sharing a public trade record or note link).
- **Message Requests & Safety**: Inbound messages from non-followed users land in a "Requests" folder (`messages_requests_view.dart`) requiring explicit acceptance.
- **Archive & Block**: Capability to mute, archive, or permanently block abusive interlocutors.
- **Plan Gating**: Direct messaging is restricted to active **Pro** tier subscribers to prevent mass-spamming and bot solicitation.

#### 9.2 Data Collected & Processed
- Private message content, sender/receiver UUIDs, message timestamps, read receipts, shared record links. Stored in Supabase `direct_messages` table.

#### 9.3 Third-Party Services Involved
- **Supabase Realtime**: WebSocket connection for instantaneous message delivery.

#### 9.4 Legal & Regulatory Considerations
- **Expectation of Privacy vs. Abuse Prevention**:
  - Users have an expectation of privacy in 1-on-1 direct messages.
  - However, direct messages can be abused for harassment, extortion, sharing malicious links, or soliciting illegal off-platform investment schemes.
  - The Terms of Service must clearly state that while messages are private from other users, AlphaJournal reserves the right to review messages in response to user reports or to comply with court orders and law enforcement subpoenas.
- **Law Enforcement Cooperation**:
  - Compliance with lawful requests from law enforcement agencies under Section 91 of the Code of Criminal Procedure (CrPC) / Bharatiya Nagarik Suraksha Sanhita (BNSS) in India.

#### 9.5 Required Disclaimers & Mitigations
- In-chat safety notice displayed at the top of every new thread: *"Security Reminder: Never share sensitive financial credentials, broker passwords, UPI PINs, or transfer money to anyone via Direct Messages. AlphaJournal staff will never ask for your private passwords."*

---

### Module 10: Affiliate Partner & Creator Monetization Program

#### 10.1 Functional Description
- **Affiliate Partner Workspace**: Separate role-gated workspace (`UserRole.affiliate`) accessible to approved partners (`affiliate_overview_page.dart`).
- **Campaign Studio & UTM Tracking**: Affiliates generate custom referral tracking links with UTM parameters (`https://alphajournal.in/r/slug?utm_source=...`) across channels (YouTube, Instagram, Newsletter, Website) (`affiliate_marketing_page.dart`).
- **Custom Vanity Slugs**: Pro affiliates can register unique brand slugs (`/r/creator-name`).
- **Commission Structure**:
  - *Standard Partner*: 15% recurring revenue share on referred paid subscriptions.
  - *Pro Creator Partner*: Up to 30%–35% recurring revenue share (for high-volume creators with 25+ active referrals).
- **Payout Engine & Destinations**:
  - Payout methods supported: **UPI VPA** (`creator@upi`), **Bank Account NEFT/IMPS** (Account Number, IFSC, Beneficiary Name), or Razorpay.
  - Minimum payout threshold enforced: **₹1,000 INR**.
  - Payout lifecycle states: `pending` → `processing` → `paid` (with bank transaction reference number).
  - Payout execution: Disbursed via **RazorpayX Payouts API** (`AffiliatePayoutsPage`).

#### 10.2 Data Collected & Processed
- Partner legal name, email, phone number, PAN (Permanent Account Number), GSTIN (if applicable), bank account details / UPI VPA, referral click counts, conversion logs, payout history, generated tax certificates.

#### 10.3 Third-Party Services Involved
- **RazorpayX**: Automated banking API for instant UPI/IMPS commission payouts.

#### 10.4 Legal & Regulatory Considerations
- **SEBI Regulations on Financial Influencer Partnerships (2024–2025)**:
  - SEBI has cracked down on unregistered financial influencers who offer stock recommendations while partnering with trading platforms.
  - While AlphaJournal is an educational recording tool and not a broker, AlphaJournal **must** legally forbid affiliate partners from bundling AlphaJournal referral links with unregistered advisory services, paid tips groups (e.g. VIP Telegram channels), or promised returns.
- **ASCI (Advertising Standards Council of India) Guidelines**:
  - The ASCI Guidelines for Influencer Advertising mandate that all affiliates must clearly and prominently disclose commercial partnerships across all social media posts and videos using tags like `#ad`, `#sponsored`, or `#affiliate`.
- **Taxation & Statutory TDS Compliance (Section 194H of Income Tax Act)**:
  - Under Section 194H of the Indian Income Tax Act, 1961, commission or brokerage payments made to residents exceeding ₹15,000 in a financial year are subject to **Tax Deducted at Source (TDS)**.
  - *Statutory Rate Alignment*: While older code or templates referenced 5%, the current statutory rate under Section 194H is **2%** (effective from October 1, 2024). Legal and tax counsel must harmonize the exact rate across database triggers, payout statements, and Form 16A certificates.
  - Collection of valid PAN is mandatory; failure to provide PAN triggers maximum marginal withholding (20% under Section 206AA).
- **Anti-Fraud & Self-Dealing Rules**:
  - Prohibiting self-referrals (signing up via one's own affiliate link to gain a discount).
  - Bidding on brand trademarks ("AlphaJournal", "alphajournal.in") on Google Ads or search engines.

#### 10.5 Required Disclaimers & Mitigations
- Dedicated **Affiliate Program Agreement** executed digitally by all affiliates before generating links.
- Clause permitting immediate termination and forfeiture of unpaid balances if an affiliate makes false claims, promises trading returns, or fails to disclose affiliate relationships.

---

### Module 11: Consumer Subscriptions, Invoicing & Dual-Rail Payments

#### 11.1 Functional Description
- **Self-Serve Subscription Plans**:
  - *AlphaJournal Free*: ₹0 / month. Core journaling (100 trades), 20 AI queries/mo, basic calculators.
  - *AlphaJournal Pro*: ₹2,499 / month or ₹23,988 / year (equivalent to ₹1,999/mo, 20% savings). Unlimited journaling, 500 AI queries/mo, full persona access, PDF export, direct messaging.
  - *Business / Institutional*: Tier reserved for teams and institutional desks.
- **Dual-Rail Billing Infrastructure**:
  - **Mobile In-App Purchases (iOS & Android)**: Handled exclusively via **RevenueCat SDK** (`purchases_flutter`), integrating Apple StoreKit 2 and Google Play Billing v7.
  - **Web & Desktop Subscriptions (macOS/Windows/Web)**: Handled via **Razorpay Subscriptions** (`razorpay-checkout`), supporting Indian UPI AutoPay recurring mandates, Credit/Debit cards, NetBanking.
- **Self-Service Billing Management**:
  - View subscription status, renew date, active tier meters (`billing_settings_page.dart`).
  - Upgrade/Downgrade plans (`change_plan_page.dart`).
  - Download itemized PDF tax invoices (`billing_history_page.dart`, `invoice_detail_page.dart`).
- **Backend Webhook Synchronization**:
  - Secure Edge Functions (`/functions/v1/billing-webhook`, `/functions/v1/revenuecat-webhook`) reconcile payments, update `profiles.subscription_tier`, and provision quotas. Paid access cannot be granted by client-side code alone.

#### 11.2 Data Collected & Processed
- Subscription tier, provider customer ID, provider subscription ID, renewal date, expiration date, billing cycle (monthly/annual), transaction amounts in INR (₹), 18% GST itemization, billing address, invoice PDFs.
- *Credit/debit card numbers are never collected, stored, or processed by AlphaJournal servers* (handled entirely by PCI-DSS compliant providers: Apple, Google, Razorpay).

#### 11.3 Third-Party Services Involved
- **Apple StoreKit 2** (iOS in-app billing).
- **Google Play Billing** (Android in-app billing).
- **RevenueCat** (Mobile entitlement validation & receipt verification).
- **Razorpay** (Web recurring mandates & merchant payment gateway).

#### 11.4 Legal & Regulatory Considerations
- **App Store Policy Compliance**:
  - *Apple App Store Review Guideline 3.1.1*: Digital features unlocked within iOS apps (unlimited journaling, AI queries, cloud storage) **must** utilize Apple In-App Purchase. Directing iOS users to an external website to pay is strictly prohibited unless qualifying for specific multiplatform exemptions.
  - *Google Play Payments Policy*: Enforces Google Play Billing for in-app digital goods.
- **Consumer Protection (E-Commerce) Rules, 2020 (India)**:
  - Transparent pricing: Total price inclusive of all applicable statutory charges (18% GST: 9% CGST + 9% SGST or 18% IGST) must be clearly stated prior to purchase confirmation.
  - Mandatory disclosure of merchant legal entity, registered office address, customer support contact, and ticket tracking mechanism.
- **RBI Recurring Mandate / E-Mandate Guidelines**:
  - Recurring debits on Indian cards and UPI AutoPay require customer authorization via AFA (Additional Factor of Authentication).
  - Pre-debit notifications must be sent at least 24 hours prior to actual card debit. Handled in coordination with Razorpay.
- **Dark Patterns Prohibition (CCPA India 2023 Guidelines)**:
  - Regulations strictly prohibit deceptive UX patterns: "Subscription Traps" (making cancellation excessively onerous compared to sign-up), "Forced Action", and "Basket Sneaking".
  - Cancellation must be frictionless and accessible directly within the app settings.
- **Refund Jurisdictions**:
  - Mobile store purchases (Apple/Google) are subject to Apple and Google refund policies; developers cannot directly issue cash refunds for StoreKit charges.
  - Web payments through Razorpay are governed by AlphaJournal's direct **Subscription Cancellation & Refund Policy**.

#### 11.5 Required Disclaimers & Mitigations
- Clear pre-purchase disclosure modal displaying: Subscription amount, 18% GST breakdown, next renewal date, and explicit notice: *"You can cancel anytime in Account Settings or Google Play / Apple Subscriptions."*
- Prominent link to **Subscription Cancellation and Refund Policy** at checkout.

---

### Module 12: Account Settings, Privacy Controls & Data Deletion

#### 12.1 Functional Description
- **Profile & Appearance Settings**: Edit display name, avatar, theme mode (Dark/Light), layout options (`profile_settings_page.dart`, `appearance_settings_page.dart`).
- **Security Settings**: Password change, active session review, two-factor authentication toggles (`account_security_page.dart`).
- **Privacy & Data Governance**: Granular controls over profile visibility, search indexing, and marketing preferences (`privacy_settings_page.dart`).
- **Safety Controls**: Blocked users management list (`blocked_users_page.dart`).
- **Data Export & Portability**: Ability to request an archive export of all personal trading data, journal entries, and notes.
- **Account Deletion Flow**: Multi-step confirmation dialog warning of permanent data loss, requiring password re-authentication before triggering database cascades (`delete_account_page.dart`).

#### 12.2 Data Collected & Processed
- Security logs, notification preferences, privacy toggles, block lists, deletion audit log.

#### 12.3 Third-Party Services Involved
- Supabase Database & Auth.

#### 12.4 Legal & Regulatory Considerations
- **DPDP Act 2023 & GDPR Data Principal Rights**:
  - Right to Access summary of personal data processed.
  - Right to Correction and Erasure of outdated or inaccurate data.
  - Right to Grievance Redressal.
  - Right to Nominate another individual in the event of death or incapacity.
- **Statutory Data Retention Exceptions**:
  - While user content (notes, journal trades, messages) is eradicated immediately upon account deletion, transaction receipts, invoice numbers, tax withholdings, and audit logs **must** be retained for up to 8 years under Section 44AA of the Income Tax Act, 1961, and the Companies Act, 2013.

#### 12.5 Required Disclaimers & Mitigations
- Explicit explanation in the Deletion Confirmation dialog detailing what is purged immediately (journals, notes, community posts, messages) versus what is legally retained (tax invoices and fraud audit logs).

---

## Consolidated Legal & Regulatory Compliance Analysis

### 2.1 Securities & Financial Regulatory Framework (SEBI / SEC)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                    Securities Regulatory Compliance Matrix                             │
├─────────────────────────┬──────────────────────┬───────────────────────────────────────┤
│ Regulation / Statute    │ Regulatory Threshold │ AlphaJournal Compliance Architecture  │
├─────────────────────────┼──────────────────────┼───────────────────────────────────────┤
│ SEBI (Investment        │ Providing advice on  │ • NO personalized recommendations.    │
│ Advisers) Regulations,  │ securities for       │ • NO model portfolios.                │
│ 2013 (India)            │ remuneration.        │ • All calculations are self-directed. │
├─────────────────────────┼──────────────────────┼───────────────────────────────────────┤
│ SEBI (Research          │ Publishing research  │ • NO target prices or buy/sell calls. │
│ Analysts) Regulations,  │ reports or target    │ • Market data is delayed reference.   │
│ 2014 (India)            │ recommendations.     │ • News feeds link to source outlets.  │
├─────────────────────────┼──────────────────────┼───────────────────────────────────────┤
│ SEBI Algorithmic & F&O  │ Automated order      │ • NO broker trading API integration.  │
│ Order Execution Rules   │ routing & execution. │ • NO automated execution algorithms.  │
├─────────────────────────┼──────────────────────┼───────────────────────────────────────┤
│ US Investment Advisers  │ Engaged in business  │ • Publisher's Exclusion: general,     │
│ Act of 1940 (SEC)       │ of advising others.  │   impersonal financial software tool. │
└─────────────────────────┴──────────────────────┴───────────────────────────────────────┘
```

#### Regulatory Protection Strategy:
1. **Publisher's Exclusion**: Under landmark US jurisprudence (*Lowe v. SEC*, 472 U.S. 181) and Indian regulatory principles, general, impersonal analysis and tools offered to subscribers without personalized client portfolio tailoring do not constitute investment advice.
2. **Contractual Status Declaration**: The Terms of Service must state unequivocally: *"AlphaJournal is not registered as an Investment Adviser or Research Analyst with SEBI, the SEC, or any financial authority. The platform provides software tools for personal record-keeping, technical study, and mathematical calculation only."*

---

### 2.2 Data Privacy & Protection (DPDP Act 2023 / GDPR)

Under the **Digital Personal Data Protection Act, 2023 (India)**:
- **Role of AlphaJournal**: AlphaJournal operates as a **Data Fiduciary**, determining the purpose and means of processing personal data.
- **Notice & Consent (Section 5 & 6)**: Prior to processing personal data, clear and separate notice must be given in plain language describing the personal data collected, purpose of processing, how to exercise rights, and grievance officer contact details.
- **Reasonable Security Safeguards (Section 8)**: Preventing data breaches through PostgreSQL Row-Level Security, HTTPS/TLS 1.3 encryption in transit, encrypted storage at rest, and signed expiring URLs for private media.
- **Data Breach Notification (Section 8(6))**: In the event of a personal data breach, intimate the Data Protection Board of India and affected users without delay.
- **CERT-In Directions (India)**: Mandatory reporting of specified cybersecurity incidents to CERT-In within 6 hours of discovery.

---

### 2.3 Consumer Protection & E-Commerce Regulations

Under the **Consumer Protection (E-Commerce) Rules, 2020** and the **CCPA Guidelines for Prevention and Regulation of Dark Patterns, 2023**:
1. **Nodal Officer**: Every e-commerce entity in India must appoint a resident Nodal Person for 24/7 coordination with law enforcement.
2. **Clear Price Breakup**: Mandatory display of the total price, itemizing delivery, service fees, and applicable taxes (18% GST).
3. **No Deceptive UX / Dark Patterns**:
   - *No Subscription Trap*: Cancellation must be simple, direct, and reachable in fewer or equal clicks than subscription.
   - *No False Urgency*: Artificial countdown timers or false claims of scarcity ("Only 2 spots left at this price!") are prohibited.
   - *No Basket Sneaking*: Subscriptions must not auto-add ancillary services or donations without affirmative consent.

---

### 2.4 Intermediary Liability Safe Harbor (IT Act Section 79)

To maintain safe harbor protection under **Section 79 of the Information Technology Act, 2000**:
1. **Due Diligence (Rule 3(1) of IT Rules 2021)**: Publish rules and regulations, privacy policy, and user agreement informing users not to host, display, upload, modify, or publish prohibited content.
2. **Named Grievance Officer**: Publish name, contact email, and postal address of the Grievance Officer on the website and app.
3. **Redressal Timelines**:
   - Acknowledge complaints within **24 hours**.
   - Resolve complaints within **15 days**.
   - Remove or disable access to unlawful content within **36 hours** of receiving an actual order from a court or appropriate government agency.
4. **Preservation of Records**: Retain user registration data and activity logs for at least **180 days** following account cancellation or deletion to assist lawful investigations.

---

### 2.5 Tax & Invoicing Compliance (GST & Section 194H TDS)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        Taxation & Statutory Deduction Matrix                           │
├─────────────────────────┬──────────────┬───────────────────────────────────────────────┤
│ Transaction Type        │ Tax / Levy   │ Operational & Legal Mechanism                 │
├─────────────────────────┼──────────────┼───────────────────────────────────────────────┤
│ Customer Subscription   │ 18% GST      │ • SAC Code: 998431 (Online SaaS information). │
│ Purchase (Web/Desktop)  │              │ • CGST 9% + SGST 9% (intra-state) or          │
│                         │              │   IGST 18% (inter-state) itemized.            │
├─────────────────────────┼──────────────┼───────────────────────────────────────────────┤
│ Customer Subscription   │ Store Taxes  │ • Apple / Google act as Merchant of Record    │
│ Purchase (Mobile Store) │              │   and remit applicable digital taxes.         │
├─────────────────────────┼──────────────┼───────────────────────────────────────────────┤
│ Affiliate Commission    │ 2% TDS       │ • Deducted under Section 194H (threshold      │
│ Payout (Outgoing)       │ (Sec. 194H)  │   exceeding ₹15,000/year).                    │
│                         │              │ • 20% TDS under Sec. 206AA if PAN missing.    │
│                         │              │ • Quarterly Form 16A TDS certificate issued.  │
└─────────────────────────┴──────────────┴───────────────────────────────────────────────┘
```

> [!WARNING]
> **Resolution of TDS Rate Discrepancy**: Legacy database scripts and UI text referred to a 5% TDS rate. Under the amended provisions of Section 194H of the Income Tax Act (effective October 1, 2024), the statutory withholding rate on commission is **2%**. The product implementation and legal terms must be formally harmonized at 2% prior to production payout disbursement.

---

## Comprehensive Legal Risk Matrix & Mitigation Blueprint

| # | Feature / Area | Legal / Regulatory Risk | Risk Severity | Concrete Technical & Contractual Mitigation |
| :-: | :--- | :--- | :-: | :--- |
| **1** | **AI Assistant Copilot** | Misinterpreted as unregistered investment advice; user trading losses resulting from hallucinated levels. | **HIGH** | Strict system prompts banning trade calls; persistent visual disclaimers; complete contractual liability waiver in Terms of Service. |
| **2** | **Community UGC Feed** | Market manipulation, illegal stock tipping, pump-and-dump coordination, defamation. | **HIGH** | Content pre-moderation queue; IT Act Section 79 compliance; Grievance Officer with 24h ack / 36h takedown SLA; user blocking and reporting tools. |
| **3** | **Financial Calculators** | Allegations of inaccurate tax calculation, wrong margin sizing leading to liquidation. | **MEDIUM** | Prominent disclaimer on all 22 calculators stating outputs are educational approximations; user must reconcile with Chartered Accountant / Broker. |
| **4** | **Market Data & Feeds** | Exchange IP violations (NSE/BSE/Nasdaq) for displaying quotes without commercial redistribution license. | **HIGH** | Explicit "Delayed by 15-20 min" labels; attribution to Yahoo Finance; removal of any marketing claiming "live tick data" or "Level 2 feeds". |
| **5** | **Affiliate Program** | SEBI crackdowns on finfluencer partnerships; false marketing claims by affiliates; tax withholding errors. | **HIGH** | Binding Affiliate Agreement prohibiting return guarantees or advisory bundling; ASCI `#ad` disclosure mandate; 2% TDS under Section 194H with PAN verification. |
| **6** | **In-App Purchases** | Rejection or delisting by Apple App Review (Guideline 3.1.1) or Google Play Billing for bypassing store rails. | **CRITICAL** | RevenueCat SDK integration on mobile; store-specific billing for digital perks; web payments restricted to web/desktop clients. |
| **7** | **AutoPay Subscriptions** | CCPA Dark Pattern violations (subscription traps); RBI e-mandate non-compliance. | **HIGH** | Frictionless self-service cancellation in settings; 24h pre-debit notifications via Razorpay; itemized GST invoices. |
| **8** | **Account Deletion** | Rejection on Google Play / App Store; non-compliance with DPDP Act 2023 / GDPR Right to Erasure. | **CRITICAL** | Fully functional in-app deletion flow (`delete_account_page.dart`); web deletion endpoint; retaining only statutory tax invoices. |
| **9** | **User Trade Journals** | Breach of highly sensitive personal trading performance and financial data. | **HIGH** | Supabase Row-Level Security (RLS) policies; TLS 1.3 encryption; private storage buckets with short-lived expiring signed URLs. |

---

## Statutory Disclaimers & Required User Consent Touchpoints

### 3.1 Sign-Up & Checkout Affirmative Consent
At the point of registration and payment checkout, the user must affirmatively click an unticked checkbox:
> `[ ]` *"I confirm that I am at least 18 years old, and I have read, understood, and agree to the [Terms of Service], [Privacy Policy], [Trading and AI Risk Disclaimer], and [Refund Policy]. I understand that AlphaJournal is a self-directed software tool, not a registered investment adviser or broker, and does not provide financial advice."*

### 3.2 Master Trading & AI Risk Disclaimer (Mandatory Copy)
> **TRADING & AI RISK DISCLAIMER**:  
> *"Securities, derivatives (futures and options), and cryptocurrency trading involve substantial risk of loss and are not suitable for all investors. A vast majority of retail traders in derivatives incur financial losses. AlphaJournal (alphajournal.in) provides self-directed software tools, quantitative calculators, and educational materials. It does not provide personalized investment advice, research analysis, or portfolio management services.*  
>  
> *Calculators and mathematical models (including Black-Scholes) rely on theoretical assumptions and user-supplied data; they do not guarantee execution accuracy or profit. Generative AI outputs are computer-generated drafts for educational brainstorming and may contain inaccuracies. Users are solely responsible for evaluating all trade decisions and verifying data with a licensed broker and qualified tax professional."*

---

## Grievance Redressal Mechanism & Operational Contacts

In compliance with the **Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021** and the **Consumer Protection (E-Commerce) Rules, 2020**, AlphaJournal maintains the following designated contacts:

- **Entity Name**: `[REGISTERED_LEGAL_ENTITY_NAME]`
- **Registered Office Address**: `[PHYSICAL_OFFICE_ADDRESS_IN_INDIA]`
- **Customer Support Email**: `support@alphajournal.in`
- **Data Protection / Privacy Officer**: `privacy@alphajournal.in`
- **Grievance Officer (IT Rules, India)**:
  - **Name**: `[NAME_OF_GRIEVANCE_OFFICER]`
  - **Designation**: Grievance Redressal Officer
  - **Email**: `grievance@alphajournal.in`
  - **Statutory Response SLA**: Acknowledgment within 24 hours; disposal within 15 days.
- **Nodal Contact Person (Law Enforcement Coordination)**: `nodal@alphajournal.in`

---

## Appendix: Legal Document Mapping & Cross-References

The 15 legal review drafts located in `docs/publication_pack/` map directly to the consumer features detailed in this PRD:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        Document to Feature Cross-Reference                             │
├─────────────────────────────────────────────┬──────────────────────────────────────────┤
│ Legal Document in Publication Pack          │ Governing Consumer Features              │
├─────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 01_Privacy_Policy.docx                      │ Auth, Journal, Notes, Profile, Analytics │
│ 02_Terms_of_Service.docx                    │ Master Platform Terms across all 12 modules│
│ 03_Cookie_and_Similar_Technologies_Policy   │ Web & Desktop Analytics, Session Storage │
│ 04_Cookie_Consent_Notice_and_Deployment     │ Web Consent Banner Specification         │
│ 05_Subscription_Cancellation_Refund_Policy  │ Module 11 (RevenueCat & Razorpay Billing)│
│ 06_Trading_and_AI_Risk_Disclaimer           │ Modules 2, 3, 5, 6, 7 (Journal, AI, Calc)│
│ 07_End_User_License_Agreement (EULA)        │ Mobile & Desktop App Installations       │
│ 08_Acceptable_Use_Policy                    │ Platform Security, Rate Limits, Scraping │
│ 09_Community_Guidelines_and_Content_Policy  │ Modules 8 & 9 (Community, UGC, Chat)     │
│ 10_Affiliate_Program_Agreement              │ Module 10 (Partner Program Terms)        │
│ 11_Affiliate_Marketing_and_Brand_Guidelines │ Module 10 (ASCI `#ad`, Trademark Usage)  │
│ 12_Affiliate_Commission_Payout_Tax_Policy   │ Module 10 (2% TDS, GST, RazorpayX)       │
│ 13_Account_Deletion_Data_Retention_Policy   │ Modules 1 & 12 (DPDP Act, App Store SLA) │
│ 14_Security_and_Incident_Communication      │ CERT-In Reporting, Data Breach Response  │
│ 15_Product_Operations_and_Publication_Guide │ Internal Compliance Deployment Checklist │
└─────────────────────────────────────────────┴──────────────────────────────────────────┘
```

---
*End of Product Requirements Document — Consumer Features & Legal Compliance Review.*
