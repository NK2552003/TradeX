"""Generate the alphajournal publication pack with python-docx.

Run with the bundled Codex Python runtime. This file is the editable source for
the fifteen Word documents in this directory.
"""

from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = Path(__file__).resolve().parent
ENTITY = "[LEGAL_ENTITY_NAME]"
ADDRESS = "[REGISTERED_BUSINESS_ADDRESS]"
EMAIL = "[SUPPORT_EMAIL]"
PRIVACY_EMAIL = "[PRIVACY_EMAIL]"
DOMAIN = "alphajournal.in"
DATE = "[EFFECTIVE_DATE]"


def P(title, intro, sections, audience="alphajournal users", kind="Public policy"):
    return dict(title=title, intro=intro, sections=sections, audience=audience, kind=kind)


DOCS = [
    ("01_Privacy_Policy.docx", P("alphajournal Privacy Policy",
        "This policy explains the personal data alphajournal needs to operate trader and affiliate workspaces, how it is used, and how users can request access, correction, export, or deletion. It applies to the alphajournal website and supported apps operated by " + ENTITY + ".",
        [
            ("Who is responsible", "The operator is " + ENTITY + " at " + ADDRESS + ". Privacy requests may be sent to " + PRIVACY_EMAIL + ". A named grievance or data protection contact, response channel, and jurisdiction-specific disclosures must be completed before publication."),
            ("Data we receive", "Account data includes email, display name, authentication identifiers, plan and account status. User content may include journals, notes, strategies, watchlists, community posts, messages, attachments, and AI prompts or outputs. Affiliate data can include application details, campaigns, referral codes, payment destination, PAN, GSTIN, payout records, and tax records. Service data can include IP address, device and browser information, security events, and first-party referral attribution. Payment processors or app stores may send subscription and transaction status; alphajournal should avoid storing full card details."),
            ("Why we use it", "We use account data to authenticate users, deliver selected features, enforce entitlements and quotas, provide support, secure the service, process billing and affiliate activity, respond to requests, and meet applicable accounting or legal duties. User content is used to display and compute the requested workspace features. AI requests may be sent to a configured model provider only when the user invokes an AI feature; the provider and retention terms must be listed in the final vendor schedule."),
            ("Sharing and recipients", "Data may be shared with configured hosting, authentication, storage, payment, app store, email, analytics, security, and AI providers to provide the service. Public content that a user chooses to publish is visible according to the chosen visibility settings. We do not describe an integration as active until it is configured and tested. The final policy must identify material providers and any cross-border transfers that actually occur."),
            ("Referral tracking and device storage", "A referral visit may store a first-party referral code, campaign, timestamp, and visitor identifier on the device for up to 30 days to connect signup with an affiliate. The browser or app may also keep essential sign-in and preference state. See the Cookie and Similar Technologies Policy for choices and the actual deployed inventory."),
            ("Retention", "We retain data while the account is active and as needed for service, security, dispute, tax, and legal obligations. The final retention schedule must state concrete periods for each category and distinguish active databases, backups, logs, and legally retained tax records. Deletion of an account may involve immediate or delayed purge options in the current product; the final public promise must match the production configuration."),
            ("User choices and rights", "Users can use account and privacy settings for visibility and deletion options, and contact " + PRIVACY_EMAIL + " for access, correction, export, consent withdrawal, or grievance requests where applicable. Verification may be required to prevent unauthorized disclosure. Some records can be retained when law requires it; any exception will be explained in the response."),
            ("Security and children", "alphajournal uses access controls and authenticated service endpoints, but no online service can guarantee absolute security. The operator must verify encryption, backups, access review, incident handling, and vendor controls before publishing security claims. The service is intended for adults able to enter contracts; the final minimum age and any parental process must match launch markets."),
            ("India legal scope", "This edition is intended for a launch in India. The operator must map each actual data flow and notice to the Digital Personal Data Protection Act, 2023 and its phased commencement, the Digital Personal Data Protection Rules, 2025, and other applicable Indian requirements as they become effective. This policy should not claim compliance before the data inventory, consent paths, grievance process, and deployed controls are verified. The version in force will be posted at " + DOMAIN + " with material-change notice where required."),
            ("Contact", "For privacy questions, write to " + PRIVACY_EMAIL + ". For account support, write to " + EMAIL + ". Effective date: " + DATE + "."),
        ])),
    ("02_Terms_of_Service.docx", P("alphajournal Terms of Service",
        "These terms govern access to alphajournal software, public pages, free and paid workspaces, and related support. They establish the account, billing, content, and service rules for users of " + ENTITY + ".",
        [
            ("Agreement and eligibility", "By creating an account or using alphajournal, you agree to these terms and the linked policies. You must be able to enter a binding contract and provide accurate account information. Organizations must ensure an authorized person accepts on their behalf."),
            ("What alphajournal provides", "alphajournal offers self-directed trading journals, research notes, strategy records, watchlists, calculators, market information, community features, AI-assisted tools, and, for approved partners, an affiliate workspace. Features, data sources, limits, and availability vary by plan and platform. A roadmap or implementation plan does not create a promise that a planned feature is live."),
            ("No brokerage or personal advice", "alphajournal is software for recording, analysis, and education. It does not hold customer funds, act as a broker, place orders on a user's behalf unless a separately disclosed and verified integration is activated, or provide individualized investment advice. Users make their own investment decisions and should consult qualified professionals where appropriate."),
            ("Accounts and security", "Keep credentials private and promptly report suspected unauthorized use. You are responsible for activity under your account except where applicable law provides otherwise. alphajournal may require verification, limit access for security, or suspend an account where misuse or legal risk is reasonably suspected."),
            ("Subscriptions and billing", "The free tier and paid offers, actual price, taxes, renewal cycle, trial terms if any, and features will be shown at checkout. Paid access must be activated only after a verified transaction or valid entitlement. App store purchases are billed and managed through the relevant store; web or desktop purchases through the designated processor. The Subscription Cancellation and Refund Policy explains cancellation and refund handling."),
            ("User content and license", "You retain rights in content you create. You grant alphajournal the limited rights needed to host, process, display, back up, and transmit it for the service and your selected sharing settings. You must have rights to upload content and may not disclose confidential third-party information without authority. Public sharing is your choice and may be copied by others."),
            ("AI and external information", "AI output and market data may be incomplete, delayed, inaccurate, or unsuitable for trading. Check outputs, calculations, sources, and execution details independently. Third-party content and links are governed by their providers, and alphajournal does not endorse every linked statement."),
            ("Prohibited activity", "Do not abuse the service, scrape protected data, evade limits, impersonate others, post unlawful or harmful material, manipulate referrals or subscriptions, reverse engineer except where law permits, or interfere with security. Separate community and acceptable-use rules form part of these terms."),
            ("Availability, changes, and termination", "alphajournal may maintain or change features and may terminate or suspend access for material breach, fraud, security risk, or legal duty. We will give notice when required. Users may stop using the service and request deletion through the available account flow. Accrued payment, record retention, and dispute duties survive as applicable."),
            ("Indian law and consumer rights", "These terms are intended for service in India and are governed by Indian law, subject to mandatory consumer protections. The appropriate court location, dispute process, and any valid limitation of liability require entity-specific legal review before publication. Nothing here excludes liability that cannot legally be excluded or removes rights under applicable Indian consumer law."),
            ("Contact and updates", "The operator is " + ENTITY + " at " + ADDRESS + ". Contact " + EMAIL + ". Effective date: " + DATE + ". Material changes will be communicated through the app, website, or email as required."),
        ])),
    ("03_Cookie_and_Similar_Technologies_Policy.docx", P("alphajournal Cookie and Similar Technologies Policy",
        "This policy describes cookies, device storage, and similar identifiers used by alphajournal website and apps. The published inventory must reflect deployed code and configured providers at launch.",
        [
            ("Essential storage", "Sign-in state, security controls, session continuity, and user preferences may require cookies or app storage. These support requested service functions and should not be disabled by a marketing preference toggle."),
            ("Affiliate attribution", "A first-party referral record stores a code, optional campaign, and capture time for up to 30 days. A separate random visitor identifier may support click attribution. On signup, the attribution can be associated with the new account and then cleared locally. The actual web cookie or local-storage name and expiry must be confirmed in a browser audit."),
            ("Analytics and advertising", "alphajournal may use analytics or advertising technologies only when they are configured, disclosed in the live inventory, and subject to the required user choice. The operator must identify each deployed vendor, purpose, identifiers, duration, data sharing, and opt-out route before enabling it. A service is not listed as active merely because it appears in promotional material."),
            ("Consent and choices in India", "For the India launch, the operator should assess consent and notice duties under Indian law for each non-essential data flow. Optional analytics or advertising storage should remain off until the user chooses it where consent is required. A user must be able to reject optional categories as easily as accept them and reopen settings later. Blocking optional storage must not prevent essential service use."),
            ("Inventory", "Publish a table for each live technology: name, provider, purpose, category, data collected, lifetime, and whether data leaves the device. The starter inventory is: affiliate_attribution_v1, first-party, referral code and campaign, up to 30 days; affiliate_visitor_v1, first-party, random visitor identifier, duration to verify; authentication and preference storage, names and duration to verify."),
            ("Browser and app controls", "Users can manage optional preferences in the consent interface and may use device or browser controls to clear stored data. Clearing storage can sign users out and may remove an unconverted referral association."),
            ("Contact and changes", "Contact " + PRIVACY_EMAIL + " for details. This policy is effective " + DATE + " and should be updated when deployed providers or storage behavior change."),
        ])),
    ("04_Cookie_Consent_Notice_and_Deployment_Spec.docx", P("alphajournal Cookie Consent Notice and Deployment Specification",
        "This document gives the exact text and acceptance checks for a web consent interface. It is an implementation document for the website team and should be aligned with the final cookie inventory and launch regions.",
        [
            ("Initial notice text", "alphajournal uses essential storage to sign you in and keep the site secure. With your choice, we may use optional analytics and advertising technologies after they are enabled and listed in our Cookie Policy. Referral links may store a first-party code for up to 30 days. Choose Accept optional, Reject optional, or Manage settings."),
            ("Controls", "The first layer should present Accept optional, Reject optional, and Manage settings with comparable prominence. The settings view should explain each category, default optional categories off where consent is required, include Save choices, and link to the Cookie and Similar Technologies Policy. Provide a persistent way to reopen choices from the footer or account privacy settings."),
            ("Consent record", "Record policy version, categories chosen, timestamp, region or applicable rule, and a pseudonymous preference identifier. Do not capture more information than needed. If a category changes materially, request renewed consent where required."),
            ("Script gating", "Load optional vendor scripts only after the matching affirmative choice. Rejecting or withdrawing must stop future optional events and clear first-party optional storage where feasible. Integrations must not send events before the consent state is known. Essential auth and security flows remain functional."),
            ("Affiliate link behavior", "Decide whether affiliate attribution requires a separate notice or consent for the India launch. The current app stores referral data locally for a 30-day window; web behavior and consent classification need an India-specific legal and technical check."),
            ("Acceptance tests", "Test fresh browser, accept, reject, custom choice, withdrawal, expired consent, private browsing, mobile layout, keyboard navigation, screen reader labels, and third-party network requests. Verify no analytics or ad request is sent on initial load when optional consent is absent. Save evidence with the release record."),
            ("Owner and contact", "Product owner: [CONSENT_OWNER]. Technical owner: [WEB_OWNER]. Privacy contact: " + PRIVACY_EMAIL + ". Effective deployment date: [DEPLOYMENT_DATE]."),
        ], audience="alphajournal product and web teams", kind="Operational specification")),
    ("05_Subscription_Cancellation_and_Refund_Policy.docx", P("alphajournal Subscription Cancellation and Refund Policy",
        "This policy explains how recurring alphajournal subscriptions are purchased, renewed, cancelled, and assessed for refunds. The checkout screen and platform-specific billing terms take precedence for the actual amount and method shown to a customer.",
        [
            ("Plans and price display", "alphajournal may offer a Free plan and paid plans shown in the live checkout. The plan page must identify the available features and the INR amount for the selected monthly or annual cycle, including any discount, applicable tax, and final total before authorization. A plan or feature is available only when it appears in the live offer and can be delivered through the chosen platform."),
            ("How billing starts", "A paid subscription begins only after the payment provider or app store confirms purchase and alphajournal records the entitlement. A plan selection screen alone does not mean a charge occurred. A failed or pending charge must not be represented as a completed purchase."),
            ("Renewal", "If recurring billing is offered, the checkout must state the cycle, renewal date or period, total, tax, and how to cancel. Customers are charged through the platform on which they subscribed, subject to that platform's billing rules. A price change should be communicated and accepted where required before it takes effect."),
            ("Cancellation", "A customer may cancel renewal through the relevant store or the web billing settings. Cancellation normally stops future renewals while access continues to the end of the paid period, as the public pricing FAQ describes. The final wording must be checked against real store and processor configuration. Account deletion is separate from subscription cancellation; explain this in the deletion flow."),
            ("Refund requests", "For Apple App Store or Google Play purchases, request a refund through the store process where the store controls billing. For direct alphajournal payments, contact " + EMAIL + " with transaction ID, date, account email, and reason. alphajournal will review duplicate charges, unauthorized transactions, service failures, and any statutory rights under applicable consumer law. Do not promise an automatic seven-day customer refund solely because the affiliate commission model has a seven-day guard."),
            ("Approved refund handling", "If a direct-payment refund is approved, return funds to the original method where practicable and explain any processor timing. Correct the subscription entitlement and invoice status, and reverse or adjust related affiliate credit. Taxes are adjusted according to applicable invoice and credit-note rules."),
            ("Questions and records", "Support contact: " + EMAIL + ". Billing entity: " + ENTITY + ". Effective date: " + DATE + ". The published version must include a specific direct-payment review time and any mandatory rights under Indian consumer law after counsel review."),
        ])),
    ("06_Trading_and_AI_Risk_Disclaimer.docx", P("alphajournal Trading and AI Risk Disclaimer",
        "alphajournal helps users organize and analyze trading information. It cannot remove market risk or guarantee the accuracy of market, model, or user-entered data. Read this notice before acting on any chart, calculation, alert, or AI output.",
        [
            ("Loss of capital", "Trading and investing can result in partial or total loss of capital. Leverage, futures, options, illiquid instruments, and volatile markets can amplify losses and create obligations beyond the initial amount invested. Past performance, simulated results, and backtests do not predict future results."),
            ("Independent decisions", "alphajournal is a software tool for self-directed records, calculations, and research. It is not a personal investment recommendation, brokerage account, guarantee, or substitute for a licensed adviser. A user is responsible for checking suitability, applicable rules, and order details before trading."),
            ("Market and third-party data", "Prices, news, symbols, corporate actions, and charts can be delayed, unavailable, incomplete, or wrong. The displayed data source and timestamp should be checked before use. Where a feature uses third-party content, that provider may impose separate terms and licensing restrictions."),
            ("AI output", "AI suggestions can hallucinate facts, misread chart images, omit risk, or produce biased or stale analysis. AI output is a draft for human review. Do not treat confidence labels, pattern names, or generated trade setups as a probability of profit or as automated authorization to trade."),
            ("Calculators and tax", "Calculators use supplied assumptions and may not include fees, slippage, taxes, margin calls, or market events. Tax summaries are informational and require review by a qualified tax professional. Save source records and reconcile them with broker and statutory statements."),
            ("Community and affiliates", "Posts and affiliate communications reflect their authors and may contain conflicts of interest. A commercial referral must be disclosed. alphajournal does not verify every user claim or endorse a third-party strategy merely because it appears in the community or a media kit."),
            ("Regulatory representation", "alphajournal must state its verified regulatory status accurately. Unless the operator has the relevant registration and service permissions, no feature or promotion should represent alphajournal as a SEBI-registered Investment Adviser or Research Analyst. Any regulated activity requires a separate compliance review and appropriate disclosures."),
            ("Contact", "Questions can be sent to " + EMAIL + ". Effective date: " + DATE + "."),
        ])),
    ("07_End_User_License_Agreement.docx", P("alphajournal End User License Agreement",
        "This agreement grants a limited license to install and use alphajournal apps on supported devices. It applies alongside the Terms of Service and the terms of the app store or distribution channel used to obtain the app.",
        [
            ("License", ENTITY + " grants a personal, limited, revocable, non-exclusive, non-transferable license to use the app for permitted personal or internal business purposes while the user complies with these terms. The app is licensed, not sold. All rights not expressly granted remain with the owner or its licensors."),
            ("Restrictions", "Do not copy, distribute, sublicense, sell, bypass access controls, extract non-public data, or reverse engineer the app except to the extent a mandatory law permits. Do not use the app in a way that violates third-party market-data or intellectual-property rights."),
            ("Accounts and network services", "Many app functions require a alphajournal account, network connection, and configured backend. App functions may differ by operating system, region, and plan. The operator may issue security or compatibility updates and may retire unsupported versions with appropriate notice."),
            ("User data", "User content remains subject to the Terms of Service and Privacy Policy. Removing an app from a device does not necessarily close the account or cancel a subscription. Use the account deletion flow to request deletion and the relevant billing channel to stop renewal."),
            ("Third-party software", "The app may include open-source and licensed components. Their notices and licenses should be made available in the app or at " + DOMAIN + "/licenses before distribution. alphajournal must maintain a current software bill of materials and attribution list."),
            ("Store-specific terms", "When downloaded through an app store, that store's mandatory terms and usage rules also apply. The operator, not the store, is responsible for the app and support unless the store terms say otherwise. The final store addendum must be checked against the selected distribution channel."),
            ("Termination and legal rights", "This license ends when the account or license is terminated. Delete local copies where required, subject to backup and statutory rights. Mandatory consumer protections and non-excludable warranties remain unaffected."),
            ("Operator", "Licensor: " + ENTITY + ", " + ADDRESS + ". Contact: " + EMAIL + ". Effective date: " + DATE + "."),
        ])),
    ("08_Acceptable_Use_Policy.docx", P("alphajournal Acceptable Use Policy",
        "These rules protect the service, market-data licenses, other users, and the integrity of subscriptions and referrals. They apply to websites, apps, APIs, community content, and affiliate tools.",
        [
            ("Account integrity", "Do not create fraudulent identities, share credentials outside authorized seats, bypass plan limits, exploit coupons, automate fake purchases, or use another person's payment or payout details without authority."),
            ("System integrity", "Do not probe, attack, overload, or interfere with alphajournal or its providers. Do not upload malware, harvest credentials, scrape restricted data, evade rate limits, or access data without permission. Report vulnerabilities responsibly to " + EMAIL + "."),
            ("Content and communications", "Do not post unlawful, defamatory, harassing, hateful, deceptive, or rights-infringing content. Do not send spam or unsolicited commercial messages through community, direct messages, or affiliate campaigns. Do not expose another person's private or financial data without consent."),
            ("Market integrity", "Do not use alphajournal to coordinate manipulation, publish fabricated prices or performance, impersonate a licensed professional, promise guaranteed returns, or present synthetic AI content as verified analysis. Disclose sponsorship and material conflicts where required."),
            ("Affiliate abuse", "Self-referrals, attribution stuffing, fake signups, unauthorized brand-keyword advertising, coupon spoofing, and hidden redirects are prohibited. alphajournal may hold disputed commissions while investigating, with a documented review and appeal process."),
            ("Enforcement", "alphajournal may remove content, limit a feature, suspend an account, reverse fraudulently earned credits, or report unlawful conduct. The response should be proportionate and users should receive notice and a way to appeal where appropriate and legally required."),
            ("Report and appeal", "Send reports and appeals to " + EMAIL + " with account or content identifiers and supporting facts. Do not include sensitive credentials. Effective date: " + DATE + "."),
        ])),
    ("09_Community_Guidelines_and_Content_Policy.docx", P("alphajournal Community Guidelines and Content Policy",
        "alphajournal community spaces let users share ideas, records, and discussions. These guidelines explain how to participate, disclose financial interests, report abuse, and understand moderation decisions.",
        [
            ("Respect people", "Discuss ideas without threats, harassment, hate, doxxing, or intimidation. Criticize an analysis without attacking the person. Do not post another member's private messages, broker statements, or personal data without permission."),
            ("Trading claims and disclosures", "Label opinions and hypothetical or backtested results clearly. Do not imply that a result is guaranteed or verified by alphajournal. Disclose positions, sponsorships, affiliate links, compensation, or other material interests when they could affect a reader's view. Do not provide personalized investment advice unless you are authorized and the service has approved that activity."),
            ("Original and lawful content", "Share content you own or are allowed to use. Attribute sources, respect market-data licenses, and do not repost paid research without permission. Do not upload malware, illegal content, or deceptive identity material."),
            ("AI-generated content", "Review AI-created posts before publishing. Do not fabricate citations, credentials, trade fills, or performance. Mark materially AI-generated analysis where the interface or applicable rule requires it."),
            ("Moderation process", "alphajournal may receive user reports, review content, remove material, limit distribution, or restrict accounts. Reports should be assessed against written rules; serious safety or legal issues may require faster action. The operator should retain a moderation log, offer an appeal channel, and publish regional notices where required."),
            ("Visibility and deletion", "Public posts and comments may remain visible or be copied by others after a user changes settings. Account deletion should remove associated user-generated content to the extent required by platform policy and law, while any lawful retention exception is explained in the Privacy Policy."),
            ("Contact", "Report content or appeal a decision at " + EMAIL + ". Effective date: " + DATE + "."),
        ])),
    ("10_Affiliate_Program_Agreement.docx", P("alphajournal Affiliate Program Agreement",
        "This agreement governs approved partners who promote alphajournal through assigned referral links and campaigns. It applies only after an application is approved and the partner accepts the current program terms in the workspace.",
        [
            ("Enrollment and status", "Applying does not guarantee approval. alphajournal may verify identity, audience, lawful marketing capacity, and payout information. Only approved partners receive partner access and a referral link. The partner remains an independent contractor and cannot bind alphajournal or claim to be its employee, broker, adviser, or agent for investments."),
            ("Permitted promotion", "Use current approved product descriptions and media assets. Clearly identify that a link is commercial and may earn commission. Comply with advertising, consumer, privacy, email, platform, and securities rules that apply to the channel and audience. Do not represent roadmap features as live."),
            ("Attribution", "The app records a referral code and campaign for up to 30 days and associates it with signup when available. Eligible conversion requires a verified paid subscription, correct attribution, and any program validation or refund hold shown in the live terms. alphajournal may reject duplicate, self-referred, fraudulent, refunded, or chargeback transactions. The final attribution precedence rule must be stated and implemented consistently."),
            ("Commission", "Rates and tier criteria are shown in the versioned schedule accepted by the partner in the workspace. Commission is calculated on qualifying net subscription revenue excluding GST, using the approved rate for that partner and transaction. The schedule must state when a tier changes and whether the change applies to existing referred subscribers. No commission is owed on free, unpaid, refunded, or invalid subscriptions."),
            ("Records and adjustments", "The partner dashboard displays tracked referrals, credited commission, unpaid balance, payout requests, and settlement history. alphajournal may correct errors or reverse commissions linked to refunds, chargebacks, fraud, or duplicate attribution. Provide a statement and appeal route for disputed adjustments."),
            ("Brand and intellectual property", "alphajournal grants a limited, revocable right to use approved marks and assets solely to promote the program. Do not register confusingly similar domains, social handles, or ads, or alter a required legal disclaimer. Remove materials promptly when approval ends or an asset is withdrawn."),
            ("Term and termination", "Either side may end participation by notice to " + EMAIL + ". alphajournal may suspend for fraud, unlawful promotion, or material breach. Valid accrued commission remains subject to verification and lawful setoff; disputed amounts must be documented. Remove links and brand materials after termination."),
            ("Relationship and law", "The partner handles their own taxes, permits, disclosures, and expenses. Any exclusivity, indemnity, liability cap, governing law, or dispute forum requires entity-specific legal approval before publication."),
            ("Contact and version", "Program operator: " + ENTITY + ". Program contact: " + EMAIL + ". Effective date: " + DATE + ". Accepted version: [AFFILIATE_TERMS_VERSION]."),
        ], audience="Approved alphajournal affiliates")),
    ("11_Affiliate_Marketing_and_Brand_Guidelines.docx", P("alphajournal Affiliate Marketing and Brand Guidelines",
        "These guidelines tell approved partners how to describe alphajournal accurately, disclose their commercial relationship, use campaign links, and protect customers from misleading financial claims.",
        [
            ("Required disclosure", "Place a clear disclosure near each promotional claim and link, such as: 'I may earn a commission if you subscribe through this link.' Use a label that is understandable in the language of the post. A profile-bio disclosure alone may be insufficient for individual posts or videos. Follow applicable ASCI and platform guidance."),
            ("Approved product claims", "Describe alphajournal as a self-directed journaling, analysis, research, and community software product. Only mention a feature, price, free limit, data latency, or integration after checking the current live product and approved offer sheet. Do not describe the implementation plan as a delivered feature list."),
            ("Financial-risk wording", "Include a visible risk reminder when discussing markets: trading can cause substantial losses, and alphajournal does not guarantee returns. Do not claim a strategy, AI signal, alert, or screenshot produces reliable profits. Do not say alphajournal is SEBI-registered unless the operator verifies and authorizes the exact claim."),
            ("Link and campaign rules", "Use the assigned /r/:code link and approved UTM parameters. Do not hide or overwrite another partner's link, inject cookies, run misleading redirects, or pay for unauthorized alphajournal brand search terms. Do not place links on prohibited content or send unsolicited messages."),
            ("Brand assets", "Use current assets from Campaign Studio without materially changing the logo, disclosures, or offer text. Do not imply an official company account or a partnership wider than the affiliate program. Written approval is needed for co-branded pages, paid ads, giveaways, or press claims."),
            ("Review and correction", "alphajournal may request a copy of a promotion, require correction or removal, and pause a campaign that creates legal or customer risk. Partners should retain proof of disclosures and publish dates for the period specified in their accepted agreement."),
            ("Contact", "Request approval or report an issue at " + EMAIL + ". Effective date: " + DATE + "."),
        ], audience="Approved alphajournal affiliates")),
    ("12_Affiliate_Commission_Payout_and_Tax_Policy.docx", P("alphajournal Affiliate Commission Payout and Tax Policy",
        "This policy explains how a verified partner earns, requests, and receives INR commission. It must be reconciled with the actual tax engine, accepted tier schedule, and payment provider before release.",
        [
            ("Qualifying revenue", "Commission is based on the approved tier's rate applied to qualifying subscription revenue actually received, excluding GST and adjusted for refunds, discounts, chargebacks, and invalid transactions. The accepted partner schedule controls the commercial rate. A statement must identify the rate and revenue base used for each credited transaction."),
            ("Attribution and hold", "A referral link may be remembered for 30 days. Signup alone creates no payable commission. The current seeded terms describe credit after a verified paid subscription and a seven-day refund guard. This is a commission validation period, not a customer refund entitlement. Confirm the real payment webhook and eligibility state before publishing a time promise."),
            ("Balance and threshold", "Payout requests are denominated in INR and require at least INR 1,000 of available balance, unless a higher partner threshold is shown in accepted settings. A request cannot exceed available unpaid balance and may be blocked while another payout is open. The request reserves balance; an administrator reviews and either records settlement with a reference or rejects and releases the reserved amount. Settlement timing must reflect the actual payout operation."),
            ("Destination and verification", "Supported settings include an Indian UPI VPA or bank details with IFSC, with rails varying by configuration. Partners must provide accurate legal name, PAN and, if applicable, GSTIN and tax invoice details. alphajournal may pause payment to resolve identity, fraud, or bank rejection issues."),
            ("TDS and GST", "Where Indian tax law requires withholding on commission, alphajournal will apply the legally applicable rate and threshold to the relevant payment, report the deduction, and provide the required tax certificate through its tax process. The applicable treatment can depend on the payee and transaction facts. GST treatment depends on partner registration, place of supply, invoice facts, and law; a GSTIN alone does not automatically create a fixed addition or 'input credit' payment."),
            ("Statements and disputes", "The dashboard may display gross, deductions, tax amount, net payout, destination, status, and reference. A displayed statement is not a statutory Form 16A unless the operator's tax process actually issues one. Send a dispute with payout ID and evidence to " + EMAIL + ". Document corrections and keep an audit trail."),
            ("Changes and contact", "Changes to rate or eligibility should apply prospectively after notice and updated acceptance where required. Operator: " + ENTITY + ". Effective date: " + DATE + "."),
        ], audience="Approved alphajournal affiliates")),
    ("13_Account_Deletion_and_Data_Retention_Policy.docx", P("alphajournal Account Deletion and Data Retention Policy",
        "This policy explains how users request account closure, what data is removed, and what may remain for lawful reasons. It should be linked from the app, website, and app store account-deletion fields.",
        [
            ("How to request deletion", "In account settings, open Security or Privacy, choose Close account, review the available purge condition, acknowledge the effects, and complete the confirmation. A user who cannot access the app can request deletion through [PUBLIC_DELETION_WEB_URL] or " + PRIVACY_EMAIL + ". The web route must be live before a Google Play submission that permits in-app account creation."),
            ("What the current flow offers", "The code contains immediate purge, a 30-day grace option, and a mode to purge personal data while retaining a statutory INR tax ledger. The chosen mode and data categories must be shown clearly before confirmation. The operator must test these paths in production and ensure the live backend executes them as represented."),
            ("Data affected", "Depending on the selected condition and lawful exceptions, deletion covers account profile, journals, notes, strategies, watchlists, community posts, messages, AI history, campaigns, local tokens, and linked storage objects. Any data retained for tax, fraud, billing, dispute, or legal duties must be limited and explained with an actual period."),
            ("Subscriptions and affiliates", "Closing an account may not cancel a store subscription; customers should cancel recurring billing through the original channel. An affiliate with pending referrals or payouts should receive a clear settlement or dispute explanation before the account closes. The operator must not leave an inaccessible paid entitlement or unpaid balance without a support path."),
            ("Backups and logs", "Deleted records may persist in encrypted backups or security logs for a limited, documented period. They should not be restored to active use except for disaster recovery, and then should be re-deleted. The final schedule must name those periods and processors."),
            ("Verification and response", "alphajournal may verify identity to prevent unauthorized deletion. A request should receive acknowledgement and completion notice within the applicable legal timeframe. If a lawful exception prevents full deletion, the response should identify the categories and reason."),
            ("Contact", "Privacy contact: " + PRIVACY_EMAIL + ". Operator: " + ENTITY + ". Effective date: " + DATE + "."),
        ])),
    ("14_Security_and_Incident_Communication_Policy.docx", P("alphajournal Security and Incident Communication Policy",
        "This policy states the security commitments alphajournal can make publicly and the steps it will take when an incident may affect users. Specific certifications and uptime commitments must be supported by independent evidence and signed service terms.",
        [
            ("Access controls", "alphajournal uses authenticated accounts and role-based access paths for trader, affiliate, and administrator functions. The database schema includes row-level access policies and controlled functions for sensitive affiliate payout and account-deletion actions. These controls must be verified in the deployed environment and reviewed when roles change."),
            ("Protecting data", "Use transport encryption, least-privilege credentials, secret management, backups, logging, and access reviews appropriate to the risk. The final statement must name only controls that operate in production; neither source code nor a design plan proves a certification or uptime level."),
            ("Payment and payout safety", "A paid entitlement should follow verified provider confirmation, and financial webhooks should validate signatures, reject replay, and use idempotent processing. Payout requests should require partner access, verified destination, available balance, and administrator settlement evidence. These are go-live acceptance criteria where not yet deployed."),
            ("Reporting a vulnerability", "Send a report to [SECURITY_EMAIL] with steps to reproduce, affected URL or app version, and impact. Do not access other users' data, disrupt service, or publicly disclose exploitable details before coordinated review. alphajournal will acknowledge and triage reports through a documented process."),
            ("Incident response", "The operator will contain and investigate suspected incidents, preserve evidence, assess affected data and users, remediate the cause, and notify regulators, users, partners, or app stores when required by applicable law or contracts. The final incident plan must assign owners, clocks, escalation paths, and tested templates."),
            ("Claims and updates", "alphajournal will describe certifications, service levels, custody status, and integration permissions only where supported by current evidence and applicable service terms. A user should not infer that all service components are certified or continuously available. Security contact: [SECURITY_EMAIL]. Effective date: " + DATE + "."),
        ])),
    ("15_Product_Operations_and_Publication_Guide.docx", P("alphajournal Product Operations and Publication Guide",
        "This internal guide maps the documented customer and affiliate journeys to the repository and identifies what must be verified before the public documents are posted or app store submissions are made. It is a working release register, not a claim that deployment is complete.",
        [
            ("Customer journey", "A user enters through public pages, signs up, verifies identity as configured, and enters the Trader workspace. The workspace includes journals, notes, strategies, watchlists, calculators, community, messages, AI tools, and market snapshots. Account settings cover plan selection, privacy, security, and deletion. Source: implementation.md sections 1 and 3; lib/core/widgets/app_scaffold.dart; lib/core/navigation/role_navigation_config.dart."),
            ("Authentication and workspace roles", "The authentication wrapper moves between splash, onboarding, login or signup, verification, subscription selection, and the authenticated shell. A customer's account can apply for affiliate status, but an application does not grant a partner role. Administrator approval provisions partner access; the app shell rechecks that access when opening the Partner Hub. A partner may switch back to the trader view while retaining the approved role. Test rejected, suspended, expired-session, and re-login paths as well as the happy path."),
            ("Trader writing and research", "The writing desk combines journal entries, markdown notes, strategy playbooks, record links, attachments, and export paths. The implementation plan defines Free and Pro limits for journal entries, notes, attachments, strategy history, and document export. The actual release should verify each limit on both client and database paths, including direct API writes. Exports should be checked for complete content and confidential-data handling. Linked records and image permissions should be tested across edit, delete, and account purge actions."),
            ("Markets calculators and social tools", "The customer navigation includes market snapshots and screeners, watchlists, financial calculators, community feeds, and messages. Document each feed's provider, timestamp, delay, and license before promising real-time data. Calculators should expose assumptions and must not be marketed as tax or investment advice. Community posts, comments, direct messages, attachments, reports, and moderation require real visibility and deletion tests. The root plan excludes unimplemented live tick bridges, Level 2 depth, and institutional desk consoles from go-live claims."),
            ("AI requests and output", "The implementation plan proposes an authenticated AI endpoint with quota checks and creation targets for notes, journal records, strategies, posts, and charts. Before publication, trace the deployed client request, model provider, prompt or attachment transfer, quota deduction, error handling, output review, and persistence. Clearly mark generated content as assistive and require a user to review it before saving or sharing. Test limit resets and failure behavior; a local mock or plan text is not proof of a production AI feature."),
            ("Subscription journey", "The implementation plan targets Free and Pro self-serve subscriptions in INR. Its desired rails are app-store purchases on mobile and Razorpay on web or desktop, with a verified webhook writing subscription, invoice, and quota state. In current code, SubscriptionPricingRepositoryImpl.selectPlan changes local session state; the comment says paid checkout must be confirmed server-side. Treat paid billing, renewals, invoices, tax, refunds, and entitlement synchronization as release gates until a live end-to-end test proves them. The public catalogue's Enterprise features should be removed or qualified if they remain unimplemented."),
            ("Subscription state and money movement", "A correct paid flow starts with a displayed INR total and tax, creates a provider purchase, validates the store receipt or gateway webhook, records an idempotent subscription event, updates the entitlement, and issues a matching invoice. Renewal, failed payment, grace period, cancellation, expiration, refund, and restore-purchase events must each lead to a documented state. Never elevate a tier from a client-only selection. Reconcile provider reports against subscriptions, invoices, user access, and affiliate commission before financial launch."),
            ("Affiliate journey", "A trader applies, an administrator reviews, and only an approved affiliate can open the Partner Hub. The workspace exposes overview, referrals, Campaign Studio, payouts, and settings. A /r/:code visit stores first-party attribution for up to 30 days. Signup can attach referral metadata. Commission depends on a qualifying paid subscription and approved business rules. The SQL has payout reservation and administrator settlement paths; prove actual deployment and payment transfer separately."),
            ("Affiliate application and campaign operations", "Applications collect identity and reach information for administrator review. Approval creates the partner profile and enables overview, referral and campaign pages; rejection and suspension should preserve a clear customer route and support path. Campaign Studio creates channel-specific links, copies media assets, and can pause or delete campaigns. Test slug validation, unique links, attribution across signup and verification, duplicate clicks, expired 30-day records, and the handling of a disabled campaign. Publish the exact attribution precedence and qualification rule accepted by partners."),
            ("Affiliate payout operations", "The payout page validates INR amount precision, the minimum threshold, balance, destination, and open-request state. A successful request reserves balance. An administrator can mark the payout paid with a transfer reference or reject it and return the reserved balance. The dashboard may show gross, TDS, GST, and net amounts, but those figures must be corrected for current Indian tax law before payouts. Verify UPI or bank transfers against external payment records and reconcile every rejected, failed, reversed, and settled request."),
            ("Administrator operations", "Admin pages cover affiliate applications, payout review, tier governance, user and seat controls, audit records, analytics, and deletion queues. Role permissions and row-level security must prevent a customer or affiliate from calling privileged operations directly. Every sensitive decision should record actor, target, reason, timestamp, and outcome. An administrator screen is not evidence that its external action, such as an actual bank transfer, completed."),
            ("Data and privacy journey", "Supabase Auth and database paths, local preferences, attachments, community content, and AI requests imply multiple data categories. Inventory every deployed processor and data flow. Test privacy settings, export, deletion modes, public deletion URL, backups, and retained tax records. Map the India launch to the phased DPDP requirements and do not infer compliance from a generator template."),
            ("Operational monitoring and support", "Set named owners for billing reconciliation, payout review, moderation, privacy requests, incident response, tax statements, and app store appeals. Monitor webhook failures, entitlement mismatches, repeated payout requests, referral fraud, failed exports, and stuck deletion jobs. Maintain a support workflow with ticket reference, acknowledgement, status, and closeout evidence. Do not publish a service-level target unless it is measured and contractually supported."),
            ("Conflicts that block publication", "1. Section 194H TDS: code and seeded terms say 5%; current Income Tax Department material says 2% with conditions. 2. Affiliate tiers: root implementation plan says 15%/30%; seeded migration says 15%/20%/25%/35%. 3. Public pricing describes Enterprise and live feeds, brokers, AI and SLA claims that the root plan explicitly excludes from launch. 4. Footer security and status modals assert unverified SOC 2, uptime, latency, and integrations. 5. Paid checkout is a planned integration rather than a verified live flow. Resolve each in product, code, and text before publication."),
            ("Required business inputs", "Confirm Indian legal entity, registered address, support/privacy/security contacts, live domain and deletion URL, Indian user minimum age rule, actual payment processors, data vendors, retention periods, refund review time, Indian court venue, tax treatment, approved tier schedule, and effective date. Enter these once in the publication register and update all documents consistently."),
            ("Release verification", "Run a production-like account journey on web, iOS, and Android. Capture checkout total and tax, successful and failed payments, renewal, cancellation, refund, invoice, entitlement changes, affiliate link capture, qualification, commission adjustment, payout request and settlement, export, and account deletion. Match every public promise to a test result or operational owner. Obtain counsel and tax sign-off before the first publication."),
            ("Publishing locations", "Link Privacy, Terms, Risk, Refund, Cookies, and account deletion from public footer and account settings. Show Affiliate Agreement, Marketing Guidelines, and Payout/Tax Policy at application and acceptance. Put Privacy URL, in-app deletion, and external deletion URL in app store metadata as required. Keep an archive of the accepted version and date for each user or affiliate."),
            ("Reference authorities", "India DPDP Rules and commencement notices: meity.gov.in; Section 194H: incometaxindia.gov.in; Consumer Protection E-Commerce Rules: consumeraffairs.nic.in; SEBI IA/RA materials: sebi.gov.in; Apple App Review Guidelines: developer.apple.com; Google Play user-data and deletion policy: support.google.com/googleplay/android-developer. Recheck these immediately before launch."),
        ], audience="alphajournal owners, product, legal, tax, and release teams", kind="Internal release guide")),
]

# Further India-specific operating clauses. These sit before each document's
# closing contact/change section so the public policy reads as a complete flow.
EXTRA = {
    "01_Privacy_Policy.docx": [
        ("Source and collection point", "Information comes from registration forms, workspace actions, uploaded files, payment or app-store events, referral links, support correspondence, and security telemetry. At each collection point, show a concise notice explaining the purpose and required fields. Do not silently repurpose PAN, GSTIN, journal content, or private messages for advertising."),
        ("Visibility and AI processing", "A user's chosen visibility controls whether notes, strategies, or posts are public to other users. Private workspace material should not become public merely because a user uses an AI helper. Identify the AI provider, the data sent, whether it is retained or used for model training, and the available opt-out before enabling AI processing."),
        ("Indian privacy requests", "Provide a usable path to obtain information about processing, request correction or erasure, withdraw consent where processing relies on it, and raise a grievance as applicable under the phased Indian data-protection framework. Record the request, verify identity proportionately, route it to an owner, and respond within the period required by the law in force at the time."),
        ("Processor safeguards", "Before onboarding a vendor, record the service, data categories, processing location, subprocessors, access controls, deletion terms, and breach notification obligation. Share only the minimum data needed. Review any transfer outside India against applicable rules and contractual restrictions rather than assuming global hosting is permitted for every category."),
        ("Changes and version history", "Keep a dated copy of every published notice and the version accepted by users where consent or contractual acceptance is required. Notify users before a material new purpose, new sensitive data category, or major sharing change takes effect, and obtain a fresh choice when required."),
    ],
    "02_Terms_of_Service.docx": [
        ("Order of documents", "The checkout terms control the specific purchased plan, tax, period, and price. The Privacy Policy governs personal data. Affiliate terms apply only to approved partners. If terms conflict, mandatory Indian law prevails; otherwise the more specific accepted terms govern the relevant feature. Keep versioned acceptance evidence."),
        ("Charges, taxes, and invoices", "A purchase confirmation should show the billing entity, plan, total INR price, tax treatment, payment provider, renewal cycle, and cancellation path. A receipt or invoice should match the provider charge. A coupon must state its expiry and conditions. alphajournal must correct duplicate or erroneous charges through the refund process."),
        ("Service data and third parties", "Third-party market feeds, broker connections, app stores, payment gateways, and AI providers can have separate terms. Their availability may affect a feature. Users should receive a clear prompt before granting an external account permission, and any broker integration must disclose its actual permission scope and revocation path."),
        ("Complaints and notices", "Send service or billing complaints to " + EMAIL + ". The operator should acknowledge the case, preserve transaction evidence, investigate, and provide a reasoned outcome and escalation path. Formal notices to the operator should be sent to the registered address or a designated electronic address once confirmed."),
        ("Severability and waiver", "If a clause is unenforceable, the remaining clauses continue to the extent permitted by Indian law. A delay in enforcing a right does not waive it. alphajournal cannot transfer consumer obligations to a new operator without giving any notice or choice required by law."),
        ("Proposed liability allocation", "Subject to rights that cannot be excluded under Indian law, the parties may agree that alphajournal is not liable for indirect or consequential trading losses caused by reliance on informational output, and that its aggregate contractual liability for the service is limited to [LIABILITY_CAP]. This proposed cap must be set and approved by Indian counsel; it must not cover fraud, wilful misconduct, or other liability that law does not allow to be limited."),
        ("Dispute process and venue", "A user may first raise a complaint through " + EMAIL + " and include relevant account and transaction records. alphajournal should give a reasoned response and a named escalation path. Any court venue at [INDIAN_COURT_CITY] or alternative dispute procedure must be reviewed for validity under Indian consumer law and must not prevent a user from pursuing a mandatory statutory remedy."),
    ],
    "03_Cookie_and_Similar_Technologies_Policy.docx": [
        ("Exact storage categories", "Classify each deployed item as strictly necessary, preference, measurement, or advertising. Necessary items support authentication and fraud prevention; preference items remember user choices; measurement items assess product use; advertising items profile or target campaigns. A category must match actual behavior, not the vendor's marketing label."),
        ("Retention and deletion", "Document the technical expiry and the business retention period separately. A browser item may expire before a server-side event is removed. When a user withdraws an optional choice, stop future collection and clear first-party optional identifiers where technically possible; explain any already processed data retained for a lawful reason."),
        ("Third-party inventory", "For each enabled analytics, ad, video, support, or payment embed, list the provider, country or region of processing, identifiers received, event types, expiry, and a direct privacy link. Re-audit after releases because an SDK or tag-manager change can add storage without a policy edit."),
        ("Children and shared devices", "Do not use optional profiling for an account known to be a child without a specifically reviewed lawful path. Explain that other people using the same browser may see or clear stored preferences and that deleting a browser cookie does not necessarily delete an account or server-side record."),
    ],
    "04_Cookie_Consent_Notice_and_Deployment_Spec.docx": [
        ("Suggested settings descriptions", "Necessary: keeps sign-in, security, and requested functions working. Preferences: remembers display or accessibility choices. Analytics: measures usage to improve the service. Advertising: supports personalized promotions if alphajournal actually deploys such technology. Do not show an optional category as active until its vendor and purpose are confirmed."),
        ("Accessibility and evidence", "Use semantic buttons, visible keyboard focus, a readable contrast ratio, and labels announced by assistive technology. The notice must work at narrow mobile widths, large text, and in the languages offered by the site. Keep test evidence showing the choice state, stored record, and network requests before and after each selection."),
        ("Server-side enforcement", "Do not rely only on hiding scripts in the browser. Where optional processing is triggered from a backend event, pass the current consent state and enforce it server-side. Prevent tag-manager defaults, consent-mode fallbacks, or delayed script hydration from sending optional events before a choice."),
        ("Withdrawal and policy update", "A footer link should reopen settings without forcing account login. Withdrawal should apply to future visits and events; display confirmation of the saved choice. When a material purpose or vendor changes, increase the consent version and request a new decision before the new processing starts."),
    ],
    "05_Subscription_Cancellation_and_Refund_Policy.docx": [
        ("Checkout disclosure checklist", "Before payment, show plan name, included features, INR subtotal, tax and total, recurring period, renewal terms, trial conversion if any, cancellation path, and billing provider. Do not preselect a paid plan or conceal a recurring charge. The final order screen and invoice must agree."),
        ("Upgrades and downgrades", "State before confirmation whether an upgrade starts immediately, whether a pro-rated charge applies, and when a downgrade takes effect. If the provider or app store controls these rules, link to that provider's terms and show the outcome in alphajournal billing settings. Do not promise the same timing across all platforms without tests."),
        ("Payment failure and access", "A failed charge should not create a paid entitlement. For renewals, display any grace period, retry schedule, or access end date that the provider actually uses. Give the customer a way to update payment details through the original billing channel and a support path for an incorrect lockout."),
        ("Refund assessment and appeal", "Evaluate duplicate payments, mistaken charge amount, failed activation, material service non-delivery, unauthorized payment, and any mandatory consumer right on their facts. Tell the customer the decision and reason, and allow a reasonable appeal. A refusal under this policy cannot override a statutory remedy or an app-store decision."),
        ("Records and tax correction", "Keep the purchase, invoice, entitlement, cancellation, and refund event linked by transaction ID. If a refund is issued, adjust the entitlement, ledger, tax document or credit note as required, and any affiliate commission tied to the transaction. Do not delete financial records merely because an account closes if Indian law requires retention."),
    ],
    "06_Trading_and_AI_Risk_Disclaimer.docx": [
        ("Examples of calculation risk", "A journal or backtest can overstate results if fills, fees, slippage, dividends, corporate actions, currency conversions, or survivorship bias are missing. A risk calculator is only as accurate as its inputs. Independently reconcile reported P&L and tax values against broker and bank statements."),
        ("No execution assurance", "An alert, price, chart, or AI draft should never be treated as a guaranteed executable order or a promise of liquidity. Market conditions can change between display and action. If alphajournal later offers a broker connection, the exact permissions, order confirmation, error handling, and broker responsibility must be separately disclosed."),
        ("Conflicts and paid promotion", "Affiliates and community authors may benefit when users subscribe or trade. A paid relationship should be disclosed near the relevant claim. A promotional performance screenshot requires context, including dates, costs, risk, and whether results were simulated. alphajournal should remove false guaranteed-return claims when reported."),
        ("High-risk instruments and emergencies", "Options, futures, leveraged products, and illiquid securities can move rapidly and may expose users to large losses. Do not use alphajournal as the only source of a risk limit, margin figure, or urgent market notice. For a live position, consult the broker and exchange information directly."),
    ],
    "07_End_User_License_Agreement.docx": [
        ("Updates and compatibility", "alphajournal may provide patches for security, compatibility, or feature changes. Some updates may be required to continue using connected services. The operator should disclose material permission changes and provide a support route if an update removes a paid feature. Supported OS versions and device requirements should be posted with each release."),
        ("Intellectual property and feedback", "The app, design, code, and alphajournal marks remain owned by their respective rights holders. Feedback can be used to improve the product without an obligation to adopt it, but user private content is not turned into public marketing material through a feedback submission."),
        ("Export and uninstall", "Users should be able to use available export tools before account closure. Uninstalling the app removes local copies subject to the operating system's behavior but does not automatically delete hosted content or stop renewal. The deletion and cancellation policies describe those separate actions."),
        ("Support and warranties", "Provide the actual support contact and any mandatory Indian consumer remedies. Any express warranty or liability limitation must be reviewed for the operating entity and app-store terms. No clause should disclaim a right that Indian law does not permit the operator to exclude."),
    ],
    "08_Acceptable_Use_Policy.docx": [
        ("Automation and API access", "Use only documented interfaces, authorized credentials, and rate limits. Do not use bots to create artificial engagement, referrals, AI usage, or market-data distribution. An enterprise API or webhook permission, if offered, must be scoped to the account and can be revoked for abuse or compromise."),
        ("Privacy and confidential data", "Do not upload another person's PAN, bank details, broker credentials, or private trade records without authority. If a user accidentally discloses sensitive information in a public post, report it promptly so moderators can restrict access while the issue is assessed."),
        ("Investigation and appeal", "alphajournal should preserve proportionate evidence, document the rule allegedly breached, and provide a user with a reason and appeal channel where appropriate. A temporary hold on a suspected fraudulent affiliate payout should not become an unexplained permanent forfeiture. Escalate criminal or urgent safety issues under applicable law."),
    ],
    "09_Community_Guidelines_and_Content_Policy.docx": [
        ("Reporting workflow", "Users should be able to report a post, comment, message, profile, or live session with a reason. The moderation team should acknowledge reports, prioritize threats and private-data exposure, record the action, and notify the reporter or author where appropriate. Provide an appeal path for removed content or account restrictions."),
        ("Financial promotions", "A post that promotes a broker, strategy service, course, or alphajournal subscription should disclose compensation or another material connection. Do not post fabricated testimonials, unverified profit screenshots, or guaranteed-return claims. A community endorsement does not substitute for any registration or authorization required under Indian securities rules."),
        ("Private messages and live sessions", "Do not use direct messages or live rooms to evade public moderation, solicit funds, or seek account credentials. Hosts are responsible for their own statements, and alphajournal may end a session or restrict a participant when rules are breached. Explain recording, replay, and retention before any live-session capture is enabled."),
        ("Repeat violations", "The operator may issue a warning, remove content, limit posting, suspend, or terminate an account based on severity and history. Publish a clear appeal route and preserve evidence for a defined period. Emergency action may be taken before a full review to protect users or comply with law."),
    ],
    "10_Affiliate_Program_Agreement.docx": [
        ("Applications and eligibility review", "A partner must provide accurate identity, channel, audience, and payout details and keep them current. Approval can be conditional on identity and tax verification. A rejected applicant may revise and reapply if the product offers that path. The operator should record the decision and prevent self-assignment of partner access."),
        ("Commission event and reconciliation", "The parties should define the payable event as a verified payment for an eligible subscription, after the stated validation period. Deduplicate renewal events and provider retries, subtract tax from the commission base only as agreed, and reverse credits associated with refunds or chargebacks. Partners should be able to inspect the calculation and raise a dispute within [AFFILIATE_DISPUTE_PERIOD]."),
        ("Partner obligations", "The partner is responsible for its own content, consent to send marketing, required disclosures, tax registrations, and accurate payout details. The partner must not use scraped audiences, purchased lists, fake reviews, or false scarcity claims. No sub-affiliate network is permitted without written approval."),
        ("Program changes", "Rate changes, tier criteria, attribution rules, and payout thresholds should be versioned. Give advance notice and obtain renewed acceptance for a material adverse change where required. State whether a change applies to already-earned commission, existing referred subscribers, or only new referrals; do not change these silently."),
        ("Records and audit", "Retain accepted terms, campaign records, conversion evidence, adjustments, payout instructions, and settlement references for the legally required period. alphajournal may request evidence of compliant promotions and remove an asset or link that violates the agreement. Any audit request should be proportionate and protect unrelated confidential information."),
        ("Proposed indemnity and liability", "Subject to Indian law and final counsel approval, a partner should be responsible for third-party claims caused by the partner's unlawful marketing, false claims, infringement, or privacy violations, except to the extent alphajournal caused the loss. Any defense procedure, liability cap, exclusions, and treatment of unpaid commission must be specified in the signed version; a blanket forfeiture or unlimited liability clause should not be inserted without review."),
    ],
    "11_Affiliate_Marketing_and_Brand_Guidelines.docx": [
        ("Channel-specific placement", "On video, make the disclosure audible or visually clear at the time of endorsement and place it near the link in the description. On short posts, place it where the reader sees it before the link or claim. In newsletters and websites, label the commercial relationship next to the recommendation. Use a disclosure label accepted by the relevant platform and current ASCI guidance."),
        ("Claims approval", "A partner should substantiate every price, feature, plan limit, data-delay, broker, security, and performance statement with the current alphajournal offer sheet. Claims about tax savings, assured returns, automatic execution, or regulatory registration need written approval and evidence. If a feature is disabled or delayed, update or remove promotions promptly."),
        ("Paid media and prohibited placements", "Written permission is required for paid search, social ads, retargeting, domain names, or landing pages using alphajournal marks. Do not buy misspelled alphajournal keywords, imitate the official site, use misleading coupons, or place links beside unlawful or exploitative content. Respect channel rules for financial promotions."),
        ("Monitoring and remedy", "Keep a copy of each live promotion and disclosure. alphajournal may request changes with a reasonable deadline or suspend a risky campaign immediately. Repeated misleading claims can end participation and trigger commission review under the Affiliate Agreement. The partner should have a route to contest a factual mistake."),
    ],
    "12_Affiliate_Commission_Payout_and_Tax_Policy.docx": [
        ("Example statement fields", "A payout statement should identify the partner, period, qualifying transaction count, agreed tier and rate, commission base excluding GST, gross earned commission, reversals, withholding applied, GST treatment if relevant, amount reserved, net amount sent, payment rail, status, transfer reference, and correction history. Do not label an in-app summary as a statutory certificate without issuing the proper certificate."),
        ("Tax decision gate", "Before the first payment, a qualified Indian tax adviser should sign off on whether each partner payment is commission under Section 194H, the applicable rate and threshold, PAN effects, deduction timing, deposit and reporting duties, GST invoice handling, and any non-resident case. The published statement and actual deductions must be kept aligned when law or partner status changes."),
        ("Failed or rejected transfer", "If a bank or UPI transfer fails, record the provider response, keep the ledger balanced, notify the partner, and allow correction of destination details. If an administrator rejects a request, release the reserved amount and provide the reason. Do not mark a payout paid solely because an internal review button was clicked; require external settlement evidence."),
        ("Fraud and disputes", "Hold an amount under investigation only for a documented reason such as self-referral, duplicate attribution, chargeback, or false identity. Give the partner the affected IDs, amount, explanation, and appeal route, subject to fraud or legal constraints. Corrections must leave a trace rather than silently overwriting the original statement."),
    ],
    "13_Account_Deletion_and_Data_Retention_Policy.docx": [
        ("Before confirmation", "Show the account email, selected purge condition, content categories affected, expected completion window, subscription status, pending affiliate balance, and available export. Require a deliberate confirmation and explain which actions cannot be undone. Do not make the user contact support merely to find the in-app deletion control."),
        ("Grace-period operation", "If the user selects a 30-day grace condition, state whether sign-in and content access stop immediately, whether restoration is possible, and the exact date on which purge occurs. A user should be able to see request status and cancel during the grace period only if the product actually supports that option."),
        ("Statutory records", "Retention of an invoice, tax ledger, audit event, or fraud record must be limited to a specific Indian legal duty or defensible purpose. Separate those records from ordinary profile, community, and marketing data. The published schedule should name the category, basis, access controls, and retention period."),
        ("Completion verification", "The deletion job should record the requested scope, deleted tables and storage objects, failed items, retry status, and final verification. Send a completion notice without exposing sensitive details. Periodically test that exported data is complete and deleted content does not reappear from caches or backups."),
    ],
    "14_Security_and_Incident_Communication_Policy.docx": [
        ("Identity and authorization", "Use multi-factor authentication for privileged accounts where supported, restrict service-role secrets to backend services, rotate credentials after exposure, and review administrator access. Test that row-level policies prevent unauthorized reads and writes, including direct API calls that bypass the Flutter interface."),
        ("Monitoring and response", "Log security-relevant sign-ins, role changes, payout decisions, billing webhooks, data exports, and deletion actions with restricted access and a documented retention period. Define incident severity, on-call ownership, evidence preservation, containment, recovery, and a post-incident review. Exercise the process before launch."),
        ("User notification", "When an incident may affect personal data or financial records, assess the facts promptly and deliver notices required by Indian law and contracts. Tell affected users what happened, what information may be involved, steps taken, and practical steps they can take. Do not state a fixed notification deadline until counsel confirms the applicable rule and commencement date."),
        ("Independent assurance", "A security audit, penetration test, SOC report, or uptime target must be described with its actual scope, period, and evidence. Avoid broad claims that every feature is certified or continuously available. Provide a status and support route for outages that affect paid access or account safety."),
    ],
}

for filename, specification in DOCS:
    if filename in EXTRA:
        specification["sections"][-1:-1] = EXTRA[filename]


def set_cell_shading(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tcPr.append(shd)


def add_page_number(para):
    run = para.add_run()
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), "PAGE")
    run._r.addnext(fld)


def build(filename, spec):
    doc = Document()
    compact = True
    ultra = filename.startswith(("01_", "02_", "08_"))
    balanced_two_pages = filename.startswith(tuple(f"{i:02d}_" for i in range(3, 15))) and not filename.startswith("08_")
    sec = doc.sections[0]
    sec.top_margin = Inches(0.63 if ultra else 0.70)
    sec.bottom_margin = Inches(0.56 if ultra else 0.62)
    sec.left_margin = Inches(0.88)
    sec.right_margin = Inches(0.88)
    sec.header_distance = Inches(0.34)
    sec.footer_distance = Inches(0.34)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Arial"
    normal.font.size = Pt(9.5 if ultra else 10)
    normal.font.color.rgb = RGBColor(25, 25, 25)
    normal.paragraph_format.space_after = Pt(4.5 if ultra else 5.5)
    normal.paragraph_format.line_spacing = 1.08 if ultra else 1.10
    for name, size, before, after in [("Title", 18.5 if ultra else 19, 0, 10), ("Heading 1", 11.5 if ultra else 12, 8 if ultra else 10, 3 if ultra else 4)]:
        s = styles[name]
        s.font.name = "Arial"
        s.font.size = Pt(size)
        s.font.bold = True
        s.font.color.rgb = RGBColor(0, 0, 0)
        s.paragraph_format.space_before = Pt(before)
        s.paragraph_format.space_after = Pt(after)
        s.paragraph_format.keep_with_next = True
        if name == "Title":
            ppr = s._element.get_or_add_pPr()
            for border in ppr.findall(qn("w:pBdr")):
                ppr.remove(border)

    t = doc.add_paragraph(style="Title")
    t.add_run(spec["title"])
    meta = doc.add_paragraph()
    meta.paragraph_format.space_after = Pt(9 if compact else 13)
    r = meta.add_run(f"ALPHAJOURNAL  |  {spec['kind'].upper()}  |  {spec['audience']}  |  Effective {DATE}")
    r.bold = True
    r.font.size = Pt(8.5)
    r.font.color.rgb = RGBColor(85, 85, 85)
    doc.add_paragraph(spec["intro"])
    scope = doc.add_paragraph("India edition. This document is drafted for alphajournal services offered to users in India; any expansion requires a separate legal and operational review.")
    scope.paragraph_format.space_after = Pt(7 if compact else 10)
    scope.runs[0].italic = True
    total_words = sum(len(body.split()) for _, body in spec["sections"])
    running_words = 0
    inserted_break = False
    for heading, body in spec["sections"]:
        if balanced_two_pages and not inserted_break and running_words >= total_words * 0.48:
            doc.add_page_break()
            inserted_break = True
        doc.add_heading(heading, level=1)
        paragraph = doc.add_paragraph(body)
        paragraph.paragraph_format.keep_together = True
        running_words += len(body.split())

    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    fr = footer.add_run("alphajournal  |  ")
    fr.font.size = Pt(8)
    fr.font.color.rgb = RGBColor(95, 95, 95)
    add_page_number(footer)
    doc.core_properties.title = spec["title"]
    doc.core_properties.subject = "alphajournal publication pack"
    doc.core_properties.author = "alphajournal"
    doc.save(OUT / filename)


def main():
    for filename, spec in DOCS:
        build(filename, spec)
    print(f"Created {len(DOCS)} DOCX files in {OUT}")


if __name__ == "__main__":
    main()
