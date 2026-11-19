# Help Centre Release Notes

Guide | Updated 2026-11-19

AlphaJournal 1.0.0 build 1 establishes the application capability baseline, entitlement boundaries, release versioning, installation flow, and automatic update checks. These notes describe repository readiness and do not by themselves announce a production deployment.

## Versioning and automatic updates

The canonical version is 1.0.0+1 in pubspec.yaml and is propagated to supported Flutter platforms. AlphaJournal checks a small static HTTPS release manifest, caches the result for six hours, shows recommended or required update prompts, reloads current web assets safely, and sends native users to the signed store or download channel. Version checks do not query Supabase.

## Workspace records

Writing Desk, Trade Journal, linked Markdown Notes, and Strategy Playbooks connect executions, theses, revisions, attachments, analytics, ticker links, public/private sharing, and eligible PDF exports in one workspace.

## Calculators and market data

The application includes 22 trading, options, investing, currency, and Indian tax calculators. Free users retain core tools; Basic and Pro unlock advanced tools. Full Market Intelligence includes overview, one consolidated World Indices table, one consolidated Assets table, movers, instruments, news, screeners, quote history, and instrument details. Free users receive only the approved lightweight Community market preview.

## Community and private messaging

Community supports public posts, setups, charts, polls, reactions, bookmarks, reposts, quote posts, threaded replies, profiles, follows, moderation, live spaces, and shareable snapshots. Private Messages are restricted to Basic and Pro and support encrypted conversations, recovery keys, attachments, voice notes, and shared workspace cards.

## Unified AI and notifications

The gateway-first Unified AI service preserves multi-provider fallback behavior, streaming, search and research modes, specialist trading workflows, citations, memory, schedules, voice, and saved pages. Activity inbox and web push surfaces route mentions, replies, security events, and other supported notifications.

## Subscriptions, affiliate, and administration

Free, Basic, and Pro entitlements are applied before navigation and before paid network work starts. Billing management, purchase restoration, quota displays, referral applications and attribution, affiliate campaign/payout workspaces, and the server-verified Admin console are included in the operational surface. Paid monthly checkout remains disabled until production provider products, signing, webhooks, and store review are complete.

## Installation and deep links

The PWA install bridge remembers dismissals, detects supported installed related apps, preserves the requested HTTPS route when handing off to an installed app, and remains on the matching web route when no app is installed. Cross-subdomain session continuity remains intentional across approved AlphaJournal hosts.

## Help, privacy, and accessibility

Help and policies includes the searchable document library, release notes, installation guidance, support, cookie and consent controls, privacy/data controls, trading and AI risk notices, and an application version card. Responsive layouts, themes, text scaling, keyboard focus, reduced motion, and shared AlphaJournal components remain required.

## Security and efficiency

Paid features are protected at route, presentation, repository/service, and server/database boundaries where applicable. Market and update reads use bounded data, caching, pagination, lazy loading, and request deduplication. Secrets, private data, and exploitable vulnerability details remain outside public reports and client bundles.

## Deployment responsibilities

A release owner must bump pubspec version/build metadata, update CHANGELOG.md, regenerate the selected platform manifest entry, validate tests and analysis, publish signed native builds through their official channel, and use minimum-supported versions only for a verified security or compatibility requirement.
